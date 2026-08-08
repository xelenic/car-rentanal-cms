<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\DriverSalaryCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DriverSalaryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $year = $request->filled('year') ? $request->integer('year') : (int) now()->format('Y');
        $month = $request->filled('month') ? $request->integer('month') : (int) now()->format('n');

        $calculation = DriverSalaryCalculator::calculate($driver, $year, $month);

        // Mirrors the admin panel's Deposit section on the driver salary
        // modal (see admin.drivers.index) so the driver app shows the exact
        // same deposit-adjusted numbers.
        $transferredTotal = round((float) $driver->depositTransfers()
            ->where('year', $year)
            ->where('month', $month)
            ->sum('amount'), 2);

        $arrearsLoans = $driver->arrearsLoans()
            ->where('source_year', $year)
            ->where('source_month', $month)
            ->with('deductions')
            ->get();

        $arrearsLoanTotal = round((float) $arrearsLoans->sum('amount'), 2);

        // Balance: plain cash-flow figure — deposit owed minus what's
        // physically been transferred so far. Floored at 0 for display.
        $balance = round($calculation['deposit_amount'] - $transferredTotal, 2);
        $balanceDisplay = max($balance, 0.0);
        $netPayableBase = $calculation['net_salary_payable'];
        $finalNetPayable = round($netPayableBase - $balance, 2);

        // Once the admin has converted this period's shortfall into an
        // Arrears Loan, the driver has effectively already "received" that
        // amount as a loan to settle their deposit — so what's actually
        // still payable in cash is the raw deficit plus the loan covering
        // it, which nets out to (approximately) zero. Mirrors the admin
        // panel's payroll "Final Payable" preview exactly.
        $settledNetPayable = round($finalNetPayable + $arrearsLoanTotal, 2);

        $calculation['deposit'] = [
            'transferred_total' => $transferredTotal,
            'balance' => $balanceDisplay,
            'final_net_payable' => $finalNetPayable,
            'arrears_loan_total' => $arrearsLoanTotal,
            'settled_net_payable' => $settledNetPayable,
            'arrears_loans' => $arrearsLoans->map(fn ($loan) => [
                'id' => $loan->id,
                'amount' => round((float) $loan->amount, 2),
                'deduction_type' => $loan->deduction_type,
                'deduction_type_label' => $loan->deduction_type_label,
                'deductions' => $loan->deductions->map(fn ($deduction) => [
                    'year' => $deduction->year,
                    'month' => $deduction->month,
                    'amount' => round((float) $deduction->amount, 2),
                ])->values(),
            ])->values(),
        ];

        return response()->json($calculation);
    }
}
