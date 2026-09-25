<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\HireResource;
use App\Http\Resources\Admin\VehicleResource;
use App\Models\Hire;
use App\Models\Vehicle;
use App\Support\MonthlyPeriods;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

/**
 * The admin mobile app's Vehicles API: the fleet as cards (with per-vehicle
 * hire numbers), adding a vehicle, and one vehicle's hires split into tabs.
 * Permissions are checked directly, like the Hires API next door — these are
 * Sanctum-token requests, not the web session the permission:* middleware
 * assumes.
 */
class VehicleController extends Controller
{
    private const PER_PAGE = 20;

    private const MAX_PER_PAGE = 50;

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorizeView($request);

        $filters = $request->validate(['condition' => ['nullable', Rule::in(Vehicle::CONDITIONS)]]);

        $vehicles = Vehicle::query()
            ->withHireStats()
            ->when($filters['condition'] ?? null, fn ($query, $condition) => $query->where('condition', $condition))
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('model', 'like', "%{$search}%")
                        ->orWhere('condition', 'like', "%{$search}%");
                });
            })
            ->orderBy('model')
            ->orderBy('id')
            ->paginate(self::PER_PAGE);

        return VehicleResource::collection($vehicles);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless($request->user()->can('vehicles.create'), 403, 'You do not have permission to add vehicles.');

        $vehicle = Vehicle::create($request->validate(Vehicle::rules()));

        return (new VehicleResource(Vehicle::query()->withHireStats()->findOrFail($vehicle->id)))
            ->response()
            ->setStatusCode(201);
    }

    /** Optionally for one year (and month): every number then covers just that period. */
    public function show(Request $request, Vehicle $vehicle): VehicleResource
    {
        $this->authorizeView($request);

        $period = $this->period($request);

        return new VehicleResource(
            Vehicle::query()->withHireStats($period['year'], $period['month'])->findOrFail($vehicle->id)
        );
    }

    /**
     * The years and months in which this vehicle has hires (cancelled ones
     * too — they're listed) — what the app's period filter offers.
     */
    public function periods(Request $request, Vehicle $vehicle): JsonResponse
    {
        $this->authorizeView($request);
        abort_unless($request->user()->can('hires.view'), 403, 'You do not have permission to view hires.');

        $periods = MonthlyPeriods::fromTimestamps(
            $vehicle->hires()->get(['start_time', 'created_at'])->pluck('effective_month_date')
        );

        return response()->json([
            'years' => $periods['years'],
            // An empty PHP array would serialize as [] rather than {}.
            'months_by_year' => (object) $periods['months_by_year'],
        ]);
    }

    /**
     * One vehicle's hires, one tab at a time (see Hire::TABS). Today's list
     * puts the running hire first; scheduled goes soonest-first; the rest
     * newest-first by the day each hire is (or was) for.
     */
    public function hires(Request $request, Vehicle $vehicle): AnonymousResourceCollection
    {
        $this->authorizeView($request);
        abort_unless($request->user()->can('hires.view'), 403, 'You do not have permission to view hires.');

        $filters = $request->validate([
            'tab' => ['nullable', Rule::in(Hire::TABS)],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:'.self::MAX_PER_PAGE],
        ]);
        $tab = $filters['tab'] ?? 'all';
        $period = $this->period($request);

        $hires = $vehicle->hires()
            ->tab($tab)
            ->when($period['year'], fn ($query, $year) => $query->inMonth($year, $period['month']))
            ->with([
                'package', 'customer', 'driver', 'vehicle',
                'fromLocation.location', 'toLocation.location', 'stayLocations.location',
            ]);

        $hires = match ($tab) {
            'today' => $hires->orderByRaw("CASE WHEN status = 'started' THEN 0 ELSE 1 END")
                ->orderByRaw('COALESCE(start_time, created_at) asc'),
            'scheduled' => $hires->orderBy('start_time'),
            default => $hires->orderByRaw('COALESCE(start_time, created_at) desc'),
        };

        return HireResource::collection(
            $hires->orderBy('id', $tab === 'today' || $tab === 'scheduled' ? 'asc' : 'desc')
                ->paginate((int) ($filters['per_page'] ?? self::PER_PAGE))
        );
    }

    /**
     * The optional year/month filter — a month only makes sense within a year.
     *
     * @return array{year: ?int, month: ?int}
     */
    private function period(Request $request): array
    {
        $period = $request->validate([
            'year' => ['nullable', 'integer', 'min:2000', 'max:2100', 'required_with:month'],
            'month' => ['nullable', 'integer', 'min:1', 'max:12'],
        ]);

        return [
            'year' => isset($period['year']) ? (int) $period['year'] : null,
            'month' => isset($period['month']) ? (int) $period['month'] : null,
        ];
    }

    private function authorizeView(Request $request): void
    {
        abort_unless($request->user()->can('vehicles.view'), 403, 'You do not have permission to view vehicles.');
    }
}
