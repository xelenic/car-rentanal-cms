<?php

namespace App\Services;

use App\Models\SalaryAdvanceDeduction;
use App\Models\SalaryAdvanceRequest;
use Carbon\Carbon;

/**
 * Builds the month-by-month deduction schedule for an approved salary
 * advance request: either the full amount taken from this month's salary,
 * or a partial amount this month with the remaining balance split evenly
 * across a chosen number of upcoming months (last installment absorbs any
 * rounding remainder so the total always matches exactly).
 */
class SalaryAdvanceScheduler
{
    public static function schedule(
        SalaryAdvanceRequest $request,
        string $deductionType,
        ?float $thisMonthAmount = null,
        ?int $installmentMonths = null,
    ): void {
        // Replays cleanly if a request is ever re-approved with new terms.
        $request->deductions()->delete();

        $amount = round((float) $request->amount, 2);
        $now = Carbon::now();

        if ($deductionType === 'full') {
            SalaryAdvanceDeduction::create([
                'salary_advance_request_id' => $request->id,
                'driver_id' => $request->driver_id,
                'year' => (int) $now->format('Y'),
                'month' => (int) $now->format('n'),
                'amount' => $amount,
            ]);

            return;
        }

        $thisMonthAmount = round(min(max($thisMonthAmount ?? 0, 0), $amount), 2);
        $remaining = round($amount - $thisMonthAmount, 2);
        $months = max($installmentMonths ?? 1, 1);

        if ($thisMonthAmount > 0) {
            SalaryAdvanceDeduction::create([
                'salary_advance_request_id' => $request->id,
                'driver_id' => $request->driver_id,
                'year' => (int) $now->format('Y'),
                'month' => (int) $now->format('n'),
                'amount' => $thisMonthAmount,
            ]);
        }

        if ($remaining <= 0) {
            return;
        }

        $perMonth = floor(($remaining / $months) * 100) / 100;
        $allocated = 0.0;

        for ($i = 1; $i <= $months; $i++) {
            $target = $now->copy()->addMonthsNoOverflow($i);
            $installmentAmount = $i === $months
                ? round($remaining - $allocated, 2)
                : $perMonth;

            SalaryAdvanceDeduction::create([
                'salary_advance_request_id' => $request->id,
                'driver_id' => $request->driver_id,
                'year' => (int) $target->format('Y'),
                'month' => (int) $target->format('n'),
                'amount' => $installmentAmount,
            ]);

            $allocated = round($allocated + $installmentAmount, 2);
        }
    }
}
