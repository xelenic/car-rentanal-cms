<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Models\DriverDepositTransfer;
use App\Models\Hire;
use App\Models\SalaryAdvanceRequest;
use App\Models\VehicleLeasingSettlement;
use App\Models\VehicleMaintenanceRecord;
use App\Services\DriverSalaryCalculator;
use Illuminate\Support\Carbon;
use Illuminate\View\View;

class DashboardController extends Controller
{
    /** How many trailing months (including the current one) the trend chart covers. */
    private const TREND_MONTHS = 6;

    public function index(): View
    {
        $now = now();

        $current = $this->metricsFor($now);
        $previous = $this->metricsFor($now->copy()->subMonthNoOverflow());

        $summary = [
            'our_hire_value_total' => $current['our_hire_value_total'],
            'salary_total' => $current['salary_total'],
            'commission_total' => $current['commission_total'],
            'hire_full_value_total' => $current['hire_full_value_total'],
            'profit_total' => $current['profit_total'],
        ];

        $deltas = [
            'our_hire_value_total' => $this->percentDelta($current['our_hire_value_total'], $previous['our_hire_value_total']),
            'salary_total' => $this->percentDelta($current['salary_total'], $previous['salary_total']),
            'commission_total' => $this->percentDelta($current['commission_total'], $previous['commission_total']),
            'hire_full_value_total' => $this->percentDelta($current['hire_full_value_total'], $previous['hire_full_value_total']),
            'profit_total' => $this->percentDelta($current['profit_total'], $previous['profit_total']),
        ];

        $trend = collect(range(self::TREND_MONTHS - 1, 0))
            ->map(function (int $monthsAgo) use ($now) {
                $date = $now->copy()->subMonthsNoOverflow($monthsAgo);

                return array_merge(['label' => $date->format('M Y')], $this->metricsFor($date));
            })
            ->values();

        return view('admin.dashboard', [
            'summary' => $summary,
            'deltas' => $deltas,
            'trend' => $trend,
            'periodLabel' => $now->format('F Y'),
            'secondary' => $this->secondaryMetricsFor($now),
            'profitBreakdown' => $this->profitBreakdownFor($now),
        ]);
    }

    /**
     * The full working behind this month's Total Profit figure, for the
     * "why is it this number" breakdown on the dashboard's Profit card.
     */
    private function profitBreakdownFor(Carbon $date): array
    {
        $year = (int) $date->format('Y');
        $month = (int) $date->format('n');

        $data = DriverSalaryCalculator::calculateForAllDrivers($year, $month);
        $leasingInstallmentTotal = $this->leasingInstallmentTotalFor($year, $month);
        $repairCostTotal = $this->repairCostTotalFor($year, $month);

        return [
            'our_hire_value_total' => $data['our_hire_value_total'],
            'expenses_total' => $data['expenses_total'],
            'expenses_by_category' => $data['expenses_by_category'],
            'net_before_salary' => $data['net_before_salary'],
            'salary_percentage' => $data['salary_percentage'],
            'salary_total' => $data['salary'],
            'leasing_installment_total' => $leasingInstallmentTotal,
            'repair_cost_total' => $repairCostTotal,
            'profit_total' => round(
                $data['net_before_salary'] - $data['salary'] - $leasingInstallmentTotal - $repairCostTotal,
                2
            ),
        ];
    }

