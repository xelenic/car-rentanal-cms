<?php

namespace App\Services;

use App\Models\VehicleLeasingSettlement;
use App\Models\VehicleMaintenanceRecord;

/**
 * The company's profit for a month — the one place the formula lives, so the
 * dashboard's Total Profit card and the My Expenses page can't drift apart:
 *
 *   Our Hire Value − hire expenses − driver salary − leasing installments − repair costs
 *
 * (The first three are DriverSalaryCalculator's net_before_salary − salary.)
 */
class ProfitCalculator
{
    /**
     * The full working behind the profit figure, month by month.
     *
     * @return array<string, mixed>
     */
    public static function breakdownFor(int $year, int $month): array
    {
        $data = DriverSalaryCalculator::calculateForAllDrivers($year, $month);
        $leasingInstallmentTotal = self::leasingInstallmentTotalFor($year, $month);
        $repairCostTotal = self::repairCostTotalFor($year, $month);

        return [
            'our_hire_value_total' => $data['our_hire_value_total'],
            'expenses_total' => $data['expenses_total'],
            'expenses_by_category' => $data['expenses_by_category'],
            'net_before_salary' => $data['net_before_salary'],
            'salary_percentage' => $data['salary_percentage'],
            'salary_total' => $data['salary'],
            'leasing_installment_total' => $leasingInstallmentTotal,
            'repair_cost_total' => $repairCostTotal,
            'profit_total' => self::profitFrom($data, $leasingInstallmentTotal, $repairCostTotal),
        ];
    }

    /**
     * The profit given a month's DriverSalaryCalculator result and its
     * leasing and repair totals — for callers that already have those.
     *
     * @param  array<string, mixed>  $salaryData  from DriverSalaryCalculator::calculateForAllDrivers()
     */
    public static function profitFrom(array $salaryData, float $leasingInstallmentTotal, float $repairCostTotal): float
    {
        return round(
            $salaryData['net_before_salary'] - $salaryData['salary'] - $leasingInstallmentTotal - $repairCostTotal,
            2
        );
    }

    /**
     * Vehicle service/repair/parts costs actually logged in the given month
     * (see VehicleMaintenanceController) — a real cash cost, not a category
     * that reduces driver salary.
     */
    public static function repairCostTotalFor(int $year, int $month): float
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
    public static function leasingInstallmentTotalFor(int $year, int $month): float
    {
        return round((float) VehicleLeasingSettlement::query()
            ->where('year', $year)
            ->where('month', $month)
            ->sum('amount'), 2);
    }
}
