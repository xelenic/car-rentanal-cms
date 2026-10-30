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
                    'label' => 'Total Hire Value',
                    'value' => $summary['hire_full_value_total'],
                    'delta' => $deltaDisplay($deltas['hire_full_value_total']),
                    'icon' => 'cash-coin',
                    'bg' => '#fef3e0',
                    'fg' => '#b3810a',
                ],
                [
                    'label' => 'Total Our Hire Value',
                    'value' => $summary['our_hire_value_total'],
                    'delta' => $deltaDisplay($deltas['our_hire_value_total']),
                    'icon' => 'cash-stack',
                    'bg' => '#eaf2fc',
                    'fg' => '#2a78d6',
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
                    'label' => 'Total Expenses',
                    'value' => $summary['expenses_total'],
                    'delta' => $deltaDisplay($deltas['expenses_total']),
                    'icon' => 'receipt',
                    'bg' => '#fdecec',
                    'fg' => '#c23b3b',
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

        <div class="row g-3">
        <div class="col-lg-8 col-xl-9">

        <div class="row row-cols-2 row-cols-md-3 row-cols-xl-6 g-2 mb-2">
            @foreach ($cards as $card)
                <div class="col">
                    <div class="card border-0 h-100 dashboard-card-hover {{ isset($card['modal']) ? 'profit-card-clickable' : '' }}"
                        @if (isset($card['modal'])) role="button" tabindex="0" data-bs-toggle="modal" data-bs-target="#{{ $card['modal'] }}" @endif>
                        <div class="card-body dashboard-stat-card-body">
                            <div class="d-flex align-items-center gap-2 mb-2">
                                <div class="stat-icon dashboard-stat-icon" style="background: {{ $card['bg'] }}; color: {{ $card['fg'] }};">
                                    <i class="bi bi-{{ $card['icon'] }}"></i>
                                </div>
                                <div class="text-muted dashboard-stat-label text-truncate">
                                    {{ $card['label'] }}
                                    @isset($card['modal'])
                                        <i class="bi bi-info-circle ms-1" title="Click for the full calculation"></i>
                                    @endisset
                                </div>
                            </div>
                            <div class="dashboard-stat-value fw-bold {{ $card['value'] < 0 ? 'text-danger' : '' }}">
                                {{ $card['value'] < 0 ? '-' : '' }}Rs. {{ number_format(abs($card['value']), 2) }}
                            </div>
                            <div class="d-flex align-items-center gap-1 dashboard-stat-footer">
                                <span class="dashboard-stat-delta-badge {{ $card['delta']['class'] }}">
                                    <i class="bi bi-{{ $card['delta']['icon'] }}"></i>{{ $card['delta']['label'] }}
                                </span>
                                <span class="text-muted dashboard-stat-caption">vs last month</span>
                            </div>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>

        @push('styles')
            <style>
                .profit-card-clickable { cursor: pointer; }
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
                ['label' => 'Pending Deposit', 'value' => 'Rs. ' . number_format($secondary['pending_deposit_total'], 2), 'icon' => 'hourglass-split'],
            ];
        @endphp

        <div class="row row-cols-2 row-cols-md-4 g-2 mb-3">
            @foreach ($smallCards as $card)
                <div class="col">
                    <div class="card border-0 h-100 dashboard-card-hover">
                        <div class="card-body dashboard-secondary-card-body d-flex align-items-center gap-2">
                            <div class="dashboard-secondary-icon">
                                <i class="bi bi-{{ $card['icon'] }}"></i>
                            </div>
                            <div>
                                <div class="text-muted dashboard-secondary-label">{{ $card['label'] }}</div>
                                <div class="fw-semibold dashboard-secondary-value">{{ $card['value'] }}</div>
                            </div>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>

        @php
            $expensesByCategory = collect($profitBreakdown['expenses_by_category'])
                ->filter(fn ($amount) => $amount > 0)
                ->sortDesc();
            $expensesChartRows = $expensesByCategory->map(fn ($amount, $key) => [
                'label' => \App\Models\HireExpense::CATEGORIES[$key] ?? ucfirst($key),
                'amount' => $amount,
            ])->values();
        @endphp

        <div class="row g-3 mb-3">
            <div class="col-lg-5 col-xl-4">
                <div class="card border-0 h-100">
                    <div class="card-header bg-transparent border-0 dashboard-section-header">
                        <span class="dashboard-section-icon" style="background: #eaf2fc; color: #2a78d6;"><i class="bi bi-pie-chart-fill"></i></span>
                        <span class="fw-semibold">Payment Type</span>
                        <span class="text-muted dashboard-section-period">&middot; {{ $periodLabel }}</span>
                    </div>
                    <div class="card-body d-flex align-items-center">
                        @if ($secondary['credit_hires_count'] + $secondary['cash_hires_count'] === 0)
                            <div class="text-center text-muted py-4 w-100">
                                <i class="bi bi-pie-chart fs-4 d-block mb-2"></i>
                                No hires yet this month.
                            </div>
                        @else
                            <div class="dashboard-donut-container">
                                <canvas id="dashboardPaymentTypeChart"></canvas>
                            </div>
                        @endif
                    </div>
                </div>
            </div>

            <div class="col-lg-7 col-xl-8">
                <div class="card border-0 h-100">
                    <div class="card-header bg-transparent border-0 dashboard-section-header">
                        <span class="dashboard-section-icon" style="background: #fdecec; color: #c23b3b;"><i class="bi bi-receipt"></i></span>
                        <span class="fw-semibold">Expenses by Category</span>
                        <span class="text-muted dashboard-section-period">&middot; {{ $periodLabel }}</span>
                        <span class="fw-semibold text-danger ms-auto dashboard-section-total">
                            Rs. {{ number_format($profitBreakdown['expenses_total'], 2) }}
                        </span>
                    </div>
                    <div class="card-body d-flex align-items-center">
                        @if ($expensesByCategory->isEmpty())
                            <div class="text-center text-muted py-4 w-100">
                                <i class="bi bi-receipt fs-4 d-block mb-2"></i>
                                No deductible expenses recorded this month.
                            </div>
                        @else
                            <div class="dashboard-bar-container">
                                <canvas id="dashboardExpensesChart"></canvas>
                            </div>
                        @endif
                    </div>
                </div>
            </div>
        </div>

        @push('scripts')
            <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"></script>
        @endpush

        @if ($secondary['credit_hires_count'] + $secondary['cash_hires_count'] > 0)
            @push('scripts')
                <script>
                    (function () {
                        const canvas = document.getElementById('dashboardPaymentTypeChart');
                        if (!canvas) return;

                        const cash = {{ (int) $secondary['cash_hires_count'] }};
                        const credit = {{ (int) $secondary['credit_hires_count'] }};
                        const total = cash + credit;

                        // Text stays in neutral ink even inside the center label —
                        // the two segments themselves carry the color identity.
                        const centerTextPlugin = {
                            id: 'centerText',
                            afterDraw(chart) {
                                const { ctx, chartArea } = chart;
                                const x = (chartArea.left + chartArea.right) / 2;
                                const y = (chartArea.top + chartArea.bottom) / 2;
                                ctx.save();
                                ctx.textAlign = 'center';
                                ctx.textBaseline = 'middle';
                                ctx.fillStyle = '#1e293b';
                                ctx.font = '700 20px Inter, system-ui, sans-serif';
                                ctx.fillText(String(total), x, y - 9);
                                ctx.fillStyle = '#64748b';
                                ctx.font = '600 11px Inter, system-ui, sans-serif';
                                ctx.fillText(total === 1 ? 'hire' : 'hires', x, y + 10);
                                ctx.restore();
                            },
                        };

                        new Chart(canvas, {
                            type: 'doughnut',
                            data: {
                                labels: ['Cash', 'Credit'],
                                datasets: [{
                                    data: [cash, credit],
                                    backgroundColor: ['#2a78d6', '#c95a26'],
                                    borderColor: '#fff',
                                    borderWidth: 2,
                                    hoverOffset: 4,
                                }],
                            },
                            options: {
                                responsive: true,
                                maintainAspectRatio: false,
                                cutout: '72%',
                                plugins: {
                                    legend: {
                                        position: 'bottom',
                                        labels: {
                                            usePointStyle: true,
                                            pointStyle: 'circle',
                                            boxWidth: 8,
                                            boxHeight: 8,
                                            color: '#52514e',
                                            font: { size: 11, weight: '600' },
                                            padding: 12,
                                        },
                                    },
                                    tooltip: {
                                        backgroundColor: '#0b0b0b',
                                        padding: 10,
                                        titleFont: { size: 12, weight: '600' },
                                        bodyFont: { size: 12 },
                                        callbacks: {
                                            label: (ctx) => {
                                                const pct = total > 0 ? Math.round((ctx.parsed / total) * 100) : 0;
                                                return ` ${ctx.label}: ${ctx.parsed} (${pct}%)`;
                                            },
                                        },
                                    },
                                },
                            },
                            plugins: [centerTextPlugin],
                        });
                    })();
                </script>
            @endpush
        @endif

        @if ($expensesByCategory->isNotEmpty())
            @push('scripts')
                <script>
                    (function () {
                        const canvas = document.getElementById('dashboardExpensesChart');
                        if (!canvas) return;

                        const rows = @json($expensesChartRows);

                        const money = (value) => 'Rs. ' + Number(value).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

                        // One series, one color — these bars rank categories by
                        // magnitude, they don't carry separate identities, so a
                        // categorical palette would be noise rather than signal.
                        const valueLabelsPlugin = {
                            id: 'valueLabels',
                            afterDatasetsDraw(chart) {
                                const { ctx } = chart;
                                const meta = chart.getDatasetMeta(0);
                                ctx.save();
                                ctx.font = '600 11px Inter, system-ui, sans-serif';
                                ctx.fillStyle = '#52514e';
                                ctx.textBaseline = 'middle';
                                meta.data.forEach((bar, i) => {
                                    ctx.textAlign = 'left';
                                    ctx.fillText(money(rows[i].amount), bar.x + 8, bar.y);
                                });
                                ctx.restore();
                            },
                        };

                        new Chart(canvas, {
                            type: 'bar',
                            data: {
                                labels: rows.map((r) => r.label),
                                datasets: [{
                                    data: rows.map((r) => r.amount),
                                    backgroundColor: '#c23b3b',
                                    borderRadius: 4,
                                    barThickness: 16,
                                }],
                            },
                            options: {
                                indexAxis: 'y',
                                responsive: true,
                                maintainAspectRatio: false,
                                layout: { padding: { right: 90 } },
                                plugins: {
                                    legend: { display: false },
                                    tooltip: {
                                        backgroundColor: '#0b0b0b',
                                        padding: 10,
                                        titleFont: { size: 12, weight: '600' },
                                        bodyFont: { size: 12 },
                                        callbacks: {
                                            label: (ctx) => ' ' + money(ctx.parsed.x),
                                        },
                                    },
                                },
                                scales: {
                                    x: {
                                        beginAtZero: true,
                                        grid: { color: '#e1e0d9', drawTicks: false },
                                        border: { display: false },
                                        ticks: { display: false },
                                    },
                                    y: {
                                        grid: { display: false },
                                        border: { display: false },
                                        ticks: { color: '#52514e', font: { size: 11, weight: '600' } },
                                    },
                                },
                            },
                            plugins: [valueLabelsPlugin],
                        });
                    })();
                </script>
            @endpush
        @endif

        @can('vehicles.view')
            @php
                $vehicleMetricList = fn ($vc) => [
                    ['label' => 'Hire Value', 'value' => $vc['hire_full_value_total'], 'icon' => 'cash-coin'],
                    ['label' => 'Our Hire Value', 'value' => $vc['our_hire_value_total'], 'icon' => 'cash-stack'],
                    ['label' => 'Commission', 'value' => $vc['commission_total'], 'icon' => 'piggy-bank'],
                    ['label' => 'Expenses', 'value' => $vc['expenses_total'], 'icon' => 'receipt'],
                    ['label' => 'Salary', 'value' => $vc['salary_total'], 'icon' => 'wallet2'],
                    ['label' => 'Profit', 'value' => $vc['profit_total'], 'icon' => 'graph-up-arrow'],
                ];
            @endphp

            <div class="dashboard-section-header mb-2">
                <span class="dashboard-section-icon" style="background: #fdeee7; color: #c95a26;"><i class="bi bi-car-front-fill"></i></span>
                <span class="fw-semibold">Vehicle Cards</span>
                <span class="text-muted dashboard-section-period">&middot; {{ $periodLabel }}</span>
            </div>

            @if (count($vehicleCards) === 0)
                <div class="card border-0 mb-2">
                    <div class="card-body text-center text-muted py-5">
                        <i class="bi bi-car-front fs-3 d-block mb-2"></i>
                        No vehicles yet — add one to see its numbers here.
                    </div>
                </div>
            @else
                <div class="row row-cols-1 row-cols-md-2 g-2 mb-2">
                    @foreach ($vehicleCards as $vc)
                        <div class="col">
                            <div class="card border-0 h-100 dashboard-card-hover" style="border-left: 4px solid {{ $vc['vehicle']->display_color }}; background: {{ $vc['vehicle']->display_color }}33;">
                                <div class="card-header border-0 pb-0 d-flex align-items-center justify-content-between" style="background: transparent;">
                                    <span class="fw-semibold d-flex align-items-center gap-2">
                                        <span class="dashboard-vehicle-dot" style="background: {{ $vc['vehicle']->display_color }};"></span>
                                        {{ $vc['vehicle']->model }}
                                    </span>
                                    <span class="badge text-bg-light border">{{ $vc['vehicle']->condition }}</span>
                                </div>
                                <div class="card-body pt-2">
                                    <div class="row row-cols-2 row-cols-sm-3 g-2">
                                        @foreach ($vehicleMetricList($vc) as $metric)
                                            <div class="col">
                                                <div class="d-flex align-items-start gap-1">
                                                    <i class="bi bi-{{ $metric['icon'] }} text-muted dashboard-vehicle-metric-icon"></i>
                                                    <div>
                                                        <div class="text-muted" style="font-size: .65rem;">{{ $metric['label'] }}</div>
                                                        <div class="fw-semibold {{ $metric['value'] < 0 ? 'text-danger' : '' }}" style="font-size: .8rem;">
                                                            {{ $metric['value'] < 0 ? '-' : '' }}Rs. {{ number_format(abs($metric['value']), 2) }}
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        @endforeach
                                    </div>
                                </div>
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif

            @push('styles')
                <style>
                    .dashboard-vehicle-metric-icon { font-size: .8rem; margin-top: 2px; }
                    .dashboard-vehicle-dot { width: 9px; height: 9px; border-radius: 50%; display: inline-block; flex-shrink: 0; }
                </style>
            @endpush
        @endcan

        <div class="card border-0">
            <div class="card-header dashboard-section-header">
                <span class="dashboard-section-icon" style="background: #fdeef4; color: #c2477a;"><i class="bi bi-graph-up-arrow"></i></span>
                <span class="fw-semibold">Trend</span>
                <span class="text-muted dashboard-section-period">&middot; Last {{ $trend->count() }} Months</span>
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

        </div>

        <div class="col-lg-4 col-xl-3">
            <div class="card border-0 h-100">
                <div class="card-header bg-transparent border-0 dashboard-section-header">
                    <span class="dashboard-section-icon" style="background: #e6f7f1; color: #158f66;"><i class="bi bi-piggy-bank-fill"></i></span>
                    <span class="fw-semibold">Driver Deposits</span>
                    <span class="text-muted dashboard-section-period ms-auto">{{ $periodLabel }}</span>
                </div>
                <div class="card-body pt-0">
                    @if (count($driverDeposits) === 0)
                        <div class="text-center text-muted py-4">
                            <i class="bi bi-piggy-bank fs-3 d-block mb-2"></i>
                            No drivers yet.
                        </div>
                    @else
                        <div class="d-flex flex-column gap-1">
                            @foreach ($driverDeposits as $entry)
                                <a href="{{ route('admin.drivers.show', $entry['driver']) }}"
                                    class="d-flex align-items-center justify-content-between text-decoration-none dashboard-deposit-row">
                                    <span class="text-truncate pe-2 dashboard-deposit-name">{{ $entry['driver']->name }}</span>
                                    <span class="fw-semibold text-nowrap dashboard-deposit-amount {{ $entry['amount'] <= 0 ? 'text-muted' : 'text-success' }}">
                                        Rs. {{ number_format($entry['amount'], 2) }}
                                    </span>
                                </a>
                            @endforeach
                        </div>

                        <div class="d-flex align-items-center justify-content-between border-top pt-2 mt-2">
                            <span class="fw-semibold dashboard-deposit-name">Total Deposited</span>
                            <span class="fw-bold text-success dashboard-deposit-total">
                                Rs. {{ number_format(collect($driverDeposits)->sum('amount'), 2) }}
                            </span>
                        </div>
                    @endif
                </div>
            </div>
        </div>

        </div>

        @push('styles')
            <style>
                /* Section headers — a small colored icon chip beside the
                   title, the same visual language across every section
                   card on this page, instead of plain bold text. */
                .dashboard-section-header { display: flex; align-items: center; gap: .55rem; }
                .dashboard-section-icon {
                    width: 26px; height: 26px; border-radius: 8px; display: inline-flex;
                    align-items: center; justify-content: center; font-size: .78rem; flex-shrink: 0;
                }
                .dashboard-section-period { font-size: .72rem; }
                .dashboard-section-total { font-size: .85rem; }

                /* A gentle lift on hover for every stat/secondary card —
                   not just the profit-breakdown one — so the page reads
                   as interactive rather than static tiles. */
                .dashboard-card-hover { transition: box-shadow .15s ease, transform .15s ease; }
                .dashboard-card-hover:hover { box-shadow: 0 4px 14px rgba(0,0,0,.07); transform: translateY(-1px); }

                .dashboard-secondary-card-body { padding: .65rem .85rem; }
                .dashboard-secondary-icon {
                    width: 30px; height: 30px; border-radius: 8px; display: inline-flex; flex-shrink: 0;
                    align-items: center; justify-content: center; background: var(--primary-light); color: var(--primary);
                    font-size: .85rem;
                }
                .dashboard-secondary-label { font-size: .68rem; }
                .dashboard-secondary-value { font-size: .85rem; }

                .dashboard-donut-container { position: relative; height: 180px; width: 100%; }
                .dashboard-bar-container { position: relative; height: 180px; width: 100%; }

                .dashboard-deposit-row { color: inherit; padding: .35rem .5rem; border-radius: 8px; transition: background .15s ease; }
                .dashboard-deposit-row:hover { background: #f4f3ef; }
                .dashboard-deposit-name { font-size: .8rem; }
                .dashboard-deposit-amount { font-size: .8rem; }
                .dashboard-deposit-total { font-size: .9rem; }

                /* Tighter, more deliberate type scale for the main summary
                   cards — one clean line each for label, value and the
                   change-badge, instead of several same-weight numbers
                   competing for attention. */
                .dashboard-stat-card-body { padding: .8rem .9rem; }
                .dashboard-stat-icon { width: 24px; height: 24px; font-size: .68rem; }
                .dashboard-stat-label { font-size: .66rem; font-weight: 600; letter-spacing: .01em; }
                .dashboard-stat-value { font-size: .95rem; margin-bottom: .3rem; }
                .dashboard-stat-footer { min-height: 1.1rem; }
                .dashboard-stat-delta-badge {
                    display: inline-flex; align-items: center; gap: 2px;
                    font-size: .62rem; font-weight: 700; line-height: 1;
                    padding: .15rem .4rem; border-radius: 999px; white-space: nowrap;
                }
                .dashboard-stat-delta-badge.text-success { background: #e6f7f1; color: #158f66 !important; }
                .dashboard-stat-delta-badge.text-danger { background: #fdecec; color: #c23b3b !important; }
                .dashboard-stat-delta-badge.text-secondary,
                .dashboard-stat-delta-badge.text-muted { background: #f1f1ee; color: #6b6a66 !important; }
                .dashboard-stat-caption { font-size: .62rem; }

                @media (max-width: 767.98px) {
                    .dashboard-stat-card-body { padding: .6rem .7rem; }
                    .dashboard-stat-icon { width: 22px; height: 22px; font-size: .62rem; }
                    .dashboard-stat-value { font-size: .85rem; }
                    .dashboard-secondary-card-body.card-body { padding: .5rem .65rem; }
                }
            </style>
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
