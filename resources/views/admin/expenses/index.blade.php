@extends('layouts.admin')

@section('title', 'Expenses')
@section('subtitle', 'Fuel, foods, room, parking and highway costs — driver-wise, hire-wise, and logged without a hire.')

@section('content')
    <div class="row row-cols-1 row-cols-md-3 g-2 mb-2">
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdeee7; color: #c95a26;">
                        <i class="bi bi-receipt"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Expenses</div>
                        <div class="fs-5 fw-bold">${{ number_format($totalExpenses, 2) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">{{ number_format($recordCount) }} record{{ $recordCount === 1 ? '' : 's' }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #eaf2fc; color: #2a78d6;">
                        <i class="bi bi-journal-check"></i>
                    </div>
                    <div>
                        <div class="text-muted small">With Hire</div>
                        <div class="fs-5 fw-bold">${{ number_format($withHireTotal, 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdeee4; color: #b5551a;">
                        <i class="bi bi-person-badge"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Without Hire</div>
                        <div class="fs-5 fw-bold">${{ number_format($withoutHireTotal, 2) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">Logged directly by driver</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card border-0 mb-2">
        <div class="card-header">
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                <div class="position-relative" style="max-width: 220px; flex: 1 1 180px;">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search driver...">
                </div>

                <select name="driver_id" class="form-select" style="max-width: 170px;" onchange="this.form.submit()">
                    <option value="">All Drivers</option>
                    @foreach ($drivers as $driver)
                        <option value="{{ $driver->id }}" {{ (string) $selectedDriverId === (string) $driver->id ? 'selected' : '' }}>{{ $driver->name }}</option>
                    @endforeach
                </select>

                <select name="category" class="form-select" style="max-width: 160px;" onchange="this.form.submit()">
                    <option value="">All Categories</option>
                    @foreach ($categories as $key => $label)
                        <option value="{{ $key }}" {{ $selectedCategory === $key ? 'selected' : '' }}>{{ $label }}</option>
                    @endforeach
                </select>

                <select name="attribution" class="form-select" style="max-width: 160px;" onchange="this.form.submit()">
                    <option value="">With & Without Hire</option>
                    <option value="with_hire" {{ $selectedAttribution === 'with_hire' ? 'selected' : '' }}>With Hire Only</option>
                    <option value="without_hire" {{ $selectedAttribution === 'without_hire' ? 'selected' : '' }}>Without Hire Only</option>
                </select>

                <select name="year" class="form-select" style="max-width: 110px;" onchange="this.form.submit()">
                    <option value="">All Years</option>
                    @foreach ($availableYears as $year)
                        <option value="{{ $year }}" {{ (string) $selectedYear === (string) $year ? 'selected' : '' }}>{{ $year }}</option>
                    @endforeach
                </select>

                <select name="month" class="form-select" style="max-width: 140px;" onchange="this.form.submit()">
                    <option value="">All Months</option>
                    @foreach ($monthsByYear[$selectedYear] ?? [] as $month)
                        <option value="{{ $month }}" {{ (string) $selectedMonth === (string) $month ? 'selected' : '' }}>{{ \Carbon\Carbon::create()->month($month)->format('F') }}</option>
                    @endforeach
                </select>

                @if ($selectedDriverId || $selectedCategory || $selectedAttribution || $selectedYear || $selectedMonth || $search)
                    <a href="{{ route('admin.expenses.index') }}" class="btn btn-light border">Clear</a>
                @endif
            </form>
        </div>
    </div>

    <div class="card border-0 mb-2">
        <div class="card-header">
            <span class="fw-semibold">Trend &middot; Last 6 Months</span>
        </div>
        <div class="card-body">
            @if (collect($trend)->sum('with_hire') + collect($trend)->sum('without_hire') == 0)
                <div class="text-center text-muted py-5">
                    <i class="bi bi-graph-up fs-3 d-block mb-2"></i>
                    No expenses recorded yet — the trend will fill in once there's data to chart.
                </div>
            @else
                <div style="position: relative; height: 300px;">
                    <canvas id="expenseTrendChart"></canvas>
                </div>
            @endif
        </div>
    </div>

    @if ($byCategory->isNotEmpty())
        <div class="row row-cols-2 row-cols-md-3 row-cols-xl-5 g-2 mb-2">
            @foreach ($byCategory as $category => $amount)
                <div class="col">
                    <div class="card border-0">
                        <div class="card-body py-2 px-3">
                            <div class="text-muted" style="font-size: .68rem;">{{ $categories[$category] ?? $category }}</div>
                            <div class="fw-semibold" style="font-size: .85rem;">${{ number_format($amount, 2) }}</div>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>
    @endif

    <div class="row g-2">
        <div class="col-lg-6">
            <div class="card border-0 h-100">
                <div class="card-header">
                    <span class="fw-semibold">By Driver</span>
                </div>
                <div class="table-responsive">
                    <table class="table align-middle mb-0">
                        <thead>
                            <tr>
                                <th>Driver</th>
                                <th>Records</th>
                                <th>Without Hire</th>
                                <th>Total</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($byDriver as $row)
                                <tr>
                                    <td>
                                        <div class="d-flex align-items-center gap-2">
                                            <x-avatar :name="$row['driver']->name" :size="26" />
                                            <span class="fw-semibold" style="font-size: .8rem;">{{ $row['driver']->name }}</span>
                                        </div>
                                    </td>
                                    <td class="text-muted">{{ $row['count'] }}</td>
                                    <td class="text-muted">
                                        @if ($row['without_hire_total'] > 0)
                                            ${{ number_format($row['without_hire_total'], 2) }}
                                        @else
                                            &mdash;
                                        @endif
                                    </td>
                                    <td class="fw-semibold" style="font-size: .82rem;">${{ number_format($row['total'], 2) }}</td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="4" class="text-center text-muted py-4">No expenses found.</td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div class="col-lg-6">
            <div class="card border-0 h-100">
                <div class="card-header">
                    <span class="fw-semibold">By Hire</span>
                </div>
                <div class="table-responsive" style="max-height: 420px; overflow-y: auto;">
                    <table class="table align-middle mb-0">
                        <thead>
                            <tr>
                                <th>Hire</th>
                                <th>Driver</th>
                                <th>Records</th>
                                <th>Total</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($byHire as $row)
                                <tr>
                                    <td>
                                        <div class="fw-semibold" style="font-size: .8rem;">#{{ $row['hire']->id }}</div>
                                        <div class="text-muted" style="font-size: .72rem;">{{ \App\Models\Hire::TOUR_TYPES[$row['hire']->tour_type] ?? $row['hire']->tour_type }} &middot; {{ $row['hire']->created_at->format('M j, Y') }}</div>
                                    </td>
                                    <td class="text-muted" style="font-size: .8rem;">{{ $row['driver']->name ?? '—' }}</td>
                                    <td class="text-muted">{{ $row['count'] }}</td>
                                    <td class="fw-semibold" style="font-size: .82rem;">${{ number_format($row['total'], 2) }}</td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="4" class="text-center text-muted py-4">No hire-tied expenses found.</td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <div class="card border-0 mt-2">
        <div class="card-header d-flex align-items-center justify-content-between">
            <span class="fw-semibold">Without Hire</span>
            <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis">Logged directly from the Options page, not tied to a hire</span>
        </div>
        <div class="table-responsive">
            <table class="table align-middle mb-0">
                <thead>
                    <tr>
                        <th>Driver</th>
                        <th>Category</th>
                        <th>Amount</th>
                        <th>Date</th>
                        <th class="text-end">Bill</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($withoutHireExpenses as $expense)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <x-avatar :name="$expense->driver->name ?? '—'" :size="26" />
                                    <span class="fw-semibold" style="font-size: .8rem;">{{ $expense->driver->name ?? '—' }}</span>
                                </div>
                            </td>
                            <td>
                                <span class="badge rounded-pill bg-secondary-subtle text-secondary-emphasis">{{ $categories[$expense->category] ?? $expense->category }}</span>
                            </td>
                            <td class="fw-semibold" style="font-size: .82rem;">${{ number_format($expense->amount, 2) }}</td>
                            <td class="text-muted" style="font-size: .8rem;">{{ $expense->created_at->format('M j, Y') }}</td>
                            <td class="text-end">
                                @if ($expense->receipt_url)
                                    <a href="{{ $expense->receipt_url }}" target="_blank" class="btn btn-sm btn-light border btn-icon" title="View Receipt">
                                        <i class="bi bi-receipt"></i>
                                    </a>
                                @else
                                    &mdash;
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="text-center text-muted py-4">
                                <i class="bi bi-person-badge fs-4 d-block mb-1"></i>
                                No expenses logged without a hire yet.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    @push('scripts')
        <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"></script>
        <script>
            (function () {
                const canvas = document.getElementById('expenseTrendChart');
                if (!canvas) return;

                const trend = @json($trend);

                const series = [
                    { key: 'with_hire', label: 'With Hire', color: '#2a78d6' },
                    { key: 'without_hire', label: 'Without Hire', color: '#eb6834' },
                ];

                const money = (value, decimals = 0) => '$' + Number(value).toLocaleString(undefined, {
                    minimumFractionDigits: decimals,
                    maximumFractionDigits: decimals,
                });

                // Direct end-of-line labels in neutral ink — the line itself
                // (right beside the label) carries identity, matching the
                // dashboard's trend chart.
                const endLabelsPlugin = {
                    id: 'endLabels',
                    afterDatasetsDraw(chart) {
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
                        layout: { padding: { right: 70 } },
                        interaction: { mode: 'index', intersect: false },
                        plugins: {
                            legend: {
                                position: 'top',
                                align: 'start',
                                labels: {
                                    usePointStyle: true,
                                    pointStyle: 'line',
                                    boxWidth: 24,
                                    boxHeight: 2,
                                    color: '#52514e',
                                    font: { size: 12, weight: '600' },
                                    padding: 16,
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
@endsection
