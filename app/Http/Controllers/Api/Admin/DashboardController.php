<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Vehicle;
use App\Services\DriverSalaryCalculator;
use App\Services\ProfitCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * The admin mobile app's Overview page: the same six summary figures and
 * per-vehicle breakdown as the web panel's Dashboard
 * (Admin\DashboardController) — reusing the exact same calculation services
 * so the numbers can never drift between the two.
 */
class DashboardController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        abort_unless($request->user()->can('drivers.view'), 403, 'You do not have permission to view the dashboard.');

        $year = $request->filled('year') ? $request->integer('year') : (int) now()->format('Y');
        $month = $request->filled('month') ? $request->integer('month') : (int) now()->format('n');
        $date = Carbon::create($year, $month, 1);

        $current = $this->metricsFor($date);
        $previous = $this->metricsFor($date->copy()->subMonthNoOverflow());

        $summary = [
            'hire_full_value_total' => $current['hire_full_value_total'],
            'our_hire_value_total' => $current['our_hire_value_total'],
            'commission_total' => $current['commission_total'],
            'expenses_total' => $current['expenses_total'],
            'salary_total' => $current['salary_total'],
            'profit_total' => $current['profit_total'],
        ];

        $deltas = [
            'hire_full_value_total' => $this->percentDelta($current['hire_full_value_total'], $previous['hire_full_value_total']),
            'our_hire_value_total' => $this->percentDelta($current['our_hire_value_total'], $previous['our_hire_value_total']),
            'commission_total' => $this->percentDelta($current['commission_total'], $previous['commission_total']),
            'expenses_total' => $this->percentDelta($current['expenses_total'], $previous['expenses_total']),
            'salary_total' => $this->percentDelta($current['salary_total'], $previous['salary_total']),
            'profit_total' => $this->percentDelta($current['profit_total'], $previous['profit_total']),
        ];

        return response()->json([
            'year' => $year,
            'month' => $month,
            'period_label' => $date->format('F Y'),
            'summary' => $summary,
            'deltas' => $deltas,
            'vehicle_cards' => $this->vehicleCardsFor($date),
        ]);
    }

    /**
     * The same six summary figures as the main response, one set per
     * vehicle — see Admin\DashboardController::vehicleCardsFor() (the web
     * dashboard's identical section) for the full rationale.
     */
    private function vehicleCardsFor(Carbon $date): array
    {
        $year = (int) $date->format('Y');
        $month = (int) $date->format('n');

        return Vehicle::all()->map(function (Vehicle $vehicle) use ($year, $month) {
            $data = DriverSalaryCalculator::calculateForVehicle($vehicle, $year, $month);
            $leasingInstallmentTotal = ProfitCalculator::leasingInstallmentTotalForVehicle($vehicle, $year, $month);
            $repairCostTotal = ProfitCalculator::repairCostTotalForVehicle($vehicle, $year, $month);

            return [
                'id' => $vehicle->id,
                'model' => $vehicle->model,
                'condition' => $vehicle->condition,
                'hire_full_value_total' => $data['hire_full_value_total'],
                'our_hire_value_total' => $data['our_hire_value_total'],
                'commission_total' => round($data['hire_full_value_total'] - $data['our_hire_value_total'], 2),
                'expenses_total' => $data['expenses_total'],
                'salary_total' => $data['salary'],
                'profit_total' => ProfitCalculator::profitFrom($data, $leasingInstallmentTotal, $repairCostTotal),
            ];
        })->values()->all();
    }

    /** Same formula as Admin\DashboardController::metricsFor() — see there for the full field-by-field rationale. */
    private function metricsFor(Carbon $date): array
    {
        $year = (int) $date->format('Y');
        $month = (int) $date->format('n');

        $data = DriverSalaryCalculator::calculateForAllDrivers($year, $month);

        return [
            'our_hire_value_total' => $data['our_hire_value_total'],
            'salary_total' => $data['salary'],
            'commission_total' => round($data['hire_full_value_total'] - $data['our_hire_value_total'], 2),
            'hire_full_value_total' => $data['hire_full_value_total'],
            'expenses_total' => $data['expenses_total'],
            'profit_total' => ProfitCalculator::profitFrom(
                $data,
                ProfitCalculator::leasingInstallmentTotalFor($year, $month),
                ProfitCalculator::repairCostTotalFor($year, $month),
            ),
        ];
    }

    /**
     * Percent change vs. the previous month. Null means "not computable"
     * (previous was zero but current isn't) — the app renders that as "New".
     */
    private function percentDelta(float $current, float $previous): ?float
    {
        if (abs($previous) < 0.005) {
            return abs($current) < 0.005 ? 0.0 : null;
        }

        return round((($current - $previous) / abs($previous)) * 100, 1);
    }
}
