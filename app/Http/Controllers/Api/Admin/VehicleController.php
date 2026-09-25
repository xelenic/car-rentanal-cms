<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\HireResource;
use App\Http\Resources\Admin\VehicleResource;
use App\Models\Hire;
use App\Models\Vehicle;
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

        $vehicles = Vehicle::query()
            ->withHireStats()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('model', 'like', "%{$search}%")
                        ->orWhere('condition', 'like', "%{$search}%");
                });
            })
            ->orderBy('model')
            ->orderBy('id')
            ->paginate(self::PER_PAGE);

        return VehicleResource::collection($vehicles)->additional(['summary' => $this->fleetSummary()]);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless($request->user()->can('vehicles.create'), 403, 'You do not have permission to add vehicles.');

        $vehicle = Vehicle::create($request->validate(Vehicle::rules()));

        return (new VehicleResource(Vehicle::query()->withHireStats()->findOrFail($vehicle->id)))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, Vehicle $vehicle): VehicleResource
    {
        $this->authorizeView($request);

        return new VehicleResource(Vehicle::query()->withHireStats()->findOrFail($vehicle->id));
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

        $hires = $vehicle->hires()
            ->tab($tab)
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

    /** Whole-fleet totals for the dashboard's header (cancelled hires earn nothing, so they're left out). */
    private function fleetSummary(): array
    {
        $totals = Hire::query()
            ->counted()
            ->whereNotNull('vehicle_id')
            ->selectRaw('COUNT(*) as hire_count, COALESCE(SUM(hire_full_value), 0) as full_value, COALESCE(SUM(our_hire_value), 0) as our_value')
            ->first();

        $full = (float) $totals->full_value;
        $our = (float) $totals->our_value;

        return [
            'vehicle_count' => Vehicle::query()->count(),
            'hire_count' => (int) $totals->hire_count,
            'hire_full_value_total' => round($full, 2),
            'our_hire_value_total' => round($our, 2),
            'commission_total' => round($full - $our, 2),
        ];
    }

    private function authorizeView(Request $request): void
    {
        abort_unless($request->user()->can('vehicles.view'), 403, 'You do not have permission to view vehicles.');
    }
}
