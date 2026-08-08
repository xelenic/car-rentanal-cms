<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\DriverPayroll;
use App\Models\SalaryAdvanceRequest;
use App\Services\SalaryAdvanceScheduler;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class SalaryAdvanceController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:salary-advances.view', only: ['index']),
            new Middleware('permission:salary-advances.update', only: ['update']),
        ];
    }

    public function index(Request $request): View
    {
        $status = $request->string('status')->toString();

        $requests = SalaryAdvanceRequest::query()
            ->with(['driver', 'reviewer', 'deductions'])
            ->when($status && $status !== 'all', fn ($query) => $query->where('status', $status))
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->whereHas('driver', function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        $driverIds = $requests->getCollection()->pluck('driver_id')->unique()->values();

        $paidPeriods = DriverPayroll::query()
            ->whereIn('driver_id', $driverIds)
            ->where('status', 'paid')
            ->get(['driver_id', 'year', 'month'])
            ->map(fn (DriverPayroll $payroll) => "{$payroll->driver_id}-{$payroll->year}-{$payroll->month}");

        return view('admin.salary-advances.index', [
            'requests' => $requests,
            'status' => $status ?: 'all',
            'search' => $request->string('search')->toString(),
            'pendingCount' => SalaryAdvanceRequest::query()->where('status', 'pending')->count(),
            'paidPeriods' => $paidPeriods,
        ]);
    }

    public function update(Request $request, SalaryAdvanceRequest $salaryAdvance): RedirectResponse
    {
        $rules = [
            'status' => ['required', Rule::in(['approved', 'rejected'])],
            'admin_note' => ['nullable', 'string', 'max:1000'],
        ];

        if ($request->input('status') === 'approved') {
            $rules['deduction_type'] = ['required', Rule::in(array_keys(SalaryAdvanceRequest::DEDUCTION_TYPES))];

            if ($request->input('deduction_type') === 'installments') {
                $rules['this_month_amount'] = [
                    'nullable', 'numeric', 'min:0', 'max:'.(float) $salaryAdvance->amount,
                ];
                $rules['installment_months'] = ['required', 'integer', 'min:1', 'max:60'];
            }
        }

        $data = $request->validate($rules);

        DB::transaction(function () use ($data, $request, $salaryAdvance) {
            $salaryAdvance->update([
                'status' => $data['status'],
                'deduction_type' => $data['deduction_type'] ?? null,
                'admin_note' => $data['admin_note'] ?? null,
                'reviewed_by' => $request->user()->id,
                'reviewed_at' => now(),
            ]);

            if ($data['status'] === 'approved') {
                SalaryAdvanceScheduler::schedule(
                    $salaryAdvance,
                    $data['deduction_type'],
                    isset($data['this_month_amount']) ? (float) $data['this_month_amount'] : null,
                    $data['installment_months'] ?? null,
                );
            }
        });

        return redirect()->route('admin.salary-advances.index')
            ->with('status', "Salary advance request for \"{$salaryAdvance->driver->name}\" was {$data['status']}.");
    }
}
