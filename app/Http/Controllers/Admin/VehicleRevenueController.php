<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Hire;
use App\Models\Vehicle;
use App\Models\VehicleMaintenanceRecord;
use App\Support\MonthlyPeriods;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;

/**
 * A dedicated, vehicle-by-vehicle revenue report — separate from the
 * Vehicles management page (which shows the same period's hire totals
 * inline, but mixed in with fleet CRUD and without the commission/net
 * figures a revenue report needs).
 */
class VehicleRevenueController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:vehicles.view'),
        ];
    }

    public function index(Request $request): View
    {
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

        $vehicles = Vehicle::query()->orderBy('model')->get();
        $vehicleIds = $vehicles->pluck('id');

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
                'commission_total' => round((float) $group->sum(fn ($hire) => $hire->hire_full_value - $hire->our_hire_value), 2),
            ]);

        // Maintenance is scoped to the same period here (unlike the Vehicles
        // page's lifetime total) so "Net Revenue" reflects what the vehicle
        // actually earned that month, not a running repair history.
        $maintenanceTotalsByVehicle = VehicleMaintenanceRecord::query()
            ->whereIn('vehicle_id', $vehicleIds)
            ->whereYear('created_at', $selectedYear)
            ->whereMonth('created_at', $selectedMonth)
            ->get(['vehicle_id', 'cost'])
            ->groupBy('vehicle_id')
            ->map(fn ($group) => round((float) $group->sum('cost'), 2));

        $rows = $vehicles->map(function (Vehicle $vehicle) use ($hireTotalsByVehicle, $maintenanceTotalsByVehicle) {
            $totals = $hireTotalsByVehicle->get($vehicle->id, [
                'hire_count' => 0,
                'hire_full_value_total' => 0.0,
                'our_hire_value_total' => 0.0,
                'commission_total' => 0.0,
            ]);
            $maintenanceTotal = $maintenanceTotalsByVehicle->get($vehicle->id, 0.0);

            return [
                'vehicle' => $vehicle,
                'hire_count' => $totals['hire_count'],
                'hire_full_value_total' => $totals['hire_full_value_total'],
                'our_hire_value_total' => $totals['our_hire_value_total'],
                'commission_total' => $totals['commission_total'],
                'maintenance_total' => $maintenanceTotal,
                'net_revenue' => round($totals['commission_total'] - $maintenanceTotal, 2),
            ];
        })->sortByDesc('commission_total')->values();

        $summary = [
            'hire_full_value_total' => round((float) $rows->sum('hire_full_value_total'), 2),
            'our_hire_value_total' => round((float) $rows->sum('our_hire_value_total'), 2),
            'commission_total' => round((float) $rows->sum('commission_total'), 2),
            'maintenance_total' => round((float) $rows->sum('maintenance_total'), 2),
            'net_revenue' => round((float) $rows->sum('net_revenue'), 2),
        ];

        return view('admin.vehicle-revenue.index', [
            'rows' => $rows,
            'summary' => $summary,
            'periodLabel' => now()->setDate($selectedYear, $selectedMonth, 1)->format('F Y'),
            'availableYears' => $availableYears,
            'monthsByYear' => $monthsByYear,
            'selectedYear' => $selectedYear,
            'selectedMonth' => $selectedMonth,
        ]);
    }
}
