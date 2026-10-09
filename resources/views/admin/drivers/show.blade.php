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

    <div class="row row-cols-1 row-cols-md-2 row-cols-xl-4 g-2 mb-2">
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

    <div class="card border-0 mb-2">
        <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2">
            <span class="fw-semibold" style="font-size: .85rem;">
                Earnings &middot; {{ $periodLabel }}
                @if ($periodPayroll?->status === 'paid')
                    <span class="badge rounded-pill bg-success-subtle text-success-emphasis ms-1">Paid</span>
                @elseif ($periodPayroll?->status === 'finalized')
                    <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis ms-1">Finalized &middot; awaiting payment</span>
                @endif
            </span>
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
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
    </div>
@endsection

@push('styles')
    <style>
        .vehicle-trend-chart-container { position: relative; height: 300px; }
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
