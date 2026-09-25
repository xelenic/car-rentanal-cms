<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Hire;
use App\Models\Vehicle;
use App\Models\VehicleMaintenanceRecord;
use App\Support\MonthlyPeriods;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;

class VehicleController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:vehicles.view', only: ['index', 'show']),
            new Middleware('permission:vehicles.create', only: ['store']),
            new Middleware('permission:vehicles.update', only: ['update']),
            new Middleware('permission:vehicles.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $vehicles = Vehicle::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('model', 'like', "%{$search}%")
                        ->orWhere('condition', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        $periods = MonthlyPeriods::fromTimestamps(
            Hire::query()->get(['start_time', 'created_at'])->pluck('effective_month_date')
        );
        $availableYears = $periods['years'];
        $monthsByYear = $periods['months_by_year'];

        $selectedYear = $request->filled('year')
            ? $request->integer('year')
            : ($availableYears[0] ?? (int) now()->format('Y'));

        $selectedMonth = $request->filled('month')
            ? $request->integer('month')
            : ($monthsByYear[$selectedYear][0] ?? (int) now()->format('n'));

        $vehicleIds = $vehicles->getCollection()->pluck('id');

        $hireTotalsByVehicle = Hire::query()
            ->whereIn('vehicle_id', $vehicleIds)
            ->counted()
            ->inMonth($selectedYear, $selectedMonth)
            ->get(['vehicle_id', 'hire_full_value', 'our_hire_value'])
            ->groupBy('vehicle_id')
            ->map(fn ($group) => [
                'hire_count' => $group->count(),
                'hire_full_value_total' => round((float) $group->sum('hire_full_value'), 2),
                'our_hire_value_total' => round((float) $group->sum('our_hire_value'), 2),
            ]);

        $summary = [
            'hire_full_value_total' => round((float) $hireTotalsByVehicle->sum('hire_full_value_total'), 2),
            'our_hire_value_total' => round((float) $hireTotalsByVehicle->sum('our_hire_value_total'), 2),
        ];

        // All-time (not period-filtered) — service/repair/parts history is
        // sporadic rather than monthly like hires, so a running lifetime
        // total is more useful here than a single month's slice.
        $maintenanceRecordsByVehicle = VehicleMaintenanceRecord::query()
            ->whereIn('vehicle_id', $vehicleIds)
            ->with('driver')
            ->latest()
            ->get()
            ->groupBy('vehicle_id');

        $maintenanceTotalsByVehicle = $maintenanceRecordsByVehicle->map(
            fn ($group) => round((float) $group->sum('cost'), 2)
        );

        return view('admin.vehicles.index', [
            'vehicles' => $vehicles,
            'search' => $request->string('search')->toString(),
            'conditions' => Vehicle::CONDITIONS,
            'hireTotalsByVehicle' => $hireTotalsByVehicle,
            'maintenanceRecordsByVehicle' => $maintenanceRecordsByVehicle,
            'maintenanceTotalsByVehicle' => $maintenanceTotalsByVehicle,
            'summary' => $summary,
            'periodLabel' => now()->setDate($selectedYear, $selectedMonth, 1)->format('F Y'),
            'availableYears' => $availableYears,
            'monthsByYear' => $monthsByYear,
            'selectedYear' => $selectedYear,
            'selectedMonth' => $selectedMonth,
        ]);
    }

    /** How many trailing months (including the current one) the revenue trend chart covers. */
    private const TREND_MONTHS = 6;

    public function show(Request $request, Vehicle $vehicle): View
    {
        // Revenue view: cancelled hires earned nothing, so they are left out.
        $hires = Hire::query()
            ->counted()
            ->where('vehicle_id', $vehicle->id)
            ->with(['customer', 'driver'])
            ->get()
            ->sortByDesc(fn (Hire $hire) => $hire->effective_month_date)
            ->values();

        $maintenanceRecords = $vehicle->maintenanceRecords()->with('driver')->latest()->get();
        $leasings = $vehicle->leasings()->with('settlements')->get();

        $summary = [
            'hire_count' => $hires->count(),
            'hire_full_value_total' => round((float) $hires->sum('hire_full_value'), 2),
            'our_hire_value_total' => round((float) $hires->sum('our_hire_value'), 2),
            'commission_total' => round((float) $hires->sum('commission'), 2),
            'maintenance_total' => round((float) $maintenanceRecords->sum('cost'), 2),
        ];
        $summary['net_revenue'] = round($summary['commission_total'] - $summary['maintenance_total'], 2);

        $now = now();
        $trend = collect(range(self::TREND_MONTHS - 1, 0))
            ->map(function (int $monthsAgo) use ($now, $hires) {
                $date = $now->copy()->subMonthsNoOverflow($monthsAgo);
                $monthHires = $hires->filter(fn (Hire $hire) => $hire->effective_month_date?->isSameMonth($date) ?? false);

                return [
                    'label' => $date->format('M Y'),
                    'hire_full_value_total' => round((float) $monthHires->sum('hire_full_value'), 2),
                    'commission_total' => round((float) $monthHires->sum('commission'), 2),
                ];
            })
            ->values();

        // Revenue by month for this one vehicle — the dropdown only ever
        // offers periods this vehicle actually has hires in.
        $periods = MonthlyPeriods::fromTimestamps($hires->pluck('effective_month_date')->filter());
        $availableYears = $periods['years'];
        $monthsByYear = $periods['months_by_year'];

        $selectedYear = $request->filled('year')
            ? $request->integer('year')
            : ($availableYears[0] ?? (int) $now->format('Y'));

        $selectedMonth = $request->filled('month')
            ? $request->integer('month')
            : ($monthsByYear[$selectedYear][0] ?? (int) $now->format('n'));

        $periodHires = $hires->filter(
            fn (Hire $hire) => $hire->effective_month_date?->year === $selectedYear
                && $hire->effective_month_date?->month === $selectedMonth
        )->values();

        $periodMaintenanceTotal = round((float) $maintenanceRecords
            ->filter(fn ($record) => $record->created_at->year === $selectedYear && $record->created_at->month === $selectedMonth)
            ->sum('cost'), 2);

        $periodSummary = [
            'hire_count' => $periodHires->count(),
            'hire_full_value_total' => round((float) $periodHires->sum('hire_full_value'), 2),
            'our_hire_value_total' => round((float) $periodHires->sum('our_hire_value'), 2),
            'commission_total' => round((float) $periodHires->sum('commission'), 2),
            'maintenance_total' => $periodMaintenanceTotal,
        ];
        $periodSummary['net_revenue'] = round($periodSummary['commission_total'] - $periodMaintenanceTotal, 2);

        return view('admin.vehicles.show', [
            'vehicle' => $vehicle,
            'periodHires' => $periodHires,
            'periodSummary' => $periodSummary,
            'periodLabel' => now()->setDate($selectedYear, $selectedMonth, 1)->format('F Y'),
            'availableYears' => $availableYears,
            'monthsByYear' => $monthsByYear,
            'selectedYear' => $selectedYear,
            'selectedMonth' => $selectedMonth,
            'maintenanceRecords' => $maintenanceRecords,
            'leasings' => $leasings,
            'summary' => $summary,
            'trend' => $trend,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $vehicle = Vehicle::create($data);

        return redirect()->route('admin.vehicles.index')->with('status', "Vehicle \"{$vehicle->model}\" was created.");
    }

    public function update(Request $request, Vehicle $vehicle): RedirectResponse
    {
        $data = $this->validated($request);

        $vehicle->update($data);

        return redirect()->route('admin.vehicles.index')->with('status', "Vehicle \"{$vehicle->model}\" was updated.");
    }

    public function destroy(Vehicle $vehicle): RedirectResponse
    {
        $vehicle->delete();

        return redirect()->route('admin.vehicles.index')->with('status', "Vehicle \"{$vehicle->model}\" was deleted.");
    }

    private function validated(Request $request): array
    {
        return $request->validate(Vehicle::rules());
    }
}
