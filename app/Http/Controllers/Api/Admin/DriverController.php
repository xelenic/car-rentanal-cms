<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\DriverResource;
use App\Http\Resources\DriverExpenseResource;
use App\Models\Driver;
use App\Models\DriverArrearsLoan;
use App\Models\DriverDepositTransfer;
use App\Models\DriverPayroll;
use App\Models\HireExpense;
use App\Models\User;
use App\Services\DriverSalaryCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

/**
 * The admin mobile app's Drivers API: the roster, adding, editing and
 * removing a driver. Mirrors the web panel's Admin\DriverController for the
 * fields this app manages, minus the two optional document uploads (no
 * multipart precedent exists in this app, and the web form treats them as
 * optional too) — a driver here is always also a User with the Driver role,
 * exactly as the web panel creates them.
 */
class DriverController extends Controller
{
    private const PER_PAGE = 20;

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorizeView($request);

        $drivers = Driver::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('contact_number', 'like', "%{$search}%");
                });
            })
            ->orderBy('name')
            ->paginate(self::PER_PAGE);

        return DriverResource::collection($drivers);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless($request->user()->can('drivers.create'), 403, 'You do not have permission to add drivers.');

        $data = $this->validated($request);

        $driver = DB::transaction(function () use ($data) {
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'],
                'password' => Hash::make($data['password']),
            ]);
            $user->syncRoles(['Driver']);

            return Driver::create([
                ...$data,
                'user_id' => $user->id,
                'password' => Hash::make($data['password']),
            ]);
        });

        return (new DriverResource($driver))->response()->setStatusCode(201);
    }

    public function show(Request $request, Driver $driver): DriverResource
    {
        $this->authorizeView($request);

        return new DriverResource($driver);
    }

    /**
     * This driver's Overview tab: one month's earnings (the same
     * DriverSalaryCalculator formula as the web panel's driver page and the
     * admin app's own company-wide dashboard) — defaults to the current
     * month, same as GET /admin/dashboard.
     */
    public function summary(Request $request, Driver $driver): JsonResponse
    {
        $this->authorizeView($request);

        $year = $request->filled('year') ? $request->integer('year') : (int) now()->format('Y');
        $month = $request->filled('month') ? $request->integer('month') : (int) now()->format('n');

        $salary = DriverSalaryCalculator::calculate($driver, $year, $month);
        $payroll = DriverPayroll::query()
            ->where('driver_id', $driver->id)
            ->where('year', $year)
            ->where('month', $month)
            ->first();

        $hireFullValueTotal = (float) $salary['hire_full_value_total'];
        $ourHireValueTotal = (float) $salary['our_hire_value_total'];

        return response()->json([
            'year' => $year,
            'month' => $month,
            'period_label' => Carbon::create($year, $month, 1)->format('F Y'),
            'summary' => [
                'hire_count' => $salary['hire_count'],
                'hire_full_value_total' => round($hireFullValueTotal, 2),
                'our_hire_value_total' => round($ourHireValueTotal, 2),
                'commission_total' => round($hireFullValueTotal - $ourHireValueTotal, 2),
                'expenses_total' => round((float) $salary['expenses_total'], 2),
                'salary_payable' => round((float) ($payroll->final_amount ?? $salary['net_salary_payable']), 2),
            ],
            'payroll_status' => $payroll?->status,
        ]);
    }

    /**
     * This driver's Expenses tab: their hire_expenses rows, one month at a
     * time (same month-stepper convention as summary()), newest first —
     * mirrors Admin\ExpenseController's driver_id filter, scoped to one
     * driver instead of listing across all of them.
     */
    public function expenses(Request $request, Driver $driver): AnonymousResourceCollection
    {
        $this->authorizeView($request);

        $category = $request->string('category')->toString() ?: null;

        $filtered = HireExpense::query()
            ->where('driver_id', $driver->id)
            ->when($category, fn ($query) => $query->where('category', $category))
            ->when($request->filled('year'), fn ($query) => $query->whereYear('created_at', $request->integer('year')))
            ->when($request->filled('month'), fn ($query) => $query->whereMonth('created_at', $request->integer('month')));

        $summaryRow = (clone $filtered)
            ->selectRaw('COUNT(*) as count, COALESCE(SUM(amount), 0) as total')
            ->first();

        $expenses = $filtered->with('hire')->latest()->paginate(20);

        return DriverExpenseResource::collection($expenses)->additional([
            'summary' => [
                'count' => (int) $summaryRow->count,
                'total' => round((float) $summaryRow->total, 2),
            ],
        ]);
    }

    /**
     * This driver's Deposit tab — the same cash-deposit breakdown and
     * arrears-loan schedule as the web panel's own Deposit tab (see
     * resources/views/admin/drivers/show.blade.php and
     * ArrearsLoanController::currentUnresolvedDeficit() for the formula
     * this mirrors). Read-only here — converting a deficit into an arrears
     * loan and running payroll stay web-panel-only actions.
     */
    public function deposit(Request $request, Driver $driver): JsonResponse
    {
        $this->authorizeView($request);

        $year = $request->filled('year') ? $request->integer('year') : (int) now()->format('Y');
        $month = $request->filled('month') ? $request->integer('month') : (int) now()->format('n');

        $salary = DriverSalaryCalculator::calculate($driver, $year, $month);

        $transferredTotal = round((float) DriverDepositTransfer::query()
            ->where('driver_id', $driver->id)
            ->where('year', $year)
            ->where('month', $month)
            ->sum('amount'), 2);

        $arrearsLoans = DriverArrearsLoan::query()
            ->where('driver_id', $driver->id)
            ->where('source_year', $year)
            ->where('source_month', $month)
            ->with('deductions')
            ->latest()
            ->get();

        $arrearsLoanTotal = round((float) $arrearsLoans->sum('amount'), 2);
        $balance = round($salary['deposit_amount'] - $transferredTotal, 2);
        $balanceDisplay = max($balance, 0.0);
        $netPayableBase = $salary['net_salary_payable'];
        $finalNetPayable = round($netPayableBase - $balance, 2);
        $unresolvedDeficit = round($netPayableBase - ($salary['deposit_amount'] - $transferredTotal - $arrearsLoanTotal), 2);

        return response()->json([
            'year' => $year,
            'month' => $month,
            'period_label' => Carbon::create($year, $month, 1)->format('F Y'),
            'deposit' => [
                'hire_full_value_total' => round((float) $salary['hire_full_value_total'], 2),
                'cash_total' => round((float) ($salary['hire_full_value_by_payment_type']['cash'] ?? 0), 2),
                'credit_total' => round((float) ($salary['hire_full_value_by_payment_type']['credit'] ?? 0), 2),
                'deposit_amount' => round((float) $salary['deposit_amount'], 2),
                'transferred_total' => $transferredTotal,
                'balance' => $balanceDisplay,
                'net_salary_payable' => round((float) $netPayableBase, 2),
                'final_net_payable' => $finalNetPayable,
                'unresolved_deficit' => $unresolvedDeficit,
            ],
            'arrears_loans' => $arrearsLoans->map(fn (DriverArrearsLoan $loan) => [
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
        ]);
    }

    public function update(Request $request, Driver $driver): DriverResource
    {
        abort_unless($request->user()->can('drivers.update'), 403, 'You do not have permission to edit drivers.');

        $data = $this->validated($request, $driver);
        $plainPassword = $data['password'] ?? null;
        unset($data['password']);

        DB::transaction(function () use ($data, $plainPassword, $driver) {
            $user = $driver->user;
            if ($user) {
                $user->update([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    ...($plainPassword ? ['password' => Hash::make($plainPassword)] : []),
                ]);
                $user->syncRoles(['Driver']);
            } else {
                $user = User::create([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    'password' => Hash::make($plainPassword ?? Str::random(24)),
                ]);
                $user->syncRoles(['Driver']);
                $data['user_id'] = $user->id;
            }

            if ($plainPassword) {
                $data['password'] = Hash::make($plainPassword);
            }

            $driver->update($data);
        });

        return new DriverResource($driver->fresh());
    }

    public function destroy(Request $request, Driver $driver): JsonResponse
    {
        abort_unless($request->user()->can('drivers.delete'), 403, 'You do not have permission to delete drivers.');

        DB::transaction(function () use ($driver) {
            $driver->user?->delete();
            $driver->delete();
        });

        return response()->json(['message' => "Driver \"{$driver->name}\" was deleted."]);
    }

    private function validated(Request $request, ?Driver $driver = null): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'license' => ['required', 'string', 'max:255'],
            'contact_number' => ['required', 'string', 'max:30'],
            'additional_phone_number' => ['nullable', 'string', 'max:30'],
            'email' => [
                'required', 'string', 'email', 'max:255',
                Rule::unique('drivers', 'email')->ignore($driver?->id),
                Rule::unique('users', 'email')->ignore($driver?->user_id),
            ],
            'password' => [$driver ? 'nullable' : 'required', 'string', 'min:8'],
        ]);
    }

    private function authorizeView(Request $request): void
    {
        abort_unless($request->user()->can('drivers.view'), 403, 'You do not have permission to view drivers.');
    }
}
