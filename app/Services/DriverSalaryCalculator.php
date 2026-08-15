<?php

namespace App\Services;

use App\Models\Driver;
use App\Models\DriverArrearsLoanDeduction;
use App\Models\DriverPayroll;
use App\Models\DriverPayrollCarryover;
use App\Models\Hire;
use App\Models\HireExpense;
use App\Models\SalaryAdvanceDeduction;
use Illuminate\Contracts\Database\Eloquent\Builder;

/**
 * Shared driver monthly salary calculation, used by both the driver app's
 * API and the admin panel so the formula only lives in one place.
 */
class DriverSalaryCalculator
{
    /**
     * Categories deducted from the "Our Hire Value" total before the
     * driver's salary cut is calculated.
     */
    public const DEDUCTIBLE_CATEGORIES = ['fuel', 'highway', 'food', 'room', 'parking'];

    public const SALARY_PERCENTAGE = 20;

    public static function calculate(Driver $driver, int $year, int $month): array
    {
        return self::calculateForQuery($driver->hires(), $year, $month, $driver->id);
    }

    /**
     * Same breakdown, but aggregated across every driver's hires — used for
     * the admin panel's system-wide summary card.
     */
    public static function calculateForAllDrivers(int $year, int $month): array
    {
        return self::calculateForQuery(Hire::query(), $year, $month, null);
    }

    private static function calculateForQuery(Builder $query, int $year, int $month, ?int $driverId): array
    {
        $hires = $query
            ->inMonth($year, $month)
            ->get(['id', 'our_hire_value', 'hire_full_value', 'payment_type']);

        $ourHireValueTotal = round((float) $hires->sum('our_hire_value'), 2);

        $hireFullValueTotal = round((float) $hires->sum('hire_full_value'), 2);
        $hireFullValueByPaymentType = $hires
            ->groupBy('payment_type')
            ->map(fn ($group) => round((float) $group->sum('hire_full_value'), 2));

        // Expenses tied to one of this month's hires (attributed by the
        // hire's month, as before) plus expenses logged without a hire —
        // from the driver app's Options page — attributed by the month
        // they were actually logged in instead.
        $expensesByCategory = HireExpense::query()
            ->where(function ($query) use ($hires, $driverId, $year, $month) {
                $query->whereIn('hire_id', $hires->pluck('id'))
                    ->orWhere(function ($query) use ($driverId, $year, $month) {
                        $query->whereNull('hire_id')
                            ->whereYear('created_at', $year)
                            ->whereMonth('created_at', $month);

                        if ($driverId !== null) {
                            $query->where('driver_id', $driverId);
                        }
                    });
            })
            ->whereIn('category', self::DEDUCTIBLE_CATEGORIES)
            ->get()
            ->groupBy('category')
            ->map(fn ($group) => round((float) $group->sum('amount'), 2));

        $expensesTotal = round(
            collect(self::DEDUCTIBLE_CATEGORIES)->sum(fn ($category) => $expensesByCategory->get($category, 0.0)),
            2
        );

        $netBeforeSalary = round($ourHireValueTotal - $expensesTotal, 2);
        $salary = round($netBeforeSalary * (self::SALARY_PERCENTAGE / 100), 2);

        $advanceDeductionQuery = SalaryAdvanceDeduction::query()
            ->where('year', $year)
            ->where('month', $month);

        if ($driverId !== null) {
            $advanceDeductionQuery->where('driver_id', $driverId);
        }

        $advanceDeductionTotal = round((float) $advanceDeductionQuery->sum('amount'), 2);

        // A shortfall carried forward from a previous month's payroll (see
        // below) is an extra deduction against this month's salary, exactly
        // like a salary advance deduction.
        $carryoverQuery = DriverPayrollCarryover::query()
            ->where('year', $year)
            ->where('month', $month);

        if ($driverId !== null) {
            $carryoverQuery->where('driver_id', $driverId);
        }

        $carryoverDeductionTotal = round((float) $carryoverQuery->sum('amount'), 2);

        // An arrears loan (a negative Net Payment deliberately converted by
        // an admin into a scheduled repayment — see DriverArrearsLoanScheduler)
        // deducts from future salary the same way.
        $arrearsQuery = DriverArrearsLoanDeduction::query()
            ->where('year', $year)
            ->where('month', $month);

        if ($driverId !== null) {
            $arrearsQuery->where('driver_id', $driverId);
        }

        $arrearsDeductionTotal = round((float) $arrearsQuery->sum('amount'), 2);
        $netSalaryPayable = round(max($salary - $advanceDeductionTotal - $carryoverDeductionTotal - $arrearsDeductionTotal, 0), 2);

        // A driver's payroll being marked "paid" is a snapshot taken at
        // finalize-time — it does not shrink if the driver keeps taking
        // hires afterwards in the same month. So "amount due" is always the
        // live total minus whatever entitlement that snapshot already
        // accounted for, not just zeroed out forever the moment any payment
        // happens this month. We use the pre-adjustment snapshot (not the
        // final cash amount) as that baseline: a manual correction settles
        // the month's entitlement even when it makes the payout negative —
        // the negative remainder is carried forward separately instead of
        // leaving this month looking perpetually unpaid.
        $payroll = $driverId !== null
            ? DriverPayroll::query()
                ->where('driver_id', $driverId)
                ->where('year', $year)
                ->where('month', $month)
                ->where('status', 'paid')
                ->first()
            : null;

        $paidAmount = $payroll !== null ? max((float) $payroll->final_amount, 0.0) : 0.0;
        $alreadyAccountedFor = $payroll !== null ? (float) $payroll->net_before_adjustment : 0.0;
        $amountDue = round(max($netSalaryPayable - $alreadyAccountedFor, 0), 2);
        $isPaid = $payroll !== null && $amountDue <= 0;

        // Cash the driver is holding that should be handed over to the
        // company: total hire value minus whatever was already settled by
        // credit, minus expenses the driver already paid out of pocket.
        // Mirrors the driver app's own DriverSalary.depositAmount getter.
        $creditTotal = $hireFullValueByPaymentType->get('credit', 0.0);
        $depositAmount = round($hireFullValueTotal - $creditTotal - $expensesTotal, 2);

        return [
            'year' => $year,
            'month' => $month,
            'hire_count' => $hires->count(),
            'our_hire_value_total' => $ourHireValueTotal,
            'hire_full_value_total' => $hireFullValueTotal,
            'hire_full_value_by_payment_type' => collect(Hire::PAYMENT_TYPES)->keys()->mapWithKeys(
                fn ($type) => [$type => $hireFullValueByPaymentType->get($type, 0.0)]
            )->all(),
            'expenses_total' => $expensesTotal,
            'expenses_by_category' => collect(self::DEDUCTIBLE_CATEGORIES)->mapWithKeys(
                fn ($category) => [$category => $expensesByCategory->get($category, 0.0)]
            )->all(),
            'net_before_salary' => $netBeforeSalary,
            'salary_percentage' => self::SALARY_PERCENTAGE,
            'salary' => $salary,
            'advance_deduction_total' => $advanceDeductionTotal,
            'carryover_deduction_total' => $carryoverDeductionTotal,
            'arrears_deduction_total' => $arrearsDeductionTotal,
            'net_salary_payable' => $netSalaryPayable,
            'is_paid' => $isPaid,
            'paid_amount' => $paidAmount,
            'paid_at' => $payroll?->paid_at?->toIso8601String(),
            'amount_due' => $amountDue,
            'deposit_amount' => $depositAmount,
        ];
    }
}