    /**
     * The smaller, secondary stat row — current month only, no trend/delta.
     */
    private function secondaryMetricsFor(Carbon $date): array
    {
        $year = (int) $date->format('Y');
        $month = (int) $date->format('n');

        $repairCostTotal = $this->repairCostTotalFor($year, $month);

        // "Average Day Hire Rate": the average hire_full_value among this
        // month's Day Tour hires specifically (Hire::TOUR_TYPES['day_tour']).
        $dayTourHires = Hire::query()
            ->inMonth($year, $month)
            ->where('tour_type', 'day_tour')
            ->get(['hire_full_value']);
        $avgDayHireRate = $dayTourHires->isNotEmpty()
            ? round((float) $dayTourHires->avg('hire_full_value'), 2)
            : 0.0;

        // Advances actually approved (given out) this month — not the
        // deductions recovering them, which already feed net_salary_payable.
        $salaryAdvancedTotal = round((float) SalaryAdvanceRequest::query()
            ->where('status', 'approved')
            ->whereYear('reviewed_at', $year)
            ->whereMonth('reviewed_at', $month)
            ->sum('amount'), 2);

        $creditHiresCount = Hire::query()
            ->inMonth($year, $month)
            ->where('payment_type', 'credit')
            ->count();

        $cashHiresCount = Hire::query()
            ->inMonth($year, $month)
            ->where('payment_type', 'cash')
            ->count();

        // Total outstanding deposit balance across all drivers this month —
        // each driver's shortfall clamped at 0 before summing (mirrors the
        // per-driver "Balance" on the Drivers page exactly), so one driver
        // being ahead never offsets another driver still owing.
        $pendingDepositTotal = Driver::all()->sum(function (Driver $driver) use ($year, $month) {
            $salary = DriverSalaryCalculator::calculate($driver, $year, $month);
            $transferred = (float) DriverDepositTransfer::query()
                ->where('driver_id', $driver->id)
                ->where('year', $year)
                ->where('month', $month)
                ->sum('amount');

            return max($salary['deposit_amount'] - $transferred, 0.0);
        });

        return [
            'repair_cost_total' => $repairCostTotal,
            'avg_day_hire_rate' => $avgDayHireRate,
            'salary_advanced_total' => $salaryAdvancedTotal,
            'credit_hires_count' => $creditHiresCount,
            'cash_hires_count' => $cashHiresCount,
            'pending_deposit_total' => round($pendingDepositTotal, 2),
        ];
    }

    /**
     * The dashboard metrics for the month containing $date:
     * - our_hire_value_total: what's recorded internally per hire (feeds driver salary).
     * - salary_total: the 20% driver cut across all drivers (DriverSalaryCalculator).
     * - commission_total: the company's margin per hire — hire_full_value - our_hire_value
     *   (mirrors Hire::getCommissionAttribute(), summed across the month).
     * - hire_full_value_total: the full amount charged to customers.
     * - profit_total: our_hire_value_total, minus expenses, minus the driver salary
     *   paid out of it, minus that month's leasing/loan settlements and vehicle
     *   repair costs — Our Hire Value's net_before_salary minus salary minus
     *   those two (mirrors the Drivers page's "My Profit" card, plus the
     *   fleet-financing costs it doesn't need to know about).
     */
    private function metricsFor(Carbon $date): array
    {
        $year = (int) $date->format('Y');
        $month = (int) $date->format('n');

        $data = DriverSalaryCalculator::calculateForAllDrivers($year, $month);
        $leasingInstallmentTotal = $this->leasingInstallmentTotalFor($year, $month);
        $repairCostTotal = $this->repairCostTotalFor($year, $month);

        return [
            'our_hire_value_total' => $data['our_hire_value_total'],
            'salary_total' => $data['salary'],
            'commission_total' => round($data['hire_full_value_total'] - $data['our_hire_value_total'], 2),
            'hire_full_value_total' => $data['hire_full_value_total'],
            'profit_total' => round(
                $data['net_before_salary'] - $data['salary'] - $leasingInstallmentTotal - $repairCostTotal,
                2
            ),
        ];
    }

    /**
     * Vehicle service/repair/parts costs actually logged in the given month
     * (see VehicleMaintenanceController) — a real cash cost, not a category
     * that reduces driver salary.
     */
    private function repairCostTotalFor(int $year, int $month): float
    {
        return round((float) VehicleMaintenanceRecord::query()
            ->whereYear('created_at', $year)
            ->whereMonth('created_at', $month)
            ->sum('cost'), 2);
    }

    /**
     * Leasing/loan settlements actually paid in the given month (see
     * VehicleLeasingSettlementController) — across every vehicle's
     * financing record, not just active ones, since a settlement is a real
     * cash outflow regardless of the record's current status.
     */
    private function leasingInstallmentTotalFor(int $year, int $month): float
    {
        return round((float) VehicleLeasingSettlement::query()
            ->where('year', $year)
            ->where('month', $month)
            ->sum('amount'), 2);
    }

    /**
     * Percent change vs. the previous month. Null means "not computable"
     * (previous was zero but current isn't) — the view renders that as "New".
     */
    private function percentDelta(float $current, float $previous): ?float
    {
        if (abs($previous) < 0.005) {
            return abs($current) < 0.005 ? 0.0 : null;
        }

        return round((($current - $previous) / abs($previous)) * 100, 1);
    }
}
