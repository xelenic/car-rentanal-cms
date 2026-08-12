@extends('layouts.admin')

@section('title', 'Repairs')
@section('subtitle', 'Vehicle service, repair and parts records logged by drivers.')

@section('content')
    <div class="row row-cols-1 row-cols-md-2 g-2 mb-2">
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #f3f4f6; color: #4b5563;">
                        <i class="bi bi-tools"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Records{{ ($selectedVehicleId || $selectedType || $selectedYear) ? ' (filtered)' : '' }}</div>
                        <div class="fs-5 fw-bold">{{ number_format($recordCount) }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdeee7; color: #c95a26;">
                        <i class="bi bi-cash-coin"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total Cost{{ ($selectedVehicleId || $selectedType || $selectedYear) ? ' (filtered)' : '' }}</div>
                        <div class="fs-5 fw-bold">Rs. {{ number_format($totalCost, 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card border-0">
        <div class="card-header">
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                <div class="position-relative" style="max-width: 240px; flex: 1 1 200px;">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search vehicle, driver or description...">
                </div>

                <select name="vehicle_id" class="form-select" style="max-width: 170px;" onchange="this.form.submit()">
                    <option value="">All Vehicles</option>
                    @foreach ($vehicles as $vehicle)
                        <option value="{{ $vehicle->id }}" {{ (string) $selectedVehicleId === (string) $vehicle->id ? 'selected' : '' }}>{{ $vehicle->model }}</option>
                    @endforeach
                </select>

                <select name="type" class="form-select" style="max-width: 160px;" onchange="this.form.submit()">
                    <option value="">All Types</option>
                    @foreach ($types as $key => $label)
                        <option value="{{ $key }}" {{ $selectedType === $key ? 'selected' : '' }}>{{ $label }}</option>
                    @endforeach
                </select>

                <select name="year" class="form-select" style="max-width: 120px;" onchange="this.form.submit()">
                    <option value="">All Years</option>
                    @foreach ($availableYears as $year)
                        <option value="{{ $year }}" {{ (string) $selectedYear === (string) $year ? 'selected' : '' }}>{{ $year }}</option>
                    @endforeach
                </select>

                <select name="month" class="form-select" style="max-width: 150px;" onchange="this.form.submit()">
                    <option value="">All Months</option>
                    @foreach ($monthsByYear[$selectedYear] ?? [] as $month)
                        <option value="{{ $month }}" {{ (string) $selectedMonth === (string) $month ? 'selected' : '' }}>{{ \Carbon\Carbon::create()->month($month)->format('F') }}</option>
                    @endforeach
                </select>

                @if ($selectedVehicleId || $selectedType || $selectedYear || $selectedMonth || $search)
                    <a href="{{ route('admin.repairs.index') }}" class="btn btn-light border">Clear</a>
                @endif
            </form>
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Vehicle</th>
                        <th>Type</th>
                        <th>Cost</th>
                        <th>Mileage</th>
                        <th>Description</th>
                        <th>Logged By</th>
                        <th>Date</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($records as $record)
                        @php
                            $typeColor = match ($record->type) {
                                'service' => 'info',
                                'repair' => 'warning',
                                default => 'secondary',
                            };
                        @endphp
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #eef2ff; color: #4f46e5;">
                                        <i class="bi bi-car-front"></i>
                                    </div>
                                    <span class="fw-semibold" style="font-size: .8rem;">{{ $record->vehicle->model ?? '—' }}</span>
                                </div>
                            </td>
                            <td>
                                <span class="badge rounded-pill bg-{{ $typeColor }}-subtle text-{{ $typeColor }}-emphasis">{{ $record->type_label }}</span>
                            </td>
                            <td class="fw-semibold" style="font-size: .82rem;">Rs. {{ number_format($record->cost, 2) }}</td>
                            <td class="text-muted">{{ $record->mileage !== null ? number_format($record->mileage).' km' : '—' }}</td>
                            <td class="text-muted" style="max-width: 220px;">
                                <span class="d-inline-block text-truncate" style="max-width: 220px;">{{ $record->description ?: '—' }}</span>
                            </td>
                            <td class="text-muted">{{ $record->driver->name ?? '—' }}</td>
                            <td class="text-muted" style="font-size: .8rem;">{{ $record->created_at->format('M j, Y') }}</td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @if ($record->bill_url)
                                        <a href="{{ $record->bill_url }}" target="_blank" class="btn btn-sm btn-light border btn-icon" title="View Bill">
                                            <i class="bi bi-receipt"></i>
                                        </a>
                                    @endif
                                    @can('vehicles.delete')
                                        <form method="POST" action="{{ route('admin.repairs.destroy', $record) }}" onsubmit="return confirm('Delete this repair record?');">
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
                            <td colspan="8" class="text-center text-muted py-4">
                                <i class="bi bi-tools fs-4 d-block mb-1"></i>
                                No repair records found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($records->hasPages())
            <div class="card-footer bg-white">
                {{ $records->links() }}
            </div>
        @endif
    </div>
@endsection
