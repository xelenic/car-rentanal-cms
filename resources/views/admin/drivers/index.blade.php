@extends('layouts.admin')

@section('title', 'Drivers')
@section('subtitle', 'Manage driver profiles, licenses, and documents.')

@section('actions')
    @can('drivers.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Driver
        </button>
    @endcan
@endsection

@section('content')
    <div class="row row-cols-1 row-cols-md-2 row-cols-xl-5 g-2 mb-2">
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #eef2ff; color: #4f46e5;">
                        <i class="bi bi-cash-stack"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Our Hire Value &middot; {{ $periodLabel }}</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['our_hire_value_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #eff6ff; color: #2563eb;">
                        <i class="bi bi-cash-coin"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Full Value &middot; {{ $periodLabel }}</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['hire_full_value_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fef2f2; color: #dc2626;">
                        <i class="bi bi-receipt"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Expenses &middot; {{ $periodLabel }}</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['expenses_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #ecfdf5; color: #059669;">
                        <i class="bi bi-wallet2"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Driver Salary &middot; {{ $periodLabel }}</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['salary'], 2) }}</div>
                        @if ($summary['advance_deduction_total'] > 0 || $summary['carryover_deduction_total'] > 0 || $summary['arrears_deduction_total'] > 0)
                            <div class="text-danger" style="font-size: .7rem;">
                                @if ($summary['advance_deduction_total'] > 0)
                                    -Rs. {{ number_format($summary['advance_deduction_total'], 2) }} advance
                                @endif
                                @if ($summary['carryover_deduction_total'] > 0)
                                    -Rs. {{ number_format($summary['carryover_deduction_total'], 2) }} carried over
                                @endif
                                @if ($summary['arrears_deduction_total'] > 0)
                                    -Rs. {{ number_format($summary['arrears_deduction_total'], 2) }} arrears
                                @endif
                                &middot; Rs. {{ number_format($summary['net_salary_payable'], 2) }} net payable
                            </div>
                        @endif
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdf4ff; color: #a21caf;">
                        <i class="bi bi-piggy-bank"></i>
                    </div>
                    <div>
                        <div class="text-muted small">My Profit &middot; {{ $periodLabel }}</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['profit'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card border-0">
        <div class="card-header">
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                <div class="position-relative" style="max-width: 280px; flex: 1 1 220px;">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search by name, email or contact...">
                </div>

                <select name="year" class="form-select" style="max-width: 120px;" onchange="this.form.submit()">
                    @foreach ($availableYears as $year)
                        <option value="{{ $year }}" {{ (string) $selectedYear === (string) $year ? 'selected' : '' }}>{{ $year }}</option>
                    @endforeach
                </select>

                <select name="month" class="form-select" style="max-width: 150px;" onchange="this.form.submit()">
                    @foreach ($monthsByYear[$selectedYear] ?? [] as $month)
                        <option value="{{ $month }}" {{ (string) $selectedMonth === (string) $month ? 'selected' : '' }}>{{ \Carbon\Carbon::create()->month($month)->format('F') }}</option>
                    @endforeach
                </select>
            </form>
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Driver</th>
                        <th>License</th>
                        <th>Contact</th>
                        <th>Documents</th>
                        <th>Salary ({{ $periodLabel }})</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($drivers as $driver)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <x-avatar :name="$driver->name" :size="30" />
                                    <div>
                                        <div class="fw-semibold" style="font-size: .8rem;">{{ $driver->name }}</div>
                                        <div class="text-muted" style="font-size: .78rem;">{{ $driver->email }}</div>
                                    </div>
                                </div>
                            </td>
                            <td class="text-muted">{{ $driver->license }}</td>
                            <td class="text-muted">
                                {{ $driver->contact_number }}
                                @if ($driver->additional_phone_number)
                                    <div class="text-muted" style="font-size: .72rem;">{{ $driver->additional_phone_number }}</div>
                                @endif
                            </td>
                            <td>
                                @if ($driver->driver_id_softcopy_path)
                                    <a href="{{ \Illuminate\Support\Facades\Storage::url($driver->driver_id_softcopy_path) }}" target="_blank" class="badge rounded-pill bg-primary-subtle text-primary-emphasis text-decoration-none">
                                        <i class="bi bi-file-earmark-check"></i> ID
                                    </a>
                                @endif
                                @if ($driver->tourism_board_license_path)
                                    <a href="{{ \Illuminate\Support\Facades\Storage::url($driver->tourism_board_license_path) }}" target="_blank" class="badge rounded-pill bg-success-subtle text-success-emphasis text-decoration-none">
                                        <i class="bi bi-file-earmark-check"></i> License
                                    </a>
                                @endif
                                @if (! $driver->driver_id_softcopy_path && ! $driver->tourism_board_license_path)
                                    <span class="text-muted small">&mdash;</span>
                                @endif
                            </td>
                            <td>
                                @php
                                    $salary = $salaries[$driver->id];
                                    $payroll = $payrolls->get($driver->id);
                                @endphp
                                @php $displayAmount = $payroll->final_amount ?? $salary['net_salary_payable']; @endphp
                                <button type="button" class="btn btn-link btn-sm p-0 fw-semibold text-decoration-none {{ (float) $displayAmount < 0 ? 'text-danger' : '' }}" style="font-size: .82rem;" data-bs-toggle="modal" data-bs-target="#modal-salary-{{ $driver->id }}">
                                    {{ (float) $displayAmount < 0 ? '-' : '' }}Rs. {{ number_format(abs($displayAmount), 2) }}
                                </button>
                                <div class="text-muted" style="font-size: .72rem;">{{ $salary['hire_count'] }} hire{{ $salary['hire_count'] === 1 ? '' : 's' }}</div>
                                @if ($salary['advance_deduction_total'] > 0)
                                    <div class="text-danger" style="font-size: .7rem;">-Rs. {{ number_format($salary['advance_deduction_total'], 2) }} advance</div>
                                @endif
                                @if ($salary['carryover_deduction_total'] > 0)
                                    <div class="text-danger" style="font-size: .7rem;">-Rs. {{ number_format($salary['carryover_deduction_total'], 2) }} carried over</div>
                                @endif
                                @if ($salary['arrears_deduction_total'] > 0)
                                    <div class="text-danger" style="font-size: .7rem;">-Rs. {{ number_format($salary['arrears_deduction_total'], 2) }} arrears</div>
                                @endif
                                @if ($payroll?->status === 'paid' && (float) $payroll->final_amount < 0)
                                    <span class="badge rounded-pill bg-danger-subtle text-danger-emphasis mt-1">Carried to next month</span>
                                @elseif ($payroll?->status === 'paid')
                                    <span class="badge rounded-pill bg-success-subtle text-success-emphasis mt-1">Paid</span>
                                @elseif ($payroll?->status === 'finalized')
                                    <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis mt-1">Finalized &middot; awaiting payment</span>
                                @endif
                            </td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('drivers.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $driver->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('drivers.delete')
                                        <form method="POST" action="{{ route('admin.drivers.destroy', $driver) }}" onsubmit="return confirm('Delete this driver?');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit" class="btn btn-sm btn-light border btn-icon text-danger">
                                                <i class="bi bi-trash"></i>
                                            </button>
                                        </form>
                                    @endcan
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="text-center text-muted py-4">
                                <i class="bi bi-person-badge fs-4 d-block mb-1"></i>
                                No drivers found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($drivers->hasPages())
            <div class="card-footer bg-white">
                {{ $drivers->links() }}
            </div>
        @endif
    </div>

    @foreach ($drivers as $driver)
        @php
            $salary = $salaries[$driver->id];
            $payroll = $payrolls->get($driver->id);
            $hires = $hiresByDriver->get($driver->id, collect());
            $transferredTotal = $depositTransferTotals->get($driver->id, 0.0);
            $arrearsLoans = $arrearsLoansByDriver->get($driver->id, collect());
            $arrearsLoanTotal = round((float) $arrearsLoans->sum('amount'), 2);
            // Balance: plain cash-flow figure — deposit owed minus what's
            // physically been transferred so far. Floored at 0 for display:
            // a driver who transferred more than they owed doesn't have a
            // negative balance, there's just nothing left.
            $balance = round($salary['deposit_amount'] - $transferredTotal, 2);
            $balanceDisplay = max($balance, 0.0);
            $netPayableBase = $salary['net_salary_payable'];
            $finalNetPayable = round($netPayableBase - $balance, 2);
            // The deficit still available to convert into a NEW arrears
            // loan — nets out anything already converted, so the button
            // below can't create duplicate loans for the same shortfall.
            $unresolvedDeficit = round($netPayableBase - ($salary['deposit_amount'] - $transferredTotal - $arrearsLoanTotal), 2);
        @endphp
        <x-modal id="modal-salary-{{ $driver->id }}" title="{{ $driver->name }} — Salary ({{ $periodLabel }})" size="lg">
            <div class="row g-2 mb-3">
                <div class="col-4">
                    <div class="text-muted small">Our Hire Value Total</div>
                    <div class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($salary['our_hire_value_total'], 2) }}</div>
                </div>
                <div class="col-4">
                    <div class="text-muted small">Hire Full Value Total</div>
                    <div class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($salary['hire_full_value_total'], 2) }}</div>
                </div>
                <div class="col-4">
                    <div class="text-muted small">Hires in {{ $periodLabel }}</div>
                    <div class="fw-semibold" style="font-size: .85rem;">{{ $salary['hire_count'] }}</div>
                </div>
            </div>

            @if ($salary['hire_count'] === 0 && $salary['advance_deduction_total'] <= 0 && $salary['carryover_deduction_total'] <= 0 && $salary['arrears_deduction_total'] <= 0)
                <div class="text-center text-muted py-4">
                    <i class="bi bi-cash-coin fs-3 d-block mb-2"></i>
                    No hires recorded for {{ $periodLabel }} yet.
                </div>
            @else
                <div class="d-flex flex-column gap-2 mb-3">
                    @foreach ($salary['expenses_by_category'] as $category => $amount)
                        <div class="d-flex align-items-center justify-content-between border rounded p-2">
                            <span style="font-size: .8rem;">{{ \App\Models\HireExpense::CATEGORIES[$category] ?? $category }}</span>
                            <span class="text-danger fw-semibold" style="font-size: .8rem;">-Rs. {{ number_format($amount, 2) }}</span>
                        </div>
                    @endforeach
                </div>

                <div class="border-top pt-3">
                    <div class="d-flex align-items-center justify-content-between mb-2">
                        <span class="text-muted" style="font-size: .82rem;">Total Expenses</span>
                        <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($salary['expenses_total'], 2) }}</span>
                    </div>
                    <div class="d-flex align-items-center justify-content-between mb-2">
                        <span class="text-muted" style="font-size: .82rem;">Net Before Salary</span>
                        <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($salary['net_before_salary'], 2) }}</span>
                    </div>
                    <div class="d-flex align-items-center justify-content-between mb-2">
                        <span class="fw-semibold" style="font-size: .9rem;">{{ $salary['salary_percentage'] }}% Driver Salary</span>
                        <span class="fw-bold text-success" style="font-size: 1.1rem;">Rs. {{ number_format($salary['salary'], 2) }}</span>
                    </div>
                    @if ($salary['advance_deduction_total'] > 0)
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Salary Advance Deduction</span>
                            <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($salary['advance_deduction_total'], 2) }}</span>
                        </div>
                    @endif
                    @if ($salary['carryover_deduction_total'] > 0)
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Carried Over from Previous Month</span>
                            <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($salary['carryover_deduction_total'], 2) }}</span>
                        </div>
                    @endif
                    @if ($salary['arrears_deduction_total'] > 0)
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Arrears Loan Deduction</span>
                            <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($salary['arrears_deduction_total'], 2) }}</span>
                        </div>
                    @endif
                    @if ($salary['advance_deduction_total'] > 0 || $salary['carryover_deduction_total'] > 0 || $salary['arrears_deduction_total'] > 0)
                        <div class="d-flex align-items-center justify-content-between border-top pt-2">
                            <span class="fw-semibold" style="font-size: .9rem;">Net Salary (without Deposit Deduction)</span>
                            <span class="fw-bold text-success" style="font-size: 1.1rem;">Rs. {{ number_format($salary['net_salary_payable'], 2) }}</span>
                        </div>
                    @endif
                </div>
            @endif

            @if ($salary['deposit_amount'] != 0 || $transferredTotal > 0)
                <div class="border-top pt-3 mt-3">
                    <div class="fw-semibold mb-2" style="font-size: .9rem;">Deposit</div>
                    <div class="d-flex align-items-center justify-content-between mb-2">
                        <span class="text-muted" style="font-size: .82rem;">Total Hire Value</span>
                        <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($salary['hire_full_value_total'], 2) }}</span>
                    </div>
                    <div class="d-flex align-items-center justify-content-between mb-2">
                        <span class="text-muted" style="font-size: .82rem;">Cash Payments</span>
                        <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($salary['hire_full_value_by_payment_type']['cash'] ?? 0, 2) }}</span>
                    </div>
                    <div class="d-flex align-items-center justify-content-between mb-2">
                        <span class="text-muted" style="font-size: .82rem;">Credit Payments</span>
                        <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($salary['hire_full_value_by_payment_type']['credit'] ?? 0, 2) }}</span>
                    </div>
                    <div class="d-flex align-items-center justify-content-between mb-2 border-top pt-2">
                        <span class="text-muted" style="font-size: .82rem;">Deposit Amount</span>
                        <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($salary['deposit_amount'], 2) }}</span>
                    </div>
                    @if ($transferredTotal > 0)
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Already Transferred</span>
                            <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($transferredTotal, 2) }}</span>
                        </div>
                    @endif
                    <div class="d-flex align-items-center justify-content-between border-top pt-2">
                        <span class="fw-semibold" style="font-size: .9rem;">Balance</span>
                        <span class="fw-bold text-success" style="font-size: 1.1rem;">Rs. {{ number_format($balanceDisplay, 2) }}</span>
                    </div>

                    <div class="d-flex align-items-center justify-content-between mt-3 pt-3 border-top">
                        <span class="fw-semibold" style="font-size: .9rem;">Net Payable Salary</span>
                        <span class="fw-bold {{ $finalNetPayable < 0 ? 'text-danger' : 'text-success' }}" style="font-size: 1.1rem;">
                            {{ $finalNetPayable < 0 ? '-' : '' }}Rs. {{ number_format(abs($finalNetPayable), 2) }}
                        </span>
                    </div>
                    <div class="text-muted mt-1" style="font-size: .75rem;">
                        Net Salary (without Deposit Deduction) (Rs. {{ number_format($netPayableBase, 2) }}) - Deposit Balance (Rs. {{ number_format($balanceDisplay, 2) }})
                        = {{ $finalNetPayable < 0 ? '-' : '' }}Rs. {{ number_format(abs($finalNetPayable), 2) }}.
                    </div>

                    @if ($arrearsLoans->isNotEmpty())
                        <div class="mt-2">
                            @foreach ($arrearsLoans as $loan)
                                <button type="button" class="btn btn-link btn-sm p-0 d-block" style="font-size: .72rem;" data-bs-toggle="modal" data-bs-target="#modal-arrears-schedule-{{ $loan->id }}">
                                    <i class="bi bi-receipt me-1"></i>Arrears Loan: Rs. {{ number_format($loan->amount, 2) }} &middot; {{ $loan->deduction_type_label }}
                                </button>
                            @endforeach
                        </div>
                    @endif

                    @can('payroll.manage')
                        @if ($unresolvedDeficit < 0)
                            <button type="button" class="btn btn-sm btn-outline-danger mt-2" data-bs-toggle="modal" data-bs-target="#modal-arrears-{{ $driver->id }}">
                                <i class="bi bi-arrow-repeat me-1"></i> Change as Arrears Loan
                            </button>
                        @endif
                    @endcan
                </div>
            @endif

            <div class="border-top pt-3 mt-3">
                <div class="d-flex align-items-center justify-content-between mb-2">
                    <span class="fw-semibold" style="font-size: .9rem;">Payroll</span>
                    @if ($payroll?->status === 'paid')
                        <span class="badge rounded-pill bg-success-subtle text-success-emphasis">Paid</span>
                    @elseif ($payroll?->status === 'finalized')
                        <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis">Finalized &middot; awaiting payment</span>
                    @endif
                </div>

                @if (! $payroll)
                    @can('payroll.manage')
                        <button type="button" class="btn btn-sm btn-outline-primary make-payroll-btn" data-target="#payroll-form-{{ $driver->id }}">
                            <i class="bi bi-cash-coin me-1"></i> Make Payroll
                        </button>

                        <div id="payroll-form-{{ $driver->id }}" class="d-none mt-3 border rounded p-3 payroll-form-wrapper" style="background: #f8f9fb;">
                            <form id="form-finalize-payroll-{{ $driver->id }}" method="POST" action="{{ route('admin.drivers.payroll.finalize', $driver) }}">
                                @csrf
                                <input type="hidden" name="year" value="{{ $selectedYear }}">
                                <input type="hidden" name="month" value="{{ $selectedMonth }}">
                                <input type="hidden" name="search" value="{{ $search }}">

                                <label class="form-label small">Manual correction (optional)</label>
                                <div class="row g-2">
                                    <div class="col-6">
                                        <input type="number" step="0.01" name="manual_adjustment" class="form-control manual-adjustment-input" placeholder="0.00" data-base="{{ $finalNetPayable + $arrearsLoanTotal }}">
                                        <div class="form-text">Positive adds, negative deducts.</div>
                                    </div>
                                    <div class="col-6">
                                        <input type="text" name="adjustment_note" class="form-control" placeholder="Reason (optional)">
                                    </div>
                                </div>
                                <div class="payroll-final-preview mt-2 fw-semibold" style="font-size: .85rem;">
                                    Final Payable: Rs. {{ number_format($finalNetPayable + $arrearsLoanTotal, 2) }}
                                </div>
                                <div class="payroll-final-negative-note text-muted d-none mt-1" style="font-size: .75rem;">
                                    <i class="bi bi-info-circle me-1"></i>A negative amount can't be paid — the shortfall will be carried forward as a deduction on next month's salary.
                                </div>
                            </form>
                            <div class="mt-3 text-end">
                                <button type="submit" form="form-finalize-payroll-{{ $driver->id }}" class="btn btn-sm btn-success">Finalize Payroll</button>
                            </div>
                        </div>
                    @endcan
                @else
                    <div class="d-flex flex-column gap-1 mb-2">
                        <div class="d-flex align-items-center justify-content-between">
                            <span class="text-muted" style="font-size: .8rem;">Salary</span>
                            <span style="font-size: .8rem;">Rs. {{ number_format($payroll->salary, 2) }}</span>
                        </div>
                        <div class="d-flex align-items-center justify-content-between">
                            <span class="text-muted" style="font-size: .8rem;">Advance Deduction</span>
                            <span style="font-size: .8rem;">-Rs. {{ number_format($payroll->advance_deduction_total, 2) }}</span>
                        </div>
                        @if ((float) $payroll->carryover_deduction_total > 0)
                            <div class="d-flex align-items-center justify-content-between">
                                <span class="text-muted" style="font-size: .8rem;">Carried Over from Previous Month</span>
                                <span style="font-size: .8rem;">-Rs. {{ number_format($payroll->carryover_deduction_total, 2) }}</span>
                            </div>
                        @endif
                        @if ((float) $payroll->arrears_deduction_total > 0)
                            <div class="d-flex align-items-center justify-content-between">
                                <span class="text-muted" style="font-size: .8rem;">Arrears Loan Deduction</span>
                                <span style="font-size: .8rem;">-Rs. {{ number_format($payroll->arrears_deduction_total, 2) }}</span>
                            </div>
                        @endif
                        @if ((float) $payroll->deposit_balance > 0)
                            <div class="d-flex align-items-center justify-content-between">
                                <span class="text-muted" style="font-size: .8rem;">Deposit Balance</span>
                                <span style="font-size: .8rem;">-Rs. {{ number_format($payroll->deposit_balance, 2) }}</span>
                            </div>
                        @endif
                        @if ((float) $payroll->arrears_loan_offset > 0)
                            <div class="d-flex align-items-center justify-content-between">
                                <span class="text-muted" style="font-size: .8rem;">Converted to Arrears Loan (Full Amount)</span>
                                <span class="text-success" style="font-size: .8rem;">+Rs. {{ number_format($payroll->arrears_loan_offset, 2) }}</span>
                            </div>
                        @endif
                        @if ((float) $payroll->manual_adjustment !== 0.0)
                            <div class="d-flex align-items-center justify-content-between">
                                <span class="text-muted" style="font-size: .8rem;">
                                    Manual Adjustment
                                    @if ($payroll->adjustment_note)
                                        <span title="{{ $payroll->adjustment_note }}">&ldquo;{{ \Illuminate\Support\Str::limit($payroll->adjustment_note, 24) }}&rdquo;</span>
                                    @endif
                                </span>
                                <span style="font-size: .8rem;" class="{{ (float) $payroll->manual_adjustment < 0 ? 'text-danger' : 'text-success' }}">
                                    {{ (float) $payroll->manual_adjustment < 0 ? '-' : '+' }}Rs. {{ number_format(abs($payroll->manual_adjustment), 2) }}
                                </span>
                            </div>
                        @endif
                        <div class="d-flex align-items-center justify-content-between border-top pt-2 mt-1">
                            <span class="fw-semibold" style="font-size: .9rem;">Final Amount</span>
                            <span class="fw-bold {{ (float) $payroll->final_amount < 0 ? 'text-danger' : 'text-success' }}" style="font-size: 1.1rem;">
                                {{ (float) $payroll->final_amount < 0 ? '-' : '' }}Rs. {{ number_format(abs($payroll->final_amount), 2) }}
                            </span>
                        </div>
                    </div>
                    <div class="text-muted" style="font-size: .72rem;">
                        Finalized by {{ $payroll->finalizedBy?->name ?? '—' }} &middot; {{ $payroll->finalized_at?->format('M j, Y g:i A') }}
                    </div>
                    @if ($payroll->status === 'paid')
                        <div class="text-muted" style="font-size: .72rem;">
                            Paid by {{ $payroll->paidBy?->name ?? '—' }} &middot; {{ $payroll->paid_at?->format('M j, Y g:i A') }}
                        </div>
                        @if ((float) $payroll->final_amount < 0)
                            @php
                                $carryTarget = \Carbon\Carbon::create($payroll->year, $payroll->month, 1)->addMonthNoOverflow();
                            @endphp
                            <div class="alert alert-danger py-2 px-3 mt-2 mb-0" style="font-size: .78rem;">
                                <i class="bi bi-arrow-return-right me-1"></i>
                                This payroll had a shortfall of <strong>Rs. {{ number_format(abs($payroll->final_amount), 2) }}</strong> —
                                carried forward as a deduction on {{ $carryTarget->format('F Y') }}'s salary.
                            </div>
                        @endif
                    @endif

                    <a href="{{ route('admin.drivers.payroll.slip', [$driver, $payroll]) }}" target="_blank" class="btn btn-sm btn-outline-secondary mt-2">
                        <i class="bi bi-printer me-1"></i> Print Salary Slip
                    </a>

                    @can('payroll.manage')
                        @if ($payroll->status === 'finalized')
                            <div class="d-flex gap-2 mt-2">
                                <form method="POST" action="{{ route('admin.drivers.payroll.mark-paid', [$driver, $payroll]) }}" onsubmit="return confirm('Mark this payroll as paid? This cannot be undone.');">
                                    @csrf
                                    <input type="hidden" name="year" value="{{ $selectedYear }}">
                                    <input type="hidden" name="month" value="{{ $selectedMonth }}">
                                    <input type="hidden" name="search" value="{{ $search }}">
                                    <button type="submit" class="btn btn-sm btn-success">
                                        <i class="bi bi-check-circle me-1"></i> Mark as Paid
                                    </button>
                                </form>
                                <form method="POST" action="{{ route('admin.drivers.payroll.revert', [$driver, $payroll]) }}" onsubmit="return confirm('Revert this finalized payroll? It will be deleted so you can make it again with different figures.');">
                                    @csrf
                                    @method('DELETE')
                                    <input type="hidden" name="year" value="{{ $selectedYear }}">
                                    <input type="hidden" name="month" value="{{ $selectedMonth }}">
                                    <input type="hidden" name="search" value="{{ $search }}">
                                    <button type="submit" class="btn btn-sm btn-outline-danger">
                                        <i class="bi bi-arrow-counterclockwise me-1"></i> Revert
                                    </button>
                                </form>
                            </div>
                        @endif
                    @endcan
                @endif
            </div>

            @if ($hires->isNotEmpty())
                <div class="mt-3">
                    <div class="text-muted small mb-1">Hires in {{ $periodLabel }}</div>
                    <div class="table-responsive" style="max-height: 220px; overflow-y: auto;">
                        <table class="table table-sm mb-0">
                            <thead>
                                <tr>
                                    <th>Route</th>
                                    <th>Status</th>
                                    <th class="text-end">Value</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($hires as $hire)
                                    <tr>
                                        <td style="font-size: .78rem;">{{ $hire->fromLocation?->location?->name ?? '—' }} &rarr; {{ $hire->toLocation?->location?->name ?? '—' }}</td>
                                        <td>
                                            @php
                                                $hireStatusColor = match ($hire->status) {
                                                    'completed' => 'success',
                                                    'started' => 'info',
                                                    default => 'secondary',
                                                };
                                            @endphp
                                            <span class="badge rounded-pill bg-{{ $hireStatusColor }}-subtle text-{{ $hireStatusColor }}-emphasis" style="font-size: .68rem;">{{ $hire->status_label }}</span>
                                        </td>
                                        <td class="text-end" style="font-size: .78rem;">Rs. {{ number_format($hire->our_hire_value, 2) }}</td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                </div>
            @endif
        </x-modal>
    @endforeach

    @can('payroll.manage')
        @foreach ($drivers as $driver)
            @php
                $salary = $salaries[$driver->id];
                $transferredTotal = $depositTransferTotals->get($driver->id, 0.0);
                $arrearsLoans = $arrearsLoansByDriver->get($driver->id, collect());
                $arrearsLoanTotal = round((float) $arrearsLoans->sum('amount'), 2);
                $netPayableBase = $salary['net_salary_payable'];
                $unresolvedDeficit = round($netPayableBase - ($salary['deposit_amount'] - $transferredTotal - $arrearsLoanTotal), 2);
            @endphp

            @if ($unresolvedDeficit < 0)
                <x-modal id="modal-arrears-{{ $driver->id }}" title="Change as Arrears Loan — {{ $driver->name }}">
                    <form id="form-arrears-{{ $driver->id }}" class="arrears-loan-form" method="POST" action="{{ route('admin.drivers.arrears-loan.store', $driver) }}" data-amount="{{ abs($unresolvedDeficit) }}">
                        @csrf
                        <input type="hidden" name="year" value="{{ $selectedYear }}">
                        <input type="hidden" name="month" value="{{ $selectedMonth }}">
                        <input type="hidden" name="search" value="{{ $search }}">

                        <div class="mb-3">
                            <div class="text-muted small">Deficit</div>
                            <div class="fw-semibold fs-5 text-danger">-Rs. {{ number_format(abs($unresolvedDeficit), 2) }}</div>
                        </div>

                        <label class="form-label">How should this be recovered?</label>

                        <div class="form-check mb-2">
                            <input class="form-check-input arrears-type-radio" type="radio" name="deduction_type" id="arrears-full-{{ $driver->id }}" value="full" checked>
                            <label class="form-check-label" for="arrears-full-{{ $driver->id }}">
                                Deduct fully from next month's salary
                            </label>
                        </div>

                        <div class="form-check mb-3">
                            <input class="form-check-input arrears-type-radio" type="radio" name="deduction_type" id="arrears-installments-{{ $driver->id }}" value="installments">
                            <label class="form-check-label" for="arrears-installments-{{ $driver->id }}">
                                Split across upcoming months
                            </label>
                        </div>

                        <div class="arrears-installment-fields d-none border rounded p-3 mb-2" style="background: #f8f9fb;">
                            <label for="arrears-months-{{ $driver->id }}" class="form-label small">Split over how many months</label>
                            <input type="number" step="1" min="1" max="60" name="installment_months" id="arrears-months-{{ $driver->id }}" class="form-control arrears-months-input" placeholder="e.g. 3">
                            <div class="arrears-installment-preview text-muted mt-2" style="font-size: .78rem;"></div>
                        </div>
                    </form>
                    <x-slot:footer>
                        <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" form="form-arrears-{{ $driver->id }}" class="btn btn-danger">Create Arrears Loan</button>
                    </x-slot:footer>
                </x-modal>
            @endif

            @foreach ($arrearsLoans as $loan)
                <x-modal id="modal-arrears-schedule-{{ $loan->id }}" title="Arrears Loan Schedule — {{ $driver->name }}">
                    <div class="mb-2">
                        <div class="text-muted small">{{ $loan->deduction_type_label }}</div>
                        <div class="fw-semibold">Rs. {{ number_format($loan->amount, 2) }} total</div>
                    </div>
                    <table class="table table-sm mb-0">
                        <thead>
                            <tr>
                                <th>Month</th>
                                <th class="text-end">Amount</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($loan->deductions as $deduction)
                                <tr>
                                    <td>{{ \Carbon\Carbon::createFromDate($deduction->year, $deduction->month, 1)->format('F Y') }}</td>
                                    <td class="text-end">Rs. {{ number_format($deduction->amount, 2) }}</td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                    <x-slot:footer>
                        <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Close</button>
                    </x-slot:footer>
                </x-modal>
            @endforeach
        @endforeach
    @endcan

    @can('drivers.create')
        <x-modal id="modal-create" title="New Driver" size="lg">
            <form id="form-create-driver" method="POST" action="{{ route('admin.drivers.store') }}" enctype="multipart/form-data">
                @csrf
                @include('admin.drivers._form', ['driver' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-driver" class="btn btn-primary">Create Driver</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @can('drivers.update')
        @foreach ($drivers as $driver)
            <x-modal id="modal-edit-{{ $driver->id }}" title="Edit Driver" size="lg">
                <form id="form-edit-driver-{{ $driver->id }}" method="POST" action="{{ route('admin.drivers.update', $driver) }}" enctype="multipart/form-data">
                    @csrf
                    @method('PUT')
                    @include('admin.drivers._form', ['driver' => $driver, 'idPrefix' => 'edit-'.$driver->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-driver-{{ $driver->id }}" class="btn btn-primary">Update Driver</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan

    @push('scripts')
        <script>
            (function () {
                function updatePreview(input) {
                    var wrapper = input.closest('.payroll-form-wrapper');
                    var preview = wrapper.querySelector('.payroll-final-preview');
                    var base = parseFloat(input.dataset.base || '0');
                    var adjustment = parseFloat(input.value) || 0;
                    var final = Math.round((base + adjustment) * 100) / 100;
                    var sign = final < 0 ? '-' : '';
                    preview.textContent = 'Final Payable: ' + sign + 'Rs. ' + Math.abs(final).toFixed(2);
                    preview.classList.toggle('text-danger', final < 0);
                    var note = wrapper.querySelector('.payroll-final-negative-note');
                    if (note) {
                        note.classList.toggle('d-none', final >= 0);
                    }
                }

                document.addEventListener('click', function (event) {
                    var button = event.target.closest('.make-payroll-btn');
                    if (!button) return;
                    var target = document.querySelector(button.dataset.target);
                    if (target) {
                        target.classList.remove('d-none');
                        button.classList.add('d-none');
                    }
                });

                document.addEventListener('input', function (event) {
                    if (event.target.classList.contains('manual-adjustment-input')) {
                        updatePreview(event.target);
                    }
                });

                function toggleArrearsFields(form) {
                    var installmentsSelected = form.querySelector('.arrears-type-radio[value="installments"]').checked;
                    var fields = form.querySelector('.arrears-installment-fields');
                    fields.classList.toggle('d-none', !installmentsSelected);
                }

                function updateArrearsPreview(form) {
                    var totalAmount = parseFloat(form.dataset.amount || '0');
                    var monthsInput = form.querySelector('.arrears-months-input');
                    var preview = form.querySelector('.arrears-installment-preview');
                    if (!monthsInput || !preview) return;

                    var months = Math.max(parseInt(monthsInput.value, 10) || 0, 0);
                    if (months <= 0) {
                        preview.textContent = 'Enter how many months to split it over.';
                        return;
                    }

                    var perMonth = Math.floor((totalAmount / months) * 100) / 100;
                    var last = Math.round((totalAmount - perMonth * (months - 1)) * 100) / 100;

                    var text;
                    if (months === 1) {
                        text = 'Rs. ' + last.toFixed(2) + ' next month.';
                    } else if (perMonth === last) {
                        text = 'Rs. ' + perMonth.toFixed(2) + '/month for ' + months + ' upcoming months.';
                    } else {
                        text = 'Rs. ' + perMonth.toFixed(2) + '/month for ' + (months - 1) + ' months, then Rs. ' + last.toFixed(2) + ' in the final month.';
                    }
                    preview.textContent = text;
                }

                document.addEventListener('change', function (event) {
                    var form = event.target.closest('.arrears-loan-form');
                    if (!form) return;
                    if (event.target.classList.contains('arrears-type-radio')) {
                        toggleArrearsFields(form);
                        updateArrearsPreview(form);
                    }
                });

                document.addEventListener('input', function (event) {
                    var form = event.target.closest('.arrears-loan-form');
                    if (!form) return;
                    if (event.target.classList.contains('arrears-months-input')) {
                        updateArrearsPreview(form);
                    }
                });
            })();
        </script>
    @endpush
@endsection
