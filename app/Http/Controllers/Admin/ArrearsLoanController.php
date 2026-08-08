<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Models\DriverArrearsLoan;
use App\Models\DriverDepositTransfer;
use App\Services\DriverArrearsLoanScheduler;
use App\Services\DriverSalaryCalculator;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ArrearsLoanController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:payroll.manage', only: ['store']),
        ];
    }

    public function store(Request $request, Driver $driver): RedirectResponse
    {
        $data = $request->validate([
            'year' => ['required', 'integer', 'min:2000', 'max:2100'],
            'month' => ['required', 'integer', 'min:1', 'max:12'],
            'deduction_type' => ['required', Rule::in(array_keys(DriverArrearsLoan::DEDUCTION_TYPES))],
            'installment_months' => ['required_if:deduction_type,installments', 'nullable', 'integer', 'min:1', 'max:60'],
            'search' => ['nullable', 'string'],
        ]);

        $year = (int) $data['year'];
        $month = (int) $data['month'];

        // Recompute the deficit server-side rather than trusting a
        // client-submitted amount — it's derived fresh from the same
        // figures the modal displayed, so it can't drift or be tampered
        // with between page render and submit.
        $unresolvedDeficit = $this->currentUnresolvedDeficit($driver, $year, $month);

        if ($unresolvedDeficit >= 0) {
            return $this->back($data)->with('error', 'There is no deficit for this period — there is nothing to convert.');
        }

        $amount = round(abs($unresolvedDeficit), 2);

        DB::transaction(function () use ($driver, $year, $month, $data, $request, $amount) {
            $loan = DriverArrearsLoan::create([
                'driver_id' => $driver->id,
                'source_year' => $year,
                'source_month' => $month,
                'amount' => $amount,
                'deduction_type' => $data['deduction_type'],
                'created_by' => $request->user()->id,
            ]);

            DriverArrearsLoanScheduler::schedule(
                $loan,
                $data['deduction_type'],
                $data['installment_months'] ?? null,
            );
        });

        return $this->back($data)->with('status', "Converted \${$this->money($amount)} of \"{$driver->name}\"'s deficit into an arrears loan.");
    }

    private function currentUnresolvedDeficit(Driver $driver, int $year, int $month): float
    {
        $salary = DriverSalaryCalculator::calculate($driver, $year, $month);

        $transferredTotal = (float) DriverDepositTransfer::query()
            ->where('driver_id', $driver->id)
            ->where('year', $year)
            ->where('month', $month)
            ->sum('amount');

        $existingArrears = (float) DriverArrearsLoan::query()
            ->where('driver_id', $driver->id)
            ->where('source_year', $year)
            ->where('source_month', $month)
            ->sum('amount');

        $remaining = round($salary['deposit_amount'] - $transferredTotal - $existingArrears, 2);

        return round($salary['net_salary_payable'] - $remaining, 2);
    }

    private function money(float $amount): string
    {
        return number_format($amount, 2);
    }

    private function back(array $data): RedirectResponse
    {
        return redirect()->route('admin.drivers.index', array_filter([
            'year' => $data['year'] ?? null,
            'month' => $data['month'] ?? null,
            'search' => $data['search'] ?? null,
        ]));
    }
}
