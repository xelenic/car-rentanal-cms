@extends('layouts.admin')

@section('title', $vehicle->model)
@section('subtitle', 'Vehicle history, revenue, and maintenance.')

@section('actions')
    <a href="{{ route('admin.vehicles.index') }}" class="btn btn-light border">
        <i class="bi bi-arrow-left me-1"></i> Back to Vehicles
    </a>
@endsection

@section('content')
    <div class="card border-0 mb-2">
        <div class="card-body d-flex flex-wrap align-items-center gap-3">
            <div class="stat-icon" style="width: 48px; height: 48px; font-size: 1.2rem; background: #eef2ff; color: #4f46e5;">
                <i class="bi bi-car-front"></i>
            </div>
            <div class="flex-grow-1">
                <div class="d-flex align-items-center gap-2">
                    <span class="fs-5 fw-bold">{{ $vehicle->model }}</span>
                    @php
                        $conditionColor = match ($vehicle->condition) {
                            'New' => 'success',
                            'Excellent' => 'primary',
                            'Good' => 'info',
                            'Fair' => 'warning',
                            default => 'danger',
                        };
                    @endphp
                    <span class="badge rounded-pill bg-{{ $conditionColor }}-subtle text-{{ $conditionColor }}-emphasis">{{ $vehicle->condition }}</span>
                </div>
                <div class="text-muted" style="font-size: .8rem;">
                    {{ $vehicle->seats }} seats &middot; {{ $vehicle->pax }} PAX
                    @if ($vehicle->description)
                        &middot; {{ $vehicle->description }}
                    @endif
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
                        <i class="bi bi-piggy-bank"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Net Revenue (all time)</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['net_revenue'], 2) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">after Rs. {{ number_format($summary['maintenance_total'], 2) }} maintenance</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card border-0 mb-2">
        <div class="card-header fw-semibold" style="font-size: .85rem;">Revenue Trend &middot; last {{ $trend->count() }} months</div>
        <div class="card-body">
            <div class="vehicle-trend-chart-container">
                <canvas id="vehicleTrendChart"></canvas>
            </div>
        </div>
    </div>

    <div class="card border-0 mb-2">
        <div class="card-header fw-semibold" style="font-size: .85rem;">Recent Hires @if ($summary['hire_count'] > $hires->count()) <span class="text-muted fw-normal">(latest {{ $hires->count() }} of {{ $summary['hire_count'] }})</span> @endif</div>
        <div class="table-responsive">
            <table class="table align-middle mb-0">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Customer</th>
                        <th>Driver</th>
                        <th>Type</th>
                        <th>Full Value</th>
                        <th>Commission</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($hires as $hire)
                        <tr>
                            <td class="text-muted" style="font-size: .8rem;">{{ $hire->effective_month_date?->format('M j, Y') ?? '—' }}</td>
                            <td style="font-size: .8rem;">{{ $hire->customer->name ?? '—' }}</td>
                            <td class="text-muted" style="font-size: .8rem;">{{ $hire->driver->name ?? '—' }}</td>
                            <td><span class="badge rounded-pill bg-primary-subtle text-primary-emphasis">{{ \App\Models\Hire::TOUR_TYPES[$hire->tour_type] ?? $hire->tour_type }}</span></td>
                            <td class="text-muted" style="font-size: .8rem;">Rs. {{ number_format($hire->hire_full_value, 2) }}</td>
                            <td class="fw-semibold" style="color: #1baf7a; font-size: .8rem;">Rs. {{ number_format($hire->commission, 2) }}</td>
                            <td><span class="badge rounded-pill bg-light text-dark border">{{ $hire->status_label }}</span></td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="7" class="text-center text-muted py-4">No hires recorded for this vehicle yet.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    <div class="card border-0 mb-2">
        <div class="card-header fw-semibold" style="font-size: .85rem;">Maintenance History</div>
        <div class="table-responsive">
            <table class="table align-middle mb-0">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Type</th>
                        <th>Driver</th>
                        <th>Mileage</th>
                        <th>Cost</th>
                        <th>Bill</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($maintenanceRecords as $record)
                        <tr>
                            <td class="text-muted" style="font-size: .8rem;">{{ $record->created_at->format('M j, Y') }}</td>
                            <td>{{ $record->type_label }}</td>
                            <td class="text-muted" style="font-size: .8rem;">{{ $record->driver->name ?? '—' }}</td>
                            <td class="text-muted" style="font-size: .8rem;">{{ $record->mileage ? number_format($record->mileage).' km' : '—' }}</td>
                            <td class="text-muted" style="font-size: .8rem;">Rs. {{ number_format($record->cost, 2) }}</td>
                            <td>
                                @if ($record->bill_url)
                                    <a href="{{ $record->bill_url }}" target="_blank" rel="noopener" class="btn btn-link btn-sm p-0" style="font-size: .75rem;">
                                        <i class="bi bi-receipt me-1"></i>View
                                    </a>
                                @else
                                    <span class="text-muted">—</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="text-center text-muted py-4">No maintenance recorded for this vehicle yet.</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    @if ($leasings->isNotEmpty())
        <div class="card border-0">
            <div class="card-header fw-semibold" style="font-size: .85rem;">Leasing &amp; Loans</div>
            <div class="card-body d-flex flex-column gap-3">
                @foreach ($leasings as $leasing)
                    <div class="border rounded p-3">
                        <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-2">
                            <div class="fw-semibold" style="font-size: .85rem;">{{ $leasing->company }} &middot; {{ $leasing->type_label }}</div>
                            @php
                                $statusColor = match ($leasing->status) {
                                    'active' => 'success',
                                    'completed' => 'secondary',
                                    default => 'danger',
                                };
                            @endphp
                            <span class="badge rounded-pill bg-{{ $statusColor }}-subtle text-{{ $statusColor }}-emphasis">{{ $leasing->status_label }}</span>
                        </div>
                        <div class="row row-cols-2 row-cols-md-4 g-2 mb-2">
                            <div class="col">
                                <div class="text-muted" style="font-size: .7rem;">Loan Amount</div>
                                <div class="fw-semibold" style="font-size: .82rem;">Rs. {{ number_format($leasing->loan_amount, 2) }}</div>
                            </div>
                            <div class="col">
                                <div class="text-muted" style="font-size: .7rem;">Balance Remaining</div>
                                <div class="fw-semibold" style="font-size: .82rem;">Rs. {{ number_format($leasing->balance_remaining, 2) }}</div>
                            </div>
                            <div class="col">
                                <div class="text-muted" style="font-size: .7rem;">Monthly Installment</div>
                                <div class="fw-semibold" style="font-size: .82rem;">Rs. {{ number_format($leasing->monthly_installment, 2) }}</div>
                            </div>
                            <div class="col">
                                <div class="text-muted" style="font-size: .7rem;">Settlements Made</div>
                                <div class="fw-semibold" style="font-size: .82rem;">{{ $leasing->settlements->count() }}</div>
                            </div>
                        </div>
                        <div class="progress" style="height: 6px;">
                            <div class="progress-bar bg-success" role="progressbar" style="width: {{ $leasing->progress_percent }}%;"></div>
                        </div>
                        <div class="text-muted mt-1" style="font-size: .7rem;">{{ $leasing->progress_percent }}% paid off</div>
                    </div>
                @endforeach
            </div>
        </div>
    @endif
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
            const canvas = document.getElementById('vehicleTrendChart');
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
