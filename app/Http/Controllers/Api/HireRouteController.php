<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hire;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Plans the driving route the driver app draws on a hire's map: from where the
 * phone is now, through whatever is still ahead, to the end location.
 *
 * Before the hire has been started that is now → pickup → (stops) → end; once
 * it has started the customer is on board and the pickup is behind, so it is
 * now → (stops) → end. Google Directions is called from here so the API key
 * never has to be used by the app for it.
 */
class HireRouteController extends Controller
{
    /** Drivers move, but not that fast — an identical request within this window reuses the answer (and saves a billed call). */
    private const CACHE_SECONDS = 60;

    public function show(Request $request, Hire $hire): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver || $hire->driver_id !== $driver->id, 403);
        abort_if($hire->is_completed || $hire->is_cancelled, 422, 'This hire is over.');

        $origin = $request->validate([
            'origin_lat' => ['required', 'numeric', 'between:-90,90'],
            'origin_lng' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $started = $hire->tracking_started_at !== null;
        $stops = collect($hire->mapLocations())
            ->reject(fn (array $place) => $started && $place['role'] === 'pickup')
            ->map(fn (array $place) => $place['latitude'].','.$place['longitude'])
            ->values();

        abort_if($stops->isEmpty(), 422, 'This hire has no destination with saved coordinates.');

        $from = round((float) $origin['origin_lat'], 6).','.round((float) $origin['origin_lng'], 6);

        // ~100 m of the origin counts as "the same place" for caching purposes.
        $cacheKey = sprintf(
            'hire-route:%d:%s:%s:%s',
            $hire->id,
            $started ? 'after' : 'before',
            round((float) $origin['origin_lat'], 3).','.round((float) $origin['origin_lng'], 3),
            md5($stops->implode('|')),
        );

        if (($cached = Cache::get($cacheKey)) !== null) {
            return response()->json($cached);
        }

        $route = $this->plan($from, $stops->last(), $stops->slice(0, -1)->values()->all());

        Cache::put($cacheKey, $route, self::CACHE_SECONDS);

        return response()->json($route);
    }

    /**
     * @param  list<string>  $waypoints  "lat,lng" strings between the origin and the destination
     * @return array{polyline: string, distance_m: int, duration_s: int}
     */
    private function plan(string $origin, string $destination, array $waypoints): array
    {
        $response = Http::timeout(10)->get('https://maps.googleapis.com/maps/api/directions/json', array_filter([
            'origin' => $origin,
            'destination' => $destination,
            'waypoints' => $waypoints === [] ? null : implode('|', $waypoints),
            'mode' => 'driving',
            'key' => config('services.google_maps.key'),
        ]));

        $status = $response->json('status');

        if (in_array($status, ['ZERO_RESULTS', 'NOT_FOUND'], true)) {
            abort(422, 'No drivable route was found for this hire.');
        }

        $route = $response->json('routes.0');

        // Google reports bad keys, disabled APIs and quota in the body (status
        // REQUEST_DENIED, OVER_QUERY_LIMIT, ...), not as an HTTP error.
        if (! $response->ok() || $status !== 'OK' || empty($route['overview_polyline']['points'])) {
            Log::warning('Hire route: Google Directions failed', [
                'status' => $status,
                'error' => $response->json('error_message'),
                'http' => $response->status(),
            ]);

            abort(502, 'Could not plan a route right now.');
        }

        $legs = collect($route['legs'] ?? []);

        return [
            'polyline' => $route['overview_polyline']['points'],
            'distance_m' => (int) $legs->sum('distance.value'),
            'duration_s' => (int) $legs->sum('duration.value'),
        ];
    }
}
