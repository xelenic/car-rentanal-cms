<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

/**
 * A thin server-side proxy for Google Places suggestions, used by the
 * admin app's Create Hire location fields — mirrors what the web admin
 * panel's google.maps.places.Autocomplete JS widget does in the browser,
 * but the Google Maps key stays on the server rather than shipping inside
 * a compiled app binary (an Android APK is trivially decompiled; a
 * browser page's key is at least scoped to this one internal tool).
 */
class PlaceController extends Controller
{
    public function autocomplete(Request $request): JsonResponse
    {
        $this->authorize($request);

        $input = trim((string) $request->query('input', ''));
        if ($input === '') {
            return response()->json(['predictions' => []]);
        }

        $response = Http::get('https://maps.googleapis.com/maps/api/place/autocomplete/json', [
            'input' => $input,
            'key' => config('services.google_maps.key'),
        ]);

        if (! $response->successful()) {
            return response()->json(['predictions' => []], 502);
        }

        $body = $response->json();

        // Google returns 200 with a status field for API-level failures
        // (bad/missing key, quota, etc.) rather than an HTTP error — treat
        // anything other than OK/ZERO_RESULTS as "no suggestions" so the
        // field just degrades to plain text instead of surfacing a raw
        // Google error to the app.
        $status = $body['status'] ?? 'UNKNOWN_ERROR';
        if (! in_array($status, ['OK', 'ZERO_RESULTS'], true)) {
            return response()->json(['predictions' => []]);
        }

        $predictions = collect($body['predictions'] ?? [])
            ->map(fn (array $p) => [
                'place_id' => $p['place_id'],
                'description' => $p['description'],
            ])
            ->values();

        return response()->json(['predictions' => $predictions]);
    }

    public function details(Request $request): JsonResponse
    {
        $this->authorize($request);

        $placeId = trim((string) $request->query('place_id', ''));
        abort_if($placeId === '', 422, 'place_id is required.');

        $response = Http::get('https://maps.googleapis.com/maps/api/place/details/json', [
            'place_id' => $placeId,
            'fields' => 'name,formatted_address,geometry',
            'key' => config('services.google_maps.key'),
        ]);

        if (! $response->successful()) {
            return response()->json(['name' => null, 'lat' => null, 'lng' => null], 502);
        }

        $body = $response->json();
        if (($body['status'] ?? null) !== 'OK') {
            return response()->json(['name' => null, 'lat' => null, 'lng' => null]);
        }

        $result = $body['result'] ?? [];
        $location = $result['geometry']['location'] ?? null;

        return response()->json([
            'name' => $result['formatted_address'] ?? $result['name'] ?? null,
            'lat' => $location['lat'] ?? null,
            'lng' => $location['lng'] ?? null,
        ]);
    }

    /**
     * Same "who's allowed to see location suggestions" gate as hire
     * creation — this endpoint only exists to support the Create Hire
     * screen's location fields.
     */
    private function authorize(Request $request): void
    {
        abort_unless($request->user()->can('hires.create'), 403, 'You do not have permission to create hires.');
    }
}
