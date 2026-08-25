@extends('layouts.admin')

@section('title', 'Dashboard')
@section('subtitle', 'Welcome back, ' . explode(' ', auth()->user()->name)[0] . '. Here\'s ' . $periodLabel . ' at a glance.')

@section('content')
    @can('drivers.view')
        @php
            $deltaDisplay = fn ($value) => match (true) {
                $value === null => ['label' => 'New', 'class' => 'text-secondary', 'icon' => 'dash-lg'],
                $value > 0 => ['label' => number_format($value, 1) . '%', 'class' => 'text-success', 'icon' => 'arrow-up-short'],
                $value < 0 => ['label' => number_format(abs($value), 1) . '%', 'class' => 'text-danger', 'icon' => 'arrow-down-short'],
                default => ['label' => 'No change', 'class' => 'text-muted', 'icon' => 'dash-lg'],
            };

            $cards = [
                [
                    'label' => 'Total Our Hire Value',
                    'value' => $summary['our_hire_value_total'],
                    'delta' => $deltaDisplay($deltas['our_hire_value_total']),
                    'icon' => 'cash-stack',
                    'bg' => '#eaf2fc',
                    'fg' => '#2a78d6',
                ],
                [
                    'label' => 'Total All Drivers Salary',
                    'value' => $summary['salary_total'],
                    'delta' => $deltaDisplay($deltas['salary_total']),
                    'icon' => 'wallet2',
                    'bg' => '#fdeee7',
                    'fg' => '#c95a26',
                ],
                [
                    'label' => 'Total Commission',
                    'value' => $summary['commission_total'],
                    'delta' => $deltaDisplay($deltas['commission_total']),
                    'icon' => 'piggy-bank',
                    'bg' => '#e6f7f1',
                    'fg' => '#158f66',
                ],
                [
                    'label' => 'Total Hire Full Value',
                    'value' => $summary['hire_full_value_total'],
                    'delta' => $deltaDisplay($deltas['hire_full_value_total']),
                    'icon' => 'cash-coin',
                    'bg' => '#fef3e0',
                    'fg' => '#b3810a',
                ],
                [
                    'label' => 'Total Profit',
                    'value' => $summary['profit_total'],
                    'delta' => $deltaDisplay($deltas['profit_total']),
                    'icon' => 'graph-up-arrow',
                    'bg' => '#fdeef4',
                    'fg' => '#c2477a',
                    'modal' => 'modal-profit-breakdown',
                ],
            ];
        @endphp

        <div class="row row-cols-2 row-cols-md-2 row-cols-xl-5 g-2 mb-2">
            @foreach ($cards as $card)
                <div class="col">
                    <div class="card border-0 h-100 {{ isset($card['modal']) ? 'profit-card-clickable' : '' }}"
                        @if (isset($card['modal'])) role="button" tabindex="0" data-bs-toggle="modal" data-bs-target="#{{ $card['modal'] }}" @endif>
                        <div class="card-body dashboard-stat-card-body">
                            <div class="d-flex align-items-center gap-2 mb-2">
                                <div class="stat-icon dashboard-stat-icon" style="background: {{ $card['bg'] }}; color: {{ $card['fg'] }};">
                                    <i class="bi bi-{{ $card['icon'] }}"></i>
                                </div>
                                <div class="text-muted small">
                                    {{ $card['label'] }}
                                    <span class="d-none d-sm-inline">&middot; {{ $periodLabel }}</span>
                                    @isset($card['modal'])
                                        <i class="bi bi-info-circle ms-1" title="Click for the full calculation"></i>
                                    @endisset
                                </div>
                            </div>
                            <div class="d-flex align-items-baseline justify-content-between flex-wrap gap-1">
                                <div class="fs-5 dashboard-stat-value fw-bold {{ $card['value'] < 0 ? 'text-danger' : '' }}">
                                    {{ $card['value'] < 0 ? '-' : '' }}Rs. {{ number_format(abs($card['value']), 2) }}
                                </div>
                                <div class="{{ $card['delta']['class'] }}" style="font-size: .75rem; font-weight: 600;">
                                    <i class="bi bi-{{ $card['delta']['icon'] }}"></i>
                                    {{ $card['delta']['label'] }}
                                </div>
                            </div>
                            <div class="text-muted" style="font-size: .7rem;">vs previous month</div>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>

        @push('styles')
            <style>
                .profit-card-clickable { cursor: pointer; transition: box-shadow .15s ease, transform .15s ease; }
                .profit-card-clickable:hover { box-shadow: 0 4px 14px rgba(0,0,0,.08); transform: translateY(-1px); }

                /* Compact stat cards — on mobile these already sit two per
                   row; tighten padding/type so the whole stack (5 main +
                   6 secondary cards) doesn't take forever to scroll past
                   before reaching the chart. */
                @media (max-width: 767.98px) {
                    .dashboard-stat-card-body { padding: .7rem .8rem; }
                    .dashboard-stat-icon { width: 30px; height: 30px; font-size: .85rem; }
                    .dashboard-stat-value { font-size: 1rem; }
                    .dashboard-secondary-card-body.card-body { padding: .5rem .65rem; }
                }
            </style>
        @endpush

        <x-modal id="modal-profit-breakdown" title="Total Profit — Full Calculation ({{ $periodLabel }})">
            <div class="d-flex flex-column gap-2">
                <div class="d-flex align-items-center justify-content-between">
                    <span style="font-size: .85rem;">Total Our Hire Value</span>
                    <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($profitBreakdown['our_hire_value_total'], 2) }}</span>
                </div>

                <div class="border-top pt-2">
                    <div class="text-muted mb-1" style="font-size: .78rem;">Less: Expenses</div>
                    @foreach ($profitBreakdown['expenses_by_category'] as $category => $amount)
                        @if ($amount > 0)
                            <div class="d-flex align-items-center justify-content-between ps-2 mb-1">
                                <span class="text-muted" style="font-size: .8rem;">{{ \App\Models\HireExpense::CATEGORIES[$category] ?? ucfirst($category) }}</span>
                                <span class="text-danger" style="font-size: .8rem;">-Rs. {{ number_format($amount, 2) }}</span>
                            </div>
                        @endif
                    @endforeach
                    <div class="d-flex align-items-center justify-content-between ps-2">
                        <span class="text-muted fw-semibold" style="font-size: .8rem;">Total Expenses</span>
                        <span class="text-danger fw-semibold" style="font-size: .8rem;">-Rs. {{ number_format($profitBreakdown['expenses_total'], 2) }}</span>
                    </div>
                </div>

                <div class="d-flex align-items-center justify-content-between border-top pt-2">
                    <span class="fw-semibold" style="font-size: .85rem;">Net Before Salary</span>
                    <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($profitBreakdown['net_before_salary'], 2) }}</span>
                </div>

                <div class="d-flex align-items-center justify-content-between">
                    <span style="font-size: .85rem;">Less: Driver Salary ({{ $profitBreakdown['salary_percentage'] }}%)</span>
                    <span class="text-danger" style="font-size: .85rem;">-Rs. {{ number_format($profitBreakdown['salary_total'], 2) }}</span>
                </div>

                <div class="d-flex align-items-center justify-content-between">
                    <span style="font-size: .85rem;">Less: Leasing Installments</span>
                    <span class="text-danger" style="font-size: .85rem;">-Rs. {{ number_format($profitBreakdown['leasing_installment_total'], 2) }}</span>
                </div>

                <div class="d-flex align-items-center justify-content-between">
                    <span style="font-size: .85rem;">Less: Vehicle Repair Cost</span>
                    <span class="text-danger" style="font-size: .85rem;">-Rs. {{ number_format($profitBreakdown['repair_cost_total'], 2) }}</span>
                </div>

                <div class="d-flex align-items-center justify-content-between border-top pt-2 mt-1">
                    <span class="fw-bold">Total Profit</span>
                    <span class="fw-bold {{ $profitBreakdown['profit_total'] < 0 ? 'text-danger' : 'text-success' }}" style="font-size: 1.1rem;">
                        {{ $profitBreakdown['profit_total'] < 0 ? '-' : '' }}Rs. {{ number_format(abs($profitBreakdown['profit_total']), 2) }}
                    </span>
                </div>

                <div class="text-muted mt-2" style="font-size: .72rem;">
                    Our Hire Value (Rs. {{ number_format($profitBreakdown['our_hire_value_total'], 2) }})
                    − Expenses (Rs. {{ number_format($profitBreakdown['expenses_total'], 2) }})
                    − Driver Salary (Rs. {{ number_format($profitBreakdown['salary_total'], 2) }})
                    − Leasing Installments (Rs. {{ number_format($profitBreakdown['leasing_installment_total'], 2) }})
                    − Vehicle Repair Cost (Rs. {{ number_format($profitBreakdown['repair_cost_total'], 2) }})
                    = {{ $profitBreakdown['profit_total'] < 0 ? '-' : '' }}Rs. {{ number_format(abs($profitBreakdown['profit_total']), 2) }}.
                </div>
            </div>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Close</button>
            </x-slot:footer>
        </x-modal>

        @php
            $smallCards = [
                ['label' => 'Repair Cost', 'value' => 'Rs. ' . number_format($secondary['repair_cost_total'], 2), 'icon' => 'tools'],
                ['label' => 'Avg. Day Hire Rate', 'value' => 'Rs. ' . number_format($secondary['avg_day_hire_rate'], 2), 'icon' => 'speedometer2'],
                ['label' => 'Salary Advanced', 'value' => 'Rs. ' . number_format($secondary['salary_advanced_total'], 2), 'icon' => 'cash'],
                ['label' => 'Credit Hires', 'value' => number_format($secondary['credit_hires_count']), 'icon' => 'credit-card'],
                ['label' => 'Cash Hires', 'value' => number_format($secondary['cash_hires_count']), 'icon' => 'wallet'],
                ['label' => 'Pending Deposit', 'value' => 'Rs. ' . number_format($secondary['pending_deposit_total'], 2), 'icon' => 'hourglass-split'],
            ];
        @endphp

        <div class="row row-cols-2 row-cols-md-3 row-cols-xl-6 g-2 mb-2">
            @foreach ($smallCards as $card)
                <div class="col">
                    <div class="card border-0 h-100">
                        <div class="card-body dashboard-secondary-card-body d-flex align-items-center gap-2 py-2 px-3">
                            <i class="bi bi-{{ $card['icon'] }} text-muted"></i>
                            <div>
                                <div class="text-muted" style="font-size: .68rem;">{{ $card['label'] }}</div>
                                <div class="fw-semibold" style="font-size: .85rem;">{{ $card['value'] }}</div>
                            </div>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>

        <div class="card border-0">
            <div class="card-header d-flex align-items-center justify-content-between">
                <span class="fw-semibold">Trend &middot; Last {{ $trend->count() }} Months</span>
            </div>
            <div class="card-body">
                @if ($trend->sum('hire_full_value_total') == 0)
                    <div class="text-center text-muted py-5">
                        <i class="bi bi-graph-up fs-3 d-block mb-2"></i>
                        No hire activity yet — the trend will fill in once there's data to chart.
                    </div>
                @else
                    <div class="dashboard-chart-container">
                        <canvas id="dashboardTrendChart"></canvas>
                    </div>
                @endif
            </div>
        </div>

        @push('styles')
            <style>
                .dashboard-chart-container { position: relative; height: 340px; }
                /* The 5-series legend wraps onto more lines at narrow
                   widths — give it the extra room so it doesn't crush the
                   plot area down to a sliver. */
                @media (max-width: 575.98px) {
                    .dashboard-chart-container { height: 420px; }
                }
            </style>
        @endpush

        @push('scripts')
            <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"></script>
            <script>
                (function () {
                    const canvas = document.getElementById('dashboardTrendChart');
                    if (!canvas) return;

                    const trend = @json($trend);

                    const series = [
                        { key: 'our_hire_value_total', label: 'Our Hire Value', color: '#2a78d6' },
                        { key: 'salary_total', label: 'All Drivers Salary', color: '#eb6834' },
                        { key: 'commission_total', label: 'Commission', color: '#1baf7a' },
                        { key: 'hire_full_value_total', label: 'Hire Full Value', color: '#eda100' },
                        { key: 'profit_total', label: 'Profit', color: '#e87ba4' },
                    ];

                    const money = (value, decimals = 0) => 'Rs. ' + Number(value).toLocaleString(undefined, {
                        minimumFractionDigits: decimals,
                        maximumFractionDigits: decimals,
                    });

                    // Below this width there isn't room for a 80px label
                    // gutter without crushing the plot itself — the legend
                    // and tooltip already carry the values, so the direct
                    // end-of-line labels are dropped rather than overlapping
                    // unreadably (still "selective" per the dataviz method,
                    // just selecting none of them at this size).
                    const isNarrow = canvas.parentElement.clientWidth < 480;

                    // Direct end-of-line labels — mandatory at this series count (4)
                    // per the dataviz method. Text stays in neutral ink (never the
                    // series color); the line itself, right beside the label,
                    // carries identity.
                    const endLabelsPlugin = {
                        id: 'endLabels',
                        afterDatasetsDraw(chart) {
                            if (isNarrow) return;

                            const { ctx } = chart;
                            const items = [];

                            chart.data.datasets.forEach((dataset, i) => {
                                const meta = chart.getDatasetMeta(i);
                                if (meta.hidden) return;
                                const point = meta.data[meta.data.length - 1];
                                const value = dataset.data[dataset.data.length - 1];
                                if (!point || value == null) return;
                                items.push({ x: point.x, y: point.y, value });
                            });

                            items.sort((a, b) => a.y - b.y);
                            const minGap = 14;
                            for (let i = 1; i < items.length; i++) {
                                if (items[i].y - items[i - 1].y < minGap) {
                                    items[i].y = items[i - 1].y + minGap;
                                }
                            }

                            ctx.save();
                            ctx.font = '600 11px system-ui, -apple-system, "Segoe UI", sans-serif';
                            ctx.fillStyle = '#52514e';
                            ctx.textBaseline = 'middle';
                            items.forEach((item) => ctx.fillText(money(item.value), item.x + 10, item.y));
                            ctx.restore();
                        },
                    };

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
                            layout: { padding: { right: isNarrow ? 12 : 80 } },
                            interaction: { mode: 'index', intersect: false },
                            plugins: {
                                legend: {
                                    position: 'top',
                                    align: 'start',
                                    labels: {
                                        usePointStyle: true,
                                        pointStyle: 'line',
                                        boxWidth: isNarrow ? 16 : 24,
                                        boxHeight: 2,
                                        color: '#52514e',
                                        font: { size: isNarrow ? 11 : 12, weight: '600' },
                                        padding: isNarrow ? 10 : 16,
                                    },
                                },
                                tooltip: {
                                    backgroundColor: '#0b0b0b',
                                    padding: 10,
                                    titleFont: { size: 12, weight: '600' },
                                    bodyFont: { size: 12 },
                                    callbacks: {
                                        label: (ctx) => ' ' + ctx.dataset.label + ':  ' + money(ctx.parsed.y, 2),
                                    },
                                },
                            },
                            scales: {
                                y: {
                                    beginAtZero: true,
                                    grid: { color: '#e1e0d9', drawTicks: false },
                                    border: { display: false },
                                    ticks: { color: '#898781', font: { size: 11 }, callback: (v) => money(v) },
                                },
                                x: {
                                    grid: { display: false },
                                    border: { color: '#c3c2b7' },
                                    ticks: { color: '#898781', font: { size: 11 } },
                                },
                            },
                        },
                        plugins: [endLabelsPlugin],
                    });
                })();
            </script>
        @endpush
    @else
        <div class="card border-0">
            <div class="card-body text-center text-muted py-5">
                <i class="bi bi-speedometer2 fs-2 d-block mb-2"></i>
                Welcome back, {{ explode(' ', auth()->user()->name)[0] }}.
            </div>
        </div>
    @endcan
@endsection
