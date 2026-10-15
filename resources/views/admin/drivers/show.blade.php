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
            </div>
        @endif
    </div>

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
