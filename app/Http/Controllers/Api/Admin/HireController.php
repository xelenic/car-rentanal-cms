<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\HireResource;
use App\Models\Customer;
use App\Models\Driver;
use App\Models\Hire;
use App\Models\Package;
use App\Models\Vehicle;
use App\Services\HireService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;

/**
 * The admin mobile app's Hires API: list, show, create, edit and delete.
 * Every request here requires "hires.view"; store additionally requires
 * "hires.create", update "hires.update" and destroy "hires.delete" — checked
 * directly rather than via route permission middleware since these are
 * Sanctum-token requests, not the web session guard the permission:*
 * middleware assumes.
 */
class HireController extends Controller
{
    public function __construct(private readonly HireService $hires)
    {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorizeView($request);

        $showUpcoming = $request->boolean('upcoming');
        $dateFrom = $this->parseDate($request, 'date_from');
        $dateTo = $this->parseDate($request, 'date_to');
        $tab = $request->filled('tab') && in_array($request->string('tab')->toString(), Hire::TABS, true)
            ? $request->string('tab')->toString()
            : 'all';

        // Every filter except the tab itself — cloned once per tab below so
        // each tab's own count (and the page shown) reflects the same
        // driver/vehicle/customer/search/date filters, just split by status.
        $preTab = Hire::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('description', 'like', "%{$search}%")
                        ->orWhereHas('customer', function ($query) use ($search) {
                            $query->where('name', 'like', "%{$search}%")
                                ->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            })
            ->when($showUpcoming, function ($query) {
                $query->where('status', 'pending')
                    ->whereNotNull('start_time')
                    ->where('start_time', '>=', now());
            })
            ->when($request->filled('driver_id'), fn ($query) => $query->where('driver_id', $request->integer('driver_id')))
            ->when($request->filled('vehicle_id'), fn ($query) => $query->where('vehicle_id', $request->integer('vehicle_id')))
            ->when($request->filled('customer_id'), fn ($query) => $query->where('customer_id', $request->integer('customer_id')))
            ->when(
                $request->filled('payment_type') && array_key_exists($request->string('payment_type')->toString(), Hire::PAYMENT_TYPES),
                fn ($query) => $query->where('payment_type', $request->string('payment_type')->toString())
            )
            ->when(
                $request->filled('payment_status') && in_array($request->string('payment_status')->toString(), ['unpaid', 'partial', 'paid'], true),
                fn ($query) => $query->paymentStatus($request->string('payment_status')->toString())
            )
            // Date range — by each hire's effective date (its scheduled
            // start_time, or created_at for one never scheduled at all); see
            // Hire::scopeInDateRange().
            ->when($dateFrom || $dateTo, fn ($query) => $query->inDateRange($dateFrom, $dateTo));

        $tabCounts = collect(Hire::TABS)->mapWithKeys(
            fn ($oneTab) => [$oneTab => (clone $preTab)->tab($oneTab)->count()]
        );

        $filtered = (clone $preTab)->tab($tab);

        // The totals of everything the filters match, not just the page
        // shown — a customer's "this month" tab wants the real total, not
        // just what fits on page one. Cloned before ->with() so the raw
        // aggregate select doesn't trip over hydrating eager-loaded relations.
        $summaryRow = (clone $filtered)
            ->selectRaw('COUNT(*) as count, COALESCE(SUM(hire_full_value), 0) as full_value, COALESCE(SUM(our_hire_value), 0) as our_value')
            ->first();
        $fullValueTotal = round((float) $summaryRow->full_value, 2);
        $ourValueTotal = round((float) $summaryRow->our_value, 2);

        // Same ordering as the per-vehicle tabbed list (Api\Admin\VehicleController::hires()):
        // today soonest-first (started hires first), scheduled soonest-first,
        // completed/cancelled most-recent-first — "all" keeps this
        // endpoint's own pre-existing upcoming/latest behavior.
        match ($tab) {
            'today' => $filtered->orderByRaw("CASE WHEN status = 'started' THEN 0 ELSE 1 END")
                ->orderByRaw('COALESCE(start_time, created_at) asc'),
            'scheduled' => $filtered->orderBy('start_time'),
            'completed', 'cancelled' => $filtered->orderByRaw('COALESCE(start_time, created_at) desc'),
            default => $showUpcoming ? $filtered->orderBy('start_time') : $filtered->latest(),
        };

        $hires = $filtered
            ->with([
                'package', 'customer', 'driver', 'vehicle',
                'fromLocation.location', 'toLocation.location', 'stayLocations.location',
            ])
            ->paginate(20);

        return HireResource::collection($hires)->additional([
            'summary' => [
                'count' => (int) $summaryRow->count,
                'hire_full_value_total' => $fullValueTotal,
                'our_hire_value_total' => $ourValueTotal,
                'commission_total' => round($fullValueTotal - $ourValueTotal, 2),
                'tab_counts' => $tabCounts,
            ],
        ]);
    }

