@extends('layouts.admin')

@section('title', 'Vehicle Revenue')
@section('subtitle', 'Revenue, commission, and net earnings broken down by vehicle.')

@section('content')
    <div class="row row-cols-1 row-cols-md-3 g-2 mb-2">
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fef6e7; color: #eda100;">
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
                    <div class="stat-icon" style="background: #eafbf3; color: #1baf7a;">
                        <i class="bi bi-graph-up-arrow"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Commission &middot; {{ $periodLabel }}</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['commission_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdeef3; color: #e87ba4;">
                        <i class="bi bi-piggy-bank"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Net Revenue &middot; {{ $periodLabel }}</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['net_revenue'], 2) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">after Rs. {{ number_format($summary['maintenance_total'], 2) }} maintenance</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card border-0 mb-2">
        <div class="card-header">
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
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

        @if ($rows->isEmpty())
            <div class="card-body text-center text-muted py-5">
                <i class="bi bi-car-front fs-4 d-block mb-2"></i>
                No vehicles yet.
            </div>
        @else
            <div class="card-body">
                <div class="vehicle-revenue-chart-container">
                    <canvas id="vehicleRevenueChart"></canvas>
                </div>
            </div>
        @endif
    </div>

    @if ($rows->isNotEmpty())
        <div class="card border-0">
            <div class="table-responsive">
                <table class="table align-middle">
                    <thead>
                        <tr>
                            <th>Vehicle</th>
                            <th>Hires</th>
                            <th>Full Value</th>
                            <th>Our Hire Value</th>
                            <th>Commission</th>
                            <th>Maintenance</th>
                            <th>Net Revenue</th>
                            <th>Share</th>
                            <th class="text-end">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($rows as $row)
                            @php
                                $share = $summary['commission_total'] > 0
                                    ? max(0, min(100, ($row['commission_total'] / $summary['commission_total']) * 100))
                                    : 0;
                            @endphp
                            <tr>
                                <td>
                                    <div class="d-flex align-items-center gap-2">
                                        <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #eef2ff; color: #4f46e5;">
                                            <i class="bi bi-car-front"></i>
                                        </div>
                                        <span class="fw-semibold" style="font-size: .8rem;">{{ $row['vehicle']->model }}</span>
                                    </div>
                                </td>
                                <td class="text-muted">{{ $row['hire_count'] }}</td>
                                <td class="text-muted">Rs. {{ number_format($row['hire_full_value_total'], 2) }}</td>
                                <td class="text-muted">Rs. {{ number_format($row['our_hire_value_total'], 2) }}</td>
                                <td class="fw-semibold" style="color: #1baf7a; font-size: .8rem;">Rs. {{ number_format($row['commission_total'], 2) }}</td>
                                <td class="text-muted">
                                    @if ($row['maintenance_total'] > 0)
                                        Rs. {{ number_format($row['maintenance_total'], 2) }}
                                    @else
                                        &mdash;
                                    @endif
                                </td>
                                <td class="fw-semibold" style="font-size: .8rem;">
                                    <span class="{{ $row['net_revenue'] < 0 ? 'text-danger' : '' }}">Rs. {{ number_format($row['net_revenue'], 2) }}</span>
                                </td>
                                <td style="min-width: 110px;">
                                    <div class="d-flex align-items-center gap-2">
                                        <div class="progress flex-grow-1" style="height: 6px; width: 60px;">
                                            <div class="progress-bar" role="progressbar" style="width: {{ $share }}%; background: #1baf7a;"></div>
                                        </div>
                                        <span class="text-muted" style="font-size: .7rem;">{{ number_format($share, 0) }}%</span>
                                    </div>
                                </td>
                                <td class="text-end">
                                    <a href="{{ route('admin.vehicles.show', $row['vehicle']) }}" class="btn btn-sm btn-light border btn-icon">
                                        <i class="bi bi-eye"></i>
                                    </a>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                    <tfoot>
                        <tr class="fw-semibold" style="font-size: .8rem;">
                            <td>Total</td>
                            <td class="text-muted">{{ $rows->sum('hire_count') }}</td>
                            <td>Rs. {{ number_format($summary['hire_full_value_total'], 2) }}</td>
                            <td>Rs. {{ number_format($summary['our_hire_value_total'], 2) }}</td>
                            <td style="color: #1baf7a;">Rs. {{ number_format($summary['commission_total'], 2) }}</td>
                            <td>Rs. {{ number_format($summary['maintenance_total'], 2) }}</td>
                            <td>Rs. {{ number_format($summary['net_revenue'], 2) }}</td>
                            <td></td>
                            <td></td>
                        </tr>
                    </tfoot>
                </table>
            </div>
        </div>
    @endif
@endsection

@push('styles')
    <style>
        .vehicle-revenue-chart-container { position: relative; height: 320px; }
        @media (min-width: 768px) {
            .vehicle-revenue-chart-container { height: 280px; }
        }
    </style>
@endpush

@push('scripts')
    @if ($rows->isNotEmpty())
        <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"></script>
        <script>
            (function () {
                const canvas = document.getElementById('vehicleRevenueChart');
                if (!canvas) return;

                @php
                    $chartRows = $rows->map(fn ($row) => [
                        'label' => $row['vehicle']->model,
                        'hire_full_value_total' => $row['hire_full_value_total'],
                        'commission_total' => $row['commission_total'],
                        'maintenance_total' => $row['maintenance_total'],
                    ])->values();
                @endphp
                const rows = @json($chartRows);

                const series = [
                    { key: 'hire_full_value_total', label: 'Full Value', color: '#eda100' },
                    { key: 'commission_total', label: 'Commission', color: '#1baf7a' },
                    { key: 'maintenance_total', label: 'Maintenance', color: '#e2574c' },
                ];

                const money = (value) => 'Rs. ' + Number(value).toLocaleString(undefined, { maximumFractionDigits: 0 });

                new Chart(canvas, {
                    type: 'bar',
                    data: {
                        labels: rows.map((row) => row.label),
                        datasets: series.map((s) => ({
                            label: s.label,
                            data: rows.map((row) => row[s.key]),
                            backgroundColor: s.color,
                            borderRadius: 4,
                            maxBarThickness: 36,
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
                                    pointStyle: 'rectRounded',
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
    @endif
@endpush
