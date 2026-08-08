<?php

namespace App\Services;

use App\Models\DriverArrearsLoan;
use App\Models\DriverArrearsLoanDeduction;
use Carbon\Carbon;

/**
 * Builds the month-by-month deduction schedule for an arrears loan: either
 * the full amount taken from next month's salary, or the amount split
 * evenly across a chosen number of upcoming months starting next month
 * (last installment absorbs any rounding remainder so the total always
 * matches exactly). Unlike a salary advance, none of it can be deducted
 * from the source month itself — that month's payable is already at or
 * below zero, which is exactly why the loan exists.
 */
class DriverArrearsLoanScheduler
{
    public static function schedule(
        DriverArrearsLoan $loan,
        string $deductionType,
        ?int $installmentMonths = null,
    ): void {
        // Replays cleanly if a loan is ever rescheduled.
        $loan->deductions()->delete();

        $amount = round((float) $loan->amount, 2);
        $anchor = Carbon::create((int) $loan->source_year, (int) $loan->source_month, 1);

        if ($deductionType === 'full') {
            $target = $anchor->copy()->addMonthNoOverflow();

            DriverArrearsLoanDeduction::create([
                'arrears_loan_id' => $loan->id,
                'driver_id' => $loan->driver_id,
                'year' => (int) $target->format('Y'),
                'month' => (int) $target->format('n'),
                'amount' => $amount,
            ]);

            return;
        }

        $months = max($installmentMonths ?? 1, 1);
        $perMonth = floor(($amount / $months) * 100) / 100;
        $allocated = 0.0;

        for ($i = 1; $i <= $months; $i++) {
            $target = $anchor->copy()->addMonthsNoOverflow($i);
            $installmentAmount = $i === $months
                ? round($amount - $allocated, 2)
                : $perMonth;

            DriverArrearsLoanDeduction::create([
                'arrears_loan_id' => $loan->id,
                'driver_id' => $loan->driver_id,
                'year' => (int) $target->format('Y'),
                'month' => (int) $target->format('n'),
                'amount' => $installmentAmount,
            ]);

            $allocated = round($allocated + $installmentAmount, 2);
        }
    }
}