    public function show(Request $request, Hire $hire): HireResource
    {
        $this->authorizeView($request);

        $hire->load([
            'package', 'customer', 'driver', 'vehicle',
            'fromLocation.location', 'toLocation.location', 'stayLocations.location',
            'payments',
        ]);

        return new HireResource($hire);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless($request->user()->can('hires.create'), 403, 'You do not have permission to create hires.');

        $rules = $this->hires->rules($request->input('tour_type'), $request->input('customer_id') === 'new');
        $data = $request->validate($rules);

        $hire = $this->hires->create($data);
        $hire->load([
            'package', 'customer', 'driver', 'vehicle',
            'fromLocation.location', 'toLocation.location', 'stayLocations.location',
        ]);

        return (new HireResource($hire))->response()->setStatusCode(201);
    }

    /**
     * Edits a hire — the same fields and rules as creating one. Status and
     * cancellation can be set by hand here too (see HireService::statusAttributes()),
     * for a hire that already happened and was never entered at the time, or
     * to correct one later. Live tracking itself (tracking_started_at/
     * tracking_stopped_at) stays the driver app's business — untouched here.
     */
    public function update(Request $request, Hire $hire): HireResource
    {
        abort_unless($request->user()->can('hires.update'), 403, 'You do not have permission to edit hires.');

        $rules = $this->hires->rules($request->input('tour_type'), $request->input('customer_id') === 'new');
        $hire = $this->hires->update($hire, $request->validate($rules));
        $hire->load([
            'package', 'customer', 'driver', 'vehicle',
            'fromLocation.location', 'toLocation.location', 'stayLocations.location',
        ]);

        return new HireResource($hire);
    }

    /**
     * Deletes a hire together with everything that hangs off it (its
     * locations, payments, expenses and tracking history) — the same as the
     * web panel's delete.
     */
    public function destroy(Request $request, Hire $hire): JsonResponse
    {
        abort_unless($request->user()->can('hires.delete'), 403, 'You do not have permission to delete hires.');

        $hire->delete();

        return response()->json(['message' => "Hire #{$hire->id} was deleted."]);
    }

    /**
     * Everything the Create Hire screen's pickers need, in one round trip.
     */
    public function referenceData(Request $request): JsonResponse
    {
        $this->authorizeView($request);

        return response()->json([
            'drivers' => Driver::query()->orderBy('name')->get(['id', 'name']),
            'vehicles' => Vehicle::query()->orderBy('model')->get(['id', 'model']),
            'customers' => Customer::query()->orderBy('name')->get(['id', 'name', 'phone']),
            'packages' => Package::query()->orderBy('name')->get(['id', 'name']),
        ]);
    }

    private function authorizeView(Request $request): void
    {
        abort_unless($request->user()->can('hires.view'), 403, 'You do not have permission to view hires.');
    }

    private function parseDate(Request $request, string $key): ?Carbon
    {
        if ($request->isNotFilled($key)) {
            return null;
        }

        try {
            return Carbon::parse($request->string($key)->toString());
        } catch (\Throwable) {
            return null;
        }
    }
}
