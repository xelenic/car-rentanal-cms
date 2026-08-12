<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Models\DriverArrearsLoan;
use App\Models\DriverDepositTransfer;
use App\Models\DriverPayroll;
use App\Models\DriverPayrollCarryover;
use App\Services\DriverSalaryCalculator;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class PayrollController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:payroll.manage', only: ['finalize', 'markPaid', 'revert']),
            new Middleware('permission:drivers.view', only: ['slip']),
        ];
    }

    public function finalize(Request $request, Driver $driver): RedirectResponse
    {
        $data = $request->validate([
            'year' => ['required', 'integer', 'min:2000', 'max:2100'],
            'month' => ['required', 'integer', 'min:1', 'max:12'],
            'manual_adjustment' => ['nullable', 'numeric'],
            'adjustment_note' => ['nullable', 'string', 'max:1000'],
            'search' => ['nullable', 'string'],
        ]);

        $existing = DriverPayroll::query()
            ->where('driver_id', $driver->id)
            ->where('year', $data['year'])
            ->where('month', $data['month'])
            ->first();

        if ($existing && $existing->status === 'paid') {
            return $this->back($data)->with('error', "Payroll for \"{$driver->name}\" is already paid and can no longer be modified.");
        }

        $calculation = DriverSalaryCalculator::calculate($driver, (int) $data['year'], (int) $data['month']);
        $manualAdjustment = round((float) ($data['manual_adjustment'] ?? 0), 2);

        // The driver's outstanding cash deposit for this same period reduces
        // what's actually payable — unless (and to the extent) that shortfall
        // has already been converted into an arrears loan, in which case it's
        // being recovered via future salary deductions instead, so it's
        // added back here to avoid deducting it twice.
        $transferredTotal = (float) DriverDepositTransfer::query()
            ->where('driver_id', $driver->id)
            ->where('year', $data['year'])
            ->where('month', $data['month'])
            ->sum('amount');

        $arrearsLoanOffset = (float) DriverArrearsLoan::query()
            ->where('driver_id', $driver->id)
            ->where('source_year', $data['year'])
            ->where('source_month', $data['month'])
            ->sum('amount');

        $depositBalance = round($calculation['deposit_amount'] - $transferredTotal, 2);
        $finalAmount = round($calculation['net_salary_payable'] - $depositBalance + $arrearsLoanOffset + $manualAdjustment, 2);

        DriverPayroll::updateOrCreate(
            ['driver_id' => $driver->id, 'year' => $data['year'], 'month' => $data['month']],
            [
                'hire_count' => $calculation['hire_count'],
                'our_hire_value_total' => $calculation['our_hire_value_total'],
                'expenses_total' => $calculation['expenses_total'],
                'salary' => $calculation['salary'],
                'advance_deduction_total' => $calculation['advance_deduction_total'],
                'carryover_deduction_total' => $calculation['carryover_deduction_total'],
                'arrears_deduction_total' => $calculation['arrears_deduction_total'],
                'deposit_balance' => $depositBalance,
                'arrears_loan_offset' => $arrearsLoanOffset,
                'net_before_adjustment' => $calculation['net_salary_payable'],
                'manual_adjustment' => $manualAdjustment,
                'adjustment_note' => $data['adjustment_note'] ?? null,
                'final_amount' => $finalAmount,
                'status' => 'finalized',
                'finalized_by' => $request->user()->id,
                'finalized_at' => now(),
            ]
        );

        return $this->back($data)->with('status', "Payroll finalized for \"{$driver->name}\".");
    }

    public function markPaid(Request $request, Driver $driver, DriverPayroll $payroll): RedirectResponse
    {
        abort_unless($payroll->driver_id === $driver->id, 404);

        $data = $request->validate([
            'year' => ['required', 'integer'],
            'month' => ['required', 'integer'],
            'search' => ['nullable', 'string'],
        ]);

        if ($payroll->status !== 'finalized') {
            return $this->back($data)->with('error', 'Only a finalized payroll can be marked as paid.');
        }

        $carryoverNote = '';

        DB::transaction(function () use ($payroll, $request, &$carryoverNote) {
            $payroll->update([
                'status' => 'paid',
                'paid_by' => $request->user()->id,
                'paid_at' => now(),
            ]);

            $finalAmount = (float) $payroll->final_amount;

            if ($finalAmount < 0) {
                $deficit = round(abs($finalAmount), 2);
                $target = Carbon::create($payroll->year, $payroll->month, 1)->addMonthNoOverflow();

                DriverPayrollCarryover::create([
                    'driver_id' => $payroll->driver_id,
                    'source_payroll_id' => $payroll->id,
                    'year' => (int) $target->format('Y'),
                    'month' => (int) $target->format('n'),
                    'amount' => $deficit,
                ]);

                $carryoverNote = ' This payroll had a shortfall of Rs. '.number_format($deficit, 2)
                    .', which was carried forward as a deduction on '.$target->format('F Y').'\'s salary.';
            }
        });

        return $this->back($data)->with('status', "Payroll for \"{$driver->name}\" was marked as paid.".$carryoverNote);
    }

    /**
     * Undo a finalized-but-not-yet-paid payroll, deleting the snapshot so
     * the admin can re-run "Make Payroll" with different figures. Paid
     * payrolls are never revertible here — that's cash already settled
     * (and possibly already carried forward), not a draft to discard.
     */
    public function revert(Request $request, Driver $driver, DriverPayroll $payroll): RedirectResponse
    {
        abort_unless($payroll->driver_id === $driver->id, 404);

        $data = $request->validate([
            'year' => ['required', 'integer'],
            'month' => ['required', 'integer'],
            'search' => ['nullable', 'string'],
        ]);

        if ($payroll->status !== 'finalized') {
            return $this->back($data)->with('error', 'Only a finalized (not yet paid) payroll can be reverted.');
        }

        $payroll->delete();

        return $this->back($data)->with('status', "Payroll finalization for \"{$driver->name}\" was reverted.");
    }

    /**
     * Stream a printable PDF salary slip for a finalized (or paid) payroll.
     */
    public function slip(Driver $driver, DriverPayroll $payroll): Response
    {
        abort_unless($payroll->driver_id === $driver->id, 404);

        $payroll->load(['finalizedBy', 'paidBy']);

        $periodLabel = Carbon::create((int) $payroll->year, (int) $payroll->month, 1)->format('F Y');

        $pdf = Pdf::loadView('admin.drivers.salary-slip', [
            'driver' => $driver,
            'payroll' => $payroll,
            'periodLabel' => $periodLabel,
        ])->setPaper('a4');

        $filename = 'salary-slip-'.Str::slug($driver->name).'-'.$payroll->year.'-'.str_pad((string) $payroll->month, 2, '0', STR_PAD_LEFT).'.pdf';

        return $pdf->stream($filename);
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
