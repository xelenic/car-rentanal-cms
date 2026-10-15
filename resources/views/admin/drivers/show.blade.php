@extends('layouts.admin')

@section('title', $driver->name)
@section('subtitle', 'Driver history, earnings, and payroll.')

@section('actions')
    <a href="{{ route('admin.drivers.index') }}" class="btn btn-light border">
        <i class="bi bi-arrow-left me-1"></i> Back to Drivers
    </a>
@endsection

@section('content')
    <div class="card border-0 mb-2">
        <div class="card-body d-flex flex-wrap align-items-center gap-3">
            <x-avatar :name="$driver->name" :size="48" />
            <div class="flex-grow-1">
                <div class="d-flex align-items-center gap-2">
                    <span class="fs-5 fw-bold">{{ $driver->name }}</span>
                    <span class="badge rounded-pill bg-primary-subtle text-primary-emphasis">{{ $driver->license }}</span>
                </div>
                <div class="text-muted" style="font-size: .8rem;">
                    {{ $driver->contact_number }}
                    @if ($driver->additional_phone_number)
                        &middot; {{ $driver->additional_phone_number }}
                    @endif
                    &middot; {{ $driver->email }}
                </div>
            </div>
        </div>
    </div>

    <div class="row row-cols-1 row-cols-md-2 row-cols-xl-5 g-2 mb-2">
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #eff6ff; color: #2563eb;">
                        <i class="bi bi-journal-check"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Hires (all time)</div>
                        <div class="fs-5 fw-bold">{{ $summary['hire_count'] }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fef6e7; color: #eda100;">
                        <i class="bi bi-cash-coin"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Full Value</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['hire_full_value_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #eafbf3; color: #1baf7a;">
                        <i class="bi bi-graph-up-arrow"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Commission</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['commission_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdeee7; color: #c95a26;">
                        <i class="bi bi-receipt"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Expenses (all time)</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['expenses_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdeef3; color: #e87ba4;">
                        <i class="bi bi-wallet2"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Salary Paid</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['salary_paid_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card border-0 mb-2">
        <div class="card-header fw-semibold" style="font-size: .85rem;">Earnings Trend &middot; last {{ $trend->count() }} months</div>
        <div class="card-body">
            <div class="vehicle-trend-chart-container">
                <canvas id="driverTrendChart"></canvas>
            </div>
        </div>
    </div>

    @php $periodQuery = ['year' => $selectedYear, 'month' => $selectedMonth]; @endphp

    <ul class="nav nav-tabs mb-2" id="driver-period-tabs">
        <li class="nav-item">
            <a class="nav-link {{ $tab === 'earnings' ? 'active' : '' }}" id="tab-earnings" href="{{ route('admin.drivers.show', ['driver' => $driver] + $periodQuery) }}">
                Earnings
            </a>
        </li>
        <li class="nav-item">
            <a class="nav-link {{ $tab === 'expenses' ? 'active' : '' }}" id="tab-expenses" href="{{ route('admin.drivers.show', ['driver' => $driver, 'tab' => 'expenses'] + $periodQuery) }}">
                Expenses
                @if ($periodExpenses->isNotEmpty())
                    <span class="badge rounded-pill bg-light text-dark border ms-1">{{ $periodExpenses->count() }}</span>
                @endif
            </a>
        </li>
        <li class="nav-item">
            <a class="nav-link {{ $tab === 'salary' ? 'active' : '' }}" id="tab-salary" href="{{ route('admin.drivers.show', ['driver' => $driver, 'tab' => 'salary'] + $periodQuery) }}">
                Salary
            </a>
        </li>
    </ul>

    <div class="card border-0 mb-2">
        <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
            <span class="fw-semibold" style="font-size: .85rem;">
                {{ ['expenses' => 'Expenses', 'salary' => 'Salary'][$tab] ?? 'Earnings' }} &middot; {{ $periodLabel }}
                @if ($tab !== 'expenses' && $periodPayroll?->status === 'paid')
                    <span class="badge rounded-pill bg-success-subtle text-success-emphasis ms-1">Paid</span>
                @elseif ($tab !== 'expenses' && $periodPayroll?->status === 'finalized')
                    <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis ms-1">Finalized &middot; awaiting payment</span>
                @endif
            </span>
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                @if ($tab !== 'earnings')
                    <input type="hidden" name="tab" value="{{ $tab }}">
                @endif

                <select name="year" class="form-select form-select-sm" style="max-width: 110px;" onchange="this.form.submit()">
                    @forelse ($availableYears as $year)
                        <option value="{{ $year }}" {{ (string) $selectedYear === (string) $year ? 'selected' : '' }}>{{ $year }}</option>
                    @empty
                        <option value="{{ $selectedYear }}" selected>{{ $selectedYear }}</option>
                    @endforelse
                </select>

                <select name="month" class="form-select form-select-sm" style="max-width: 140px;" onchange="this.form.submit()">
                    @forelse ($monthsByYear[$selectedYear] ?? [] as $month)
                        <option value="{{ $month }}" {{ (string) $selectedMonth === (string) $month ? 'selected' : '' }}>{{ \Carbon\Carbon::create()->month($month)->format('F') }}</option>
                    @empty
                        <option value="{{ $selectedMonth }}" selected>{{ \Carbon\Carbon::create()->month($selectedMonth)->format('F') }}</option>
                    @endforelse
                </select>
            </form>
        </div>

        @if ($tab === 'earnings')
            <div class="row row-cols-2 row-cols-md-5 g-2 p-3 border-bottom">
                <div class="col">
                    <div class="text-muted" style="font-size: .7rem;">Hires</div>
                    <div class="fw-semibold" style="font-size: .85rem;">{{ $periodSummary['hire_count'] }}</div>
                </div>
                <div class="col">
                    <div class="text-muted" style="font-size: .7rem;">Full Value</div>
                    <div class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSummary['hire_full_value_total'], 2) }}</div>
                </div>
                <div class="col">
                    <div class="text-muted" style="font-size: .7rem;">Our Hire Value</div>
                    <div class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSummary['our_hire_value_total'], 2) }}</div>
                </div>
                <div class="col">
                    <div class="text-muted" style="font-size: .7rem;">Commission</div>
                    <div class="fw-semibold" style="color: #1baf7a; font-size: .85rem;">Rs. {{ number_format($periodSummary['commission_total'], 2) }}</div>
                </div>
                <div class="col">
                    <div class="text-muted" style="font-size: .7rem;">Salary Payable</div>
                    <div class="fw-semibold" style="font-size: .85rem;">
                        <span class="{{ $periodSummary['salary_payable'] < 0 ? 'text-danger' : '' }}">Rs. {{ number_format($periodSummary['salary_payable'], 2) }}</span>
                    </div>
                </div>
            </div>

            <div class="table-responsive">
                <table class="table align-middle mb-0">
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th>Customer</th>
                            <th>Vehicle</th>
                            <th>Type</th>
                            <th>Full Value</th>
                            <th>Commission</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($periodHires as $hire)
                            <tr>
                                <td class="text-muted" style="font-size: .8rem;">{{ $hire->effective_month_date?->format('M j, Y') ?? '—' }}</td>
                                <td style="font-size: .8rem;">{{ $hire->customer->name ?? '—' }}</td>
                                <td class="text-muted" style="font-size: .8rem;">{{ $hire->vehicle->model ?? '—' }}</td>
                                <td><span class="badge rounded-pill bg-primary-subtle text-primary-emphasis">{{ \App\Models\Hire::TOUR_TYPES[$hire->tour_type] ?? $hire->tour_type }}</span></td>
                                <td class="text-muted" style="font-size: .8rem;">Rs. {{ number_format($hire->hire_full_value, 2) }}</td>
                                <td class="fw-semibold" style="color: #1baf7a; font-size: .8rem;">Rs. {{ number_format($hire->commission, 2) }}</td>
                                <td><span class="badge rounded-pill bg-light text-dark border">{{ $hire->status_label }}</span></td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="text-center text-muted py-4">No hires for {{ $periodLabel }}.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        @elseif ($tab === 'expenses')
            <div class="row row-cols-2 row-cols-md-2 g-2 p-3 border-bottom">
                <div class="col">
                    <div class="text-muted" style="font-size: .7rem;">Expenses</div>
                    <div class="fw-semibold" style="font-size: .85rem;">{{ $periodExpenses->count() }}</div>
                </div>
                <div class="col">
                    <div class="text-muted" style="font-size: .7rem;">Total</div>
                    <div class="fw-semibold" style="color: #c95a26; font-size: .85rem;">Rs. {{ number_format($periodSummary['expenses_total'], 2) }}</div>
                </div>
            </div>

            <div class="table-responsive">
                <table class="table align-middle mb-0">
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th>Category</th>
                            <th>Hire</th>
                            <th>Amount</th>
                            <th class="text-end">Receipt</th>
                            @canany(['hires.update', 'hires.delete'])
                                <th class="text-end">Actions</th>
                            @endcanany
                        </tr>
                    </thead>
                    <tbody>
                        @forelse ($periodExpenses as $expense)
                            <tr>
                                <td class="text-muted" style="font-size: .8rem;">{{ $expense->created_at?->format('M j, Y') ?? '—' }}</td>
                                <td><span class="badge rounded-pill bg-secondary-subtle text-secondary-emphasis">{{ $expense->category_label }}</span></td>
                                <td class="text-muted" style="font-size: .8rem;">
                                    @if ($expense->hire)
                                        #{{ $expense->hire_id }} &middot; {{ \App\Models\Hire::TOUR_TYPES[$expense->hire->tour_type] ?? $expense->hire->tour_type }}
                                    @else
                                        &mdash;
                                    @endif
                                </td>
                                <td class="fw-semibold" style="color: #c95a26; font-size: .82rem;">Rs. {{ number_format($expense->amount, 2) }}</td>
                                <td class="text-end">
                                    @if ($expense->receipt_url)
                                        <a href="{{ $expense->receipt_url }}" target="_blank" class="btn btn-sm btn-light border btn-icon" title="View Receipt">
                                            <i class="bi bi-receipt"></i>
                                        </a>
                                    @else
                                        &mdash;
                                    @endif
                                </td>
                                @canany(['hires.update', 'hires.delete'])
                                    <td class="text-end">
                                        <div class="d-inline-flex gap-1">
                                            @can('hires.update')
                                                <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-expense-{{ $expense->id }}" title="Edit">
                                                    <i class="bi bi-pencil"></i>
                                                </button>
                                            @endcan
                                            @can('hires.delete')
                                                <form method="POST" action="{{ route('admin.expenses.destroy', $expense) }}" onsubmit="return confirm('Delete this expense?');">
                                                    @csrf
                                                    @method('DELETE')
                                                    <button type="submit" class="btn btn-sm btn-light border btn-icon text-danger" title="Delete">
                                                        <i class="bi bi-trash"></i>
                                                    </button>
                                                </form>
                                            @endcan
                                        </div>
                                    </td>
                                @endcanany
                            </tr>
                        @empty
                            <tr>
                                <td colspan="6" class="text-center text-muted py-4">No expenses for {{ $periodLabel }}.</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        @else
            @php
                $arrearsLoanTotal = round((float) $arrearsLoans->sum('amount'), 2);
                // Balance: plain cash-flow figure — deposit owed minus what's
                // physically been transferred so far. Floored at 0 for
                // display: a driver who transferred more than they owed
                // doesn't have a negative balance, there's just nothing left.
                $balance = round($periodSalary['deposit_amount'] - $transferredTotal, 2);
                $balanceDisplay = max($balance, 0.0);
                $netPayableBase = $periodSalary['net_salary_payable'];
                $finalNetPayable = round($netPayableBase - $balance, 2);
                // The deficit still available to convert into a NEW arrears
                // loan — nets out anything already converted, so the button
                // below can't create duplicate loans for the same shortfall.
                $unresolvedDeficit = round($netPayableBase - ($periodSalary['deposit_amount'] - $transferredTotal - $arrearsLoanTotal), 2);
            @endphp
            <div class="p-3">
                <div class="row row-cols-2 row-cols-md-3 g-2 mb-3">
                    <div class="col">
                        <div class="text-muted" style="font-size: .7rem;">Total Hired Value</div>
                        <div class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSalary['hire_full_value_total'], 2) }}</div>
                    </div>
                    <div class="col">
                        <div class="text-muted" style="font-size: .7rem;">Our Hire Value</div>
                        <div class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSalary['our_hire_value_total'], 2) }}</div>
                    </div>
                    <div class="col">
                        <div class="text-muted" style="font-size: .7rem;">Commission</div>
                        <div class="fw-semibold" style="color: #1baf7a; font-size: .85rem;">Rs. {{ number_format($periodSummary['commission_total'], 2) }}</div>
                    </div>
                </div>

                @if ($periodSalary['hire_count'] === 0 && $periodSalary['advance_deduction_total'] <= 0 && $periodSalary['carryover_deduction_total'] <= 0 && $periodSalary['arrears_deduction_total'] <= 0)
                    <div class="text-center text-muted py-4">
                        <i class="bi bi-cash-coin fs-3 d-block mb-2"></i>
                        No hires recorded for {{ $periodLabel }} yet.
                    </div>
                @else
                    <div class="fw-semibold mb-2" style="font-size: .82rem;">Expenses deducted from salary</div>
                    <div class="d-flex flex-column gap-2 mb-3">
                        @foreach ($periodSalary['expenses_by_category'] as $category => $amount)
                            <div class="d-flex align-items-center justify-content-between border rounded p-2">
                                <span style="font-size: .8rem;">{{ \App\Models\HireExpense::CATEGORIES[$category] ?? $category }}</span>
                                <span class="text-danger fw-semibold" style="font-size: .8rem;">-Rs. {{ number_format($amount, 2) }}</span>
                            </div>
                        @endforeach
                    </div>

                    <div class="border-top pt-3">
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Total Expenses</span>
                            <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($periodSalary['expenses_total'], 2) }}</span>
                        </div>
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Net Before Salary</span>
                            <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSalary['net_before_salary'], 2) }}</span>
                        </div>
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="fw-semibold" style="font-size: .9rem;">{{ $periodSalary['salary_percentage'] }}% Driver Salary</span>
                            <span class="fw-bold text-success" style="font-size: 1.1rem;">Rs. {{ number_format($periodSalary['salary'], 2) }}</span>
                        </div>
                        @if ($periodSalary['advance_deduction_total'] > 0)
                            <div class="d-flex align-items-center justify-content-between mb-2">
                                <span class="text-muted" style="font-size: .82rem;">Salary Advance Deduction</span>
                                <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($periodSalary['advance_deduction_total'], 2) }}</span>
                            </div>
                        @endif
                        @if ($periodSalary['carryover_deduction_total'] > 0)
                            <div class="d-flex align-items-center justify-content-between mb-2">
                                <span class="text-muted" style="font-size: .82rem;">Carried Over from Previous Month</span>
                                <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($periodSalary['carryover_deduction_total'], 2) }}</span>
                            </div>
                        @endif
                        @if ($periodSalary['arrears_deduction_total'] > 0)
                            <div class="d-flex align-items-center justify-content-between mb-2">
                                <span class="text-muted" style="font-size: .82rem;">Arrears Loan Deduction</span>
                                <span class="fw-semibold text-danger" style="font-size: .85rem;">-Rs. {{ number_format($periodSalary['arrears_deduction_total'], 2) }}</span>
                            </div>
                        @endif
                        <div class="d-flex align-items-center justify-content-between border-top pt-2">
                            <span class="fw-semibold" style="font-size: .9rem;">Net Salary Payable</span>
                            <span class="fw-bold {{ $periodSalary['net_salary_payable'] < 0 ? 'text-danger' : 'text-success' }}" style="font-size: 1.1rem;">Rs. {{ number_format($periodSalary['net_salary_payable'], 2) }}</span>
                        </div>
                    </div>
                @endif

                @if ($periodSalary['deposit_amount'] != 0 || $transferredTotal > 0)
                    <div class="border-top pt-3 mt-3">
                        <div class="fw-semibold mb-2" style="font-size: .9rem;">Deposit</div>
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Total Hire Value</span>
                            <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSalary['hire_full_value_total'], 2) }}</span>
                        </div>
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Cash Payments</span>
                            <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSalary['hire_full_value_by_payment_type']['cash'] ?? 0, 2) }}</span>
                        </div>
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="text-muted" style="font-size: .82rem;">Credit Payments</span>
                            <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSalary['hire_full_value_by_payment_type']['credit'] ?? 0, 2) }}</span>
                        </div>
                        <div class="d-flex align-items-center justify-content-between mb-2 border-top pt-2">
                            <span class="text-muted" style="font-size: .82rem;">Deposit Amount</span>
                            <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($periodSalary['deposit_amount'], 2) }}</span>
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
                            Net Salary Payable (Rs. {{ number_format($netPayableBase, 2) }}) - Deposit Balance (Rs. {{ number_format($balanceDisplay, 2) }})
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
                        @if ($periodPayroll?->status === 'paid')
                            <span class="badge rounded-pill bg-success-subtle text-success-emphasis">Paid</span>
                        @elseif ($periodPayroll?->status === 'finalized')
                            <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis">Finalized &middot; awaiting payment</span>
                        @endif
                    </div>

                    @if (! $periodPayroll)
                        @can('payroll.manage')
                            <button type="button" class="btn btn-sm btn-outline-primary make-payroll-btn" data-target="#payroll-form-{{ $driver->id }}">
                                <i class="bi bi-cash-coin me-1"></i> Make Payroll
                            </button>

                            <div id="payroll-form-{{ $driver->id }}" class="d-none mt-3 border rounded p-3 payroll-form-wrapper" style="background: #f8f9fb;">
                                <form id="form-finalize-payroll-{{ $driver->id }}" method="POST" action="{{ route('admin.drivers.payroll.finalize', $driver) }}">
                                    @csrf
                                    <input type="hidden" name="year" value="{{ $selectedYear }}">
                                    <input type="hidden" name="month" value="{{ $selectedMonth }}">
                                    <input type="hidden" name="redirect_to" value="show">

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
                                <span style="font-size: .8rem;">Rs. {{ number_format($periodPayroll->salary, 2) }}</span>
                            </div>
                            <div class="d-flex align-items-center justify-content-between">
                                <span class="text-muted" style="font-size: .8rem;">Advance Deduction</span>
                                <span style="font-size: .8rem;">-Rs. {{ number_format($periodPayroll->advance_deduction_total, 2) }}</span>
                            </div>
                            @if ((float) $periodPayroll->carryover_deduction_total > 0)
                                <div class="d-flex align-items-center justify-content-between">
                                    <span class="text-muted" style="font-size: .8rem;">Carried Over from Previous Month</span>
                                    <span style="font-size: .8rem;">-Rs. {{ number_format($periodPayroll->carryover_deduction_total, 2) }}</span>
                                </div>
                            @endif
                            @if ((float) $periodPayroll->arrears_deduction_total > 0)
                                <div class="d-flex align-items-center justify-content-between">
                                    <span class="text-muted" style="font-size: .8rem;">Arrears Loan Deduction</span>
                                    <span style="font-size: .8rem;">-Rs. {{ number_format($periodPayroll->arrears_deduction_total, 2) }}</span>
                                </div>
                            @endif
                            @if ((float) $periodPayroll->deposit_balance > 0)
                                <div class="d-flex align-items-center justify-content-between">
                                    <span class="text-muted" style="font-size: .8rem;">Deposit Balance</span>
                                    <span style="font-size: .8rem;">-Rs. {{ number_format($periodPayroll->deposit_balance, 2) }}</span>
                                </div>
                            @endif
                            @if ((float) $periodPayroll->arrears_loan_offset > 0)
                                <div class="d-flex align-items-center justify-content-between">
                                    <span class="text-muted" style="font-size: .8rem;">Converted to Arrears Loan (Full Amount)</span>
                                    <span class="text-success" style="font-size: .8rem;">+Rs. {{ number_format($periodPayroll->arrears_loan_offset, 2) }}</span>
                                </div>
                            @endif
                            @if ((float) $periodPayroll->manual_adjustment !== 0.0)
                                <div class="d-flex align-items-center justify-content-between">
                                    <span class="text-muted" style="font-size: .8rem;">
                                        Manual Adjustment
                                        @if ($periodPayroll->adjustment_note)
                                            <span title="{{ $periodPayroll->adjustment_note }}">&ldquo;{{ \Illuminate\Support\Str::limit($periodPayroll->adjustment_note, 24) }}&rdquo;</span>
                                        @endif
                                    </span>
                                    <span style="font-size: .8rem;" class="{{ (float) $periodPayroll->manual_adjustment < 0 ? 'text-danger' : 'text-success' }}">
                                        {{ (float) $periodPayroll->manual_adjustment < 0 ? '-' : '+' }}Rs. {{ number_format(abs($periodPayroll->manual_adjustment), 2) }}
                                    </span>
                                </div>
                            @endif
                            <div class="d-flex align-items-center justify-content-between border-top pt-2 mt-1">
                                <span class="fw-semibold" style="font-size: .9rem;">Final Amount</span>
                                <span class="fw-bold {{ (float) $periodPayroll->final_amount < 0 ? 'text-danger' : 'text-success' }}" style="font-size: 1.1rem;">
                                    {{ (float) $periodPayroll->final_amount < 0 ? '-' : '' }}Rs. {{ number_format(abs($periodPayroll->final_amount), 2) }}
                                </span>
                            </div>
                        </div>
                        <div class="text-muted" style="font-size: .72rem;">
                            Finalized by {{ $periodPayroll->finalizedBy?->name ?? '—' }} &middot; {{ $periodPayroll->finalized_at?->format('M j, Y g:i A') }}
                        </div>
                        @if ($periodPayroll->status === 'paid')
                            <div class="text-muted" style="font-size: .72rem;">
                                Paid by {{ $periodPayroll->paidBy?->name ?? '—' }} &middot; {{ $periodPayroll->paid_at?->format('M j, Y g:i A') }}
                            </div>
                            @if ((float) $periodPayroll->final_amount < 0)
                                @php
                                    $carryTarget = \Carbon\Carbon::create($periodPayroll->year, $periodPayroll->month, 1)->addMonthNoOverflow();
                                @endphp
                                <div class="alert alert-danger py-2 px-3 mt-2 mb-0" style="font-size: .78rem;">
                                    <i class="bi bi-arrow-return-right me-1"></i>
                                    This payroll had a shortfall of <strong>Rs. {{ number_format(abs($periodPayroll->final_amount), 2) }}</strong> —
                                    carried forward as a deduction on {{ $carryTarget->format('F Y') }}'s salary.
                                </div>
                            @endif
                        @endif

                        <a href="{{ route('admin.drivers.payroll.slip', [$driver, $periodPayroll]) }}" target="_blank" class="btn btn-sm btn-outline-secondary mt-2">
                            <i class="bi bi-printer me-1"></i> Print Salary Slip
                        </a>

                        @can('payroll.manage')
                            @if ($periodPayroll->status === 'finalized')
                                <div class="d-flex gap-2 mt-2">
                                    <form method="POST" action="{{ route('admin.drivers.payroll.mark-paid', [$driver, $periodPayroll]) }}" onsubmit="return confirm('Mark this payroll as paid? This cannot be undone.');">
                                        @csrf
                                        <input type="hidden" name="year" value="{{ $selectedYear }}">
                                        <input type="hidden" name="month" value="{{ $selectedMonth }}">
                                        <input type="hidden" name="redirect_to" value="show">
                                        <button type="submit" class="btn btn-sm btn-success">
                                            <i class="bi bi-check-circle me-1"></i> Mark as Paid
                                        </button>
                                    </form>
                                    <form method="POST" action="{{ route('admin.drivers.payroll.revert', [$driver, $periodPayroll]) }}" onsubmit="return confirm('Revert this finalized payroll? It will be deleted so you can make it again with different figures.');">
                                        @csrf
                                        @method('DELETE')
                                        <input type="hidden" name="year" value="{{ $selectedYear }}">
                                        <input type="hidden" name="month" value="{{ $selectedMonth }}">
                                        <input type="hidden" name="redirect_to" value="show">
                                        <button type="submit" class="btn btn-sm btn-outline-danger">
                                            <i class="bi bi-arrow-counterclockwise me-1"></i> Revert
                                        </button>
                                    </form>
                                </div>
                            @endif
                        @endcan
                    @endif
                </div>
            </div>
        @endif
    </div>

    @can('payroll.manage')
        @if ($tab === 'salary' && $unresolvedDeficit < 0)
            <x-modal id="modal-arrears-{{ $driver->id }}" title="Change as Arrears Loan — {{ $driver->name }}">
                <form id="form-arrears-{{ $driver->id }}" class="arrears-loan-form" method="POST" action="{{ route('admin.drivers.arrears-loan.store', $driver) }}" data-amount="{{ abs($unresolvedDeficit) }}">
                    @csrf
                    <input type="hidden" name="year" value="{{ $selectedYear }}">
                    <input type="hidden" name="month" value="{{ $selectedMonth }}">
                    <input type="hidden" name="redirect_to" value="show">

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

        @if ($tab === 'salary')
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
        @endif
    @endcan

    @can('hires.update')
        @foreach ($periodExpenses as $expense)
            <x-modal id="modal-edit-expense-{{ $expense->id }}" title="Edit Expense">
                <form id="form-edit-expense-{{ $expense->id }}" method="POST" action="{{ route('admin.expenses.update', $expense) }}">
                    @csrf
                    @method('PUT')
                    <div class="row g-2">
                        <div class="col-md-6">
                            <label for="edit-expense-{{ $expense->id }}-category" class="form-label">Category</label>
                            <select id="edit-expense-{{ $expense->id }}-category" name="category" class="form-select" required>
                                @foreach (\App\Models\HireExpense::CATEGORIES as $key => $label)
                                    <option value="{{ $key }}" {{ $expense->category === $key ? 'selected' : '' }}>{{ $label }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div class="col-md-6">
                            <label for="edit-expense-{{ $expense->id }}-amount" class="form-label">Amount (Rs.)</label>
                            <input id="edit-expense-{{ $expense->id }}-amount" type="number" step="0.01" min="0.01" name="amount"
                                value="{{ $expense->amount }}" class="form-control" placeholder="0.00" required>
                        </div>
                    </div>
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-expense-{{ $expense->id }}" class="btn btn-primary">Update Expense</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan
@endsection

@push('styles')
    <style>
        .vehicle-trend-chart-container { position: relative; height: 300px; }

        /* The tabs in the panel's own colours, not Bootstrap's default blue. */
        #driver-period-tabs .nav-link { color: var(--text-muted); font-weight: 500; }
        #driver-period-tabs .nav-link:hover { color: var(--text-dark); }
        #driver-period-tabs .nav-link.active { color: var(--primary); font-weight: 600; }
    </style>
@endpush

@push('scripts')
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"></script>
    <script>
        (function () {
            const canvas = document.getElementById('driverTrendChart');
            if (!canvas) return;

            const trend = @json($trend);
            const series = [
                { key: 'hire_full_value_total', label: 'Full Value', color: '#eda100' },
                { key: 'commission_total', label: 'Commission', color: '#1baf7a' },
            ];

            const money = (value) => 'Rs. ' + Number(value).toLocaleString(undefined, { maximumFractionDigits: 0 });

            new Chart(canvas, {
                type: 'line',
                data: {
                    labels: trend.map((row) => row.label),
                    datasets: series.map((s) => ({
                        label: s.label,
                        data: trend.map((row) => row[s.key]),
                        borderColor: s.color,
                        backgroundColor: s.color,
                        pointBackgroundColor: s.color,
                        pointBorderColor: '#fcfcfb',
                        pointBorderWidth: 2,
                        borderWidth: 2,
                        pointRadius: 3,
                        pointHoverRadius: 5,
                        tension: 0.3,
                        fill: false,
                    })),
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    interaction: { mode: 'index', intersect: false },
                    scales: {
                        x: { grid: { display: false }, ticks: { color: '#52514e', font: { size: 11, weight: '600' } } },
                        y: {
                            beginAtZero: true,
                            grid: { color: '#eee' },
                            ticks: { color: '#8a887f', callback: (value) => money(value) },
                        },
                    },
                    plugins: {
                        legend: {
                            position: 'top',
                            align: 'start',
                            labels: {
                                usePointStyle: true,
                                pointStyle: 'line',
                                color: '#52514e',
                                font: { size: 12, weight: '600' },
                                padding: 14,
                            },
                        },
                        tooltip: {
                            backgroundColor: '#0b0b0b',
                            padding: 10,
                            titleFont: { size: 12, weight: '600' },
                            bodyFont: { size: 12 },
                            callbacks: {
                                label: (ctx) => ' ' + ctx.dataset.label + ':  ' + money(ctx.parsed.y),
                            },
                        },
                    },
                },
            });
        })();
    </script>
@endpush

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
