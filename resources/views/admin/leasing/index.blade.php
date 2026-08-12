@extends('layouts.admin')

@section('title', 'Leasing')
@section('subtitle', 'Vehicle financing — leasing facilities and loans, per vehicle.')

@section('actions')
    @can('vehicles.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Leasing Record
        </button>
    @endcan
@endsection

@section('content')
    <div class="row row-cols-1 row-cols-md-2 row-cols-xl-4 g-2 mb-2">
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #eaf2fc; color: #2a78d6;">
                        <i class="bi bi-file-earmark-text"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Active Records</div>
                        <div class="fs-5 fw-bold">{{ number_format($summary['active_count']) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdeee7; color: #c95a26;">
                        <i class="bi bi-cash-stack"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Loan Amount</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['loan_amount_total'], 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #e6f7f1; color: #158f66;">
                        <i class="bi bi-calendar-check"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Monthly Installments</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['monthly_installment_total'], 2) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">Active records only</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fef3e0; color: #b3810a;">
                        <i class="bi bi-hourglass-split"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Balance Remaining</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($summary['balance_remaining_total'], 2) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">Active records only</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card border-0">
        <div class="card-header">
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                <div class="position-relative" style="max-width: 220px; flex: 1 1 180px;">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search company, agreement, vehicle...">
                </div>

                <select name="vehicle_id" class="form-select" style="max-width: 170px;" onchange="this.form.submit()">
                    <option value="">All Vehicles</option>
                    @foreach ($vehicles as $vehicle)
                        <option value="{{ $vehicle->id }}" {{ (string) $selectedVehicleId === (string) $vehicle->id ? 'selected' : '' }}>{{ $vehicle->model }}</option>
                    @endforeach
                </select>

                <select name="type" class="form-select" style="max-width: 150px;" onchange="this.form.submit()">
                    <option value="">All Types</option>
                    @foreach ($types as $key => $label)
                        <option value="{{ $key }}" {{ $selectedType === $key ? 'selected' : '' }}>{{ $label }}</option>
                    @endforeach
                </select>

                <select name="status" class="form-select" style="max-width: 150px;" onchange="this.form.submit()">
                    <option value="">All Statuses</option>
                    @foreach ($statuses as $key => $label)
                        <option value="{{ $key }}" {{ $selectedStatus === $key ? 'selected' : '' }}>{{ $label }}</option>
                    @endforeach
                </select>

                @if ($selectedVehicleId || $selectedType || $selectedStatus || $search)
                    <a href="{{ route('admin.leasing.index') }}" class="btn btn-light border">Clear</a>
                @endif
            </form>
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Vehicle</th>
                        <th>Type</th>
                        <th>Company</th>
                        <th>Loan Amount</th>
                        <th>Installment</th>
                        <th>Balance</th>
                        <th>Term</th>
                        <th>Status</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($leasings as $leasing)
                        @php
                            $typeColor = $leasing->type === 'loan' ? 'info' : 'primary';
                            $statusColor = match ($leasing->status) {
                                'active' => 'success',
                                'completed' => 'secondary',
                                default => 'danger',
                            };
                        @endphp
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #eef2ff; color: #4f46e5;">
                                        <i class="bi bi-car-front"></i>
                                    </div>
                                    <span class="fw-semibold" style="font-size: .8rem;">{{ $leasing->vehicle->model ?? '—' }}</span>
                                </div>
                            </td>
                            <td>
                                <span class="badge rounded-pill bg-{{ $typeColor }}-subtle text-{{ $typeColor }}-emphasis">{{ $leasing->type_label }}</span>
                            </td>
                            <td>
                                <div class="fw-semibold" style="font-size: .8rem;">{{ $leasing->company }}</div>
                                @if ($leasing->agreement_number)
                                    <div class="text-muted" style="font-size: .72rem;">{{ $leasing->agreement_number }}</div>
                                @endif
                            </td>
                            <td class="text-muted">Rs. {{ number_format($leasing->loan_amount, 2) }}</td>
                            <td class="text-muted">Rs. {{ number_format($leasing->monthly_installment, 2) }}</td>
                            <td>
                                <div class="fw-semibold" style="font-size: .82rem;">Rs. {{ number_format($leasing->balance_remaining, 2) }}</div>
                                <div class="progress" style="height: 4px; width: 90px;">
                                    <div class="progress-bar bg-{{ $statusColor }}" style="width: {{ $leasing->progress_percent }}%"></div>
                                </div>
                                <div class="text-muted" style="font-size: .68rem;">{{ $leasing->progress_percent }}% paid</div>
                                <button type="button" class="btn btn-link btn-sm p-0" style="font-size: .72rem;" data-bs-toggle="modal" data-bs-target="#modal-settlements-{{ $leasing->id }}">
                                    <i class="bi bi-calendar2-check me-1"></i>Settlements
                                    @if ($leasing->settlements->isNotEmpty())
                                        ({{ $leasing->settlements->count() }})
                                    @endif
                                </button>
                            </td>
                            <td class="text-muted" style="font-size: .78rem;">
                                {{ $leasing->start_date->format('M j, Y') }}
                                @if ($leasing->end_date)
                                    <div>to {{ $leasing->end_date->format('M j, Y') }}</div>
                                @elseif ($leasing->term_months)
                                    <div>{{ $leasing->term_months }} months</div>
                                @endif
                            </td>
                            <td>
                                <span class="badge rounded-pill bg-{{ $statusColor }}-subtle text-{{ $statusColor }}-emphasis">{{ $leasing->status_label }}</span>
                            </td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('vehicles.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $leasing->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('vehicles.delete')
                                        <form method="POST" action="{{ route('admin.leasing.destroy', $leasing) }}" onsubmit="return confirm('Delete this leasing record?');">
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
                            <td colspan="9" class="text-center text-muted py-4">
                                <i class="bi bi-file-earmark-text fs-4 d-block mb-1"></i>
                                No leasing records found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($leasings->hasPages())
            <div class="card-footer bg-white">
                {{ $leasings->links() }}
            </div>
        @endif
    </div>

    @can('vehicles.create')
        <x-modal id="modal-create" title="New Leasing Record" size="lg">
            <form id="form-create-leasing" method="POST" action="{{ route('admin.leasing.store') }}">
                @csrf
                @include('admin.leasing._form', ['leasing' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-leasing" class="btn btn-primary">Create Record</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @foreach ($leasings as $leasing)
        @php
            $settlementYears = range($leasing->start_date->year, max($leasing->start_date->year + 6, now()->year + 1));
            $totalSettled = round((float) $leasing->settlements->sum('amount'), 2);
        @endphp
        <x-modal id="modal-settlements-{{ $leasing->id }}" title="Settlements — {{ $leasing->vehicle->model ?? '' }} ({{ $leasing->company }})" size="lg">
            @can('vehicles.update')
                <form method="POST" action="{{ route('admin.leasing.settlements.store', $leasing) }}" class="border rounded-3 p-2 mb-3">
                    @csrf
                    <div class="fw-semibold mb-2" style="font-size: .8rem;">Record a Settlement</div>
                    <div class="row g-2">
                        <div class="col-4">
                            <label class="form-label">Year</label>
                            <select name="year" class="form-select form-select-sm" required>
                                @foreach ($settlementYears as $year)
                                    <option value="{{ $year }}" {{ $year === now()->year ? 'selected' : '' }}>{{ $year }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div class="col-4">
                            <label class="form-label">Month</label>
                            <select name="month" class="form-select form-select-sm" required>
                                @foreach (range(1, 12) as $month)
                                    <option value="{{ $month }}" {{ $month === now()->month ? 'selected' : '' }}>{{ \Carbon\Carbon::create()->month($month)->format('F') }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div class="col-4">
                            <label class="form-label">Amount</label>
                            <input type="number" min="0.01" step="0.01" name="amount" class="form-control form-control-sm" placeholder="e.g. 85000.00" required>
                        </div>
                        <div class="col-12">
                            <label class="form-label">Notes</label>
                            <input type="text" name="notes" class="form-control form-control-sm" placeholder="Optional">
                        </div>
                    </div>
                    <div class="text-end mt-2">
                        <button type="submit" class="btn btn-sm btn-primary">
                            <i class="bi bi-plus-lg me-1"></i> Add Settlement
                        </button>
                    </div>
                </form>
            @endcan

            <div class="d-flex align-items-center justify-content-between border-bottom pb-2 mb-2">
                <span class="text-muted small">{{ $leasing->settlements->count() }} settlement{{ $leasing->settlements->count() === 1 ? '' : 's' }}</span>
                <span class="fw-semibold">Total Settled: Rs. {{ number_format($totalSettled, 2) }}</span>
            </div>

            @if ($leasing->settlements->isEmpty())
                <div class="text-center text-muted py-4">
                    <i class="bi bi-calendar2-check fs-3 d-block mb-2"></i>
                    No settlements recorded yet.
                </div>
            @else
                <div class="table-responsive">
                    <table class="table table-sm align-middle mb-0">
                        <thead>
                            <tr>
                                <th>Month</th>
                                <th>Amount</th>
                                <th>Notes</th>
                                <th>Logged</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($leasing->settlements as $settlement)
                                <tr>
                                    <td class="fw-semibold" style="font-size: .82rem;">{{ $settlement->month_label }}</td>
                                    <td style="font-size: .82rem;">Rs. {{ number_format($settlement->amount, 2) }}</td>
                                    <td class="text-muted" style="font-size: .78rem;">{{ $settlement->notes ?: '—' }}</td>
                                    <td class="text-muted" style="font-size: .75rem;">{{ $settlement->created_at->format('M j, Y') }}</td>
                                    <td class="text-end">
                                        @can('vehicles.update')
                                            <form method="POST" action="{{ route('admin.leasing.settlements.destroy', [$leasing, $settlement]) }}" onsubmit="return confirm('Remove this settlement? The balance will be added back.');">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="btn btn-sm btn-light border btn-icon text-danger">
                                                    <i class="bi bi-trash"></i>
                                                </button>
                                            </form>
                                        @endcan
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @endif

            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Close</button>
            </x-slot:footer>
        </x-modal>
    @endforeach

    @can('vehicles.update')
        @foreach ($leasings as $leasing)
            <x-modal id="modal-edit-{{ $leasing->id }}" title="Edit Leasing Record" size="lg">
                <form id="form-edit-leasing-{{ $leasing->id }}" method="POST" action="{{ route('admin.leasing.update', $leasing) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.leasing._form', ['leasing' => $leasing, 'idPrefix' => 'edit-'.$leasing->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-leasing-{{ $leasing->id }}" class="btn btn-primary">Update Record</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan
@endsection
