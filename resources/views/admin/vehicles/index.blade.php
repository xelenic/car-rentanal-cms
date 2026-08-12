@extends('layouts.admin')

@section('title', 'Vehicles')
@section('subtitle', 'Manage your rental fleet.')

@section('actions')
    @can('vehicles.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Vehicle
        </button>
    @endcan
@endsection

@section('content')
    <div class="row row-cols-1 row-cols-md-2 g-2 mb-2">
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
    </div>

    <div class="card border-0">
        <div class="card-header">
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                <div class="position-relative" style="max-width: 280px; flex: 1 1 220px;">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search by model or condition...">
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
                        <th>Model</th>
                        <th>Condition</th>
                        <th>Seats</th>
                        <th>PAX</th>
                        <th>Description</th>
                        <th>Total Full Value ({{ $periodLabel }})</th>
                        <th>Total Our Hire Value ({{ $periodLabel }})</th>
                        <th>Repair Cost</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($vehicles as $vehicle)
                        @php
                            $vehicleHireTotals = $hireTotalsByVehicle->get($vehicle->id, [
                                'hire_count' => 0,
                                'hire_full_value_total' => 0,
                                'our_hire_value_total' => 0,
                            ]);
                            $vehicleMaintenanceRecords = $maintenanceRecordsByVehicle->get($vehicle->id, collect());
                            $vehicleMaintenanceTotal = $maintenanceTotalsByVehicle->get($vehicle->id, 0);
                        @endphp
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #eef2ff; color: #4f46e5;">
                                        <i class="bi bi-car-front"></i>
                                    </div>
                                    <span class="fw-semibold" style="font-size: .8rem;">{{ $vehicle->model }}</span>
                                </div>
                            </td>
                            <td>
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
                            </td>
                            <td class="text-muted">{{ $vehicle->seats }}</td>
                            <td class="text-muted">{{ $vehicle->pax }}</td>
                            <td class="text-muted" style="max-width: 260px;">
                                <span class="d-inline-block text-truncate" style="max-width: 260px;">{{ $vehicle->description ?: '—' }}</span>
                            </td>
                            <td class="text-muted">Rs. {{ number_format($vehicleHireTotals['hire_full_value_total'], 2) }}</td>
                            <td class="text-muted">Rs. {{ number_format($vehicleHireTotals['our_hire_value_total'], 2) }}</td>
                            <td>
                                <div class="text-muted" style="font-size: .8rem;">Rs. {{ number_format($vehicleMaintenanceTotal, 2) }}</div>
                                <button type="button" class="btn btn-link btn-sm p-0" style="font-size: .75rem;" data-bs-toggle="modal" data-bs-target="#modal-repairs-{{ $vehicle->id }}">
                                    <i class="bi bi-tools me-1"></i>View Repairs
                                    @if ($vehicleMaintenanceRecords->isNotEmpty())
                                        ({{ $vehicleMaintenanceRecords->count() }})
                                    @endif
                                </button>
                            </td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('vehicles.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $vehicle->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('vehicles.delete')
                                        <form method="POST" action="{{ route('admin.vehicles.destroy', $vehicle) }}" onsubmit="return confirm('Delete this vehicle?');">
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
                                <i class="bi bi-car-front fs-4 d-block mb-1"></i>
                                No vehicles found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($vehicles->hasPages())
            <div class="card-footer bg-white">
                {{ $vehicles->links() }}
            </div>
        @endif
    </div>

    @can('vehicles.create')
        <x-modal id="modal-create" title="New Vehicle">
            <form id="form-create-vehicle" method="POST" action="{{ route('admin.vehicles.store') }}">
                @csrf
                @include('admin.vehicles._form', ['vehicle' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-vehicle" class="btn btn-primary">Create Vehicle</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @foreach ($vehicles as $vehicle)
        @php
            $vehicleMaintenanceRecords = $maintenanceRecordsByVehicle->get($vehicle->id, collect());
            $vehicleMaintenanceTotal = $maintenanceTotalsByVehicle->get($vehicle->id, 0);
        @endphp
        <x-modal id="modal-repairs-{{ $vehicle->id }}" title="Vehicle Repairs — {{ $vehicle->model }}" size="lg">
            @if ($vehicleMaintenanceRecords->isEmpty())
                <div class="text-center text-muted py-4">
                    <i class="bi bi-tools fs-3 d-block mb-2"></i>
                    No service, repair or parts records for this vehicle yet.
                </div>
            @else
                <div class="d-flex align-items-center justify-content-between border-bottom pb-2 mb-2">
                    <span class="text-muted small">{{ $vehicleMaintenanceRecords->count() }} record{{ $vehicleMaintenanceRecords->count() === 1 ? '' : 's' }}</span>
                    <span class="fw-semibold">Total: Rs. {{ number_format($vehicleMaintenanceTotal, 2) }}</span>
                </div>
                <div class="table-responsive">
                    <table class="table table-sm align-middle mb-0">
                        <thead>
                            <tr>
                                <th>Type</th>
                                <th>Cost</th>
                                <th>Mileage</th>
                                <th>Description</th>
                                <th>Logged By</th>
                                <th>Date</th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($vehicleMaintenanceRecords as $record)
                                @php
                                    $typeColor = match ($record->type) {
                                        'service' => 'info',
                                        'repair' => 'warning',
                                        default => 'secondary',
                                    };
                                @endphp
                                <tr>
                                    <td>
                                        <span class="badge rounded-pill bg-{{ $typeColor }}-subtle text-{{ $typeColor }}-emphasis">{{ $record->type_label }}</span>
                                    </td>
                                    <td class="fw-semibold" style="font-size: .82rem;">Rs. {{ number_format($record->cost, 2) }}</td>
                                    <td class="text-muted" style="font-size: .82rem;">{{ $record->mileage !== null ? number_format($record->mileage).' km' : '—' }}</td>
                                    <td class="text-muted" style="font-size: .82rem; max-width: 180px;">
                                        <span class="d-inline-block text-truncate" style="max-width: 180px;">{{ $record->description ?: '—' }}</span>
                                    </td>
                                    <td class="text-muted" style="font-size: .82rem;">{{ $record->driver->name ?? '—' }}</td>
                                    <td class="text-muted" style="font-size: .78rem;">{{ $record->created_at->format('M j, Y') }}</td>
                                    <td class="text-end">
                                        @if ($record->bill_url)
                                            <a href="{{ $record->bill_url }}" target="_blank" class="btn btn-sm btn-light border btn-icon" title="View Bill">
                                                <i class="bi bi-receipt"></i>
                                            </a>
                                        @endif
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
            <x-slot:footer>
                @can('vehicles.view')
                    <a href="{{ route('admin.repairs.index', ['vehicle_id' => $vehicle->id]) }}" class="btn btn-light border">
                        <i class="bi bi-list-ul me-1"></i> Full Repairs Page
                    </a>
                @endcan
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Close</button>
            </x-slot:footer>
        </x-modal>
    @endforeach

    @can('vehicles.update')
        @foreach ($vehicles as $vehicle)
            <x-modal id="modal-edit-{{ $vehicle->id }}" title="Edit Vehicle">
                <form id="form-edit-vehicle-{{ $vehicle->id }}" method="POST" action="{{ route('admin.vehicles.update', $vehicle) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.vehicles._form', ['vehicle' => $vehicle, 'idPrefix' => 'edit-'.$vehicle->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-vehicle-{{ $vehicle->id }}" class="btn btn-primary">Update Vehicle</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan
@endsection
