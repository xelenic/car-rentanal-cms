@extends('layouts.admin')

@section('title', 'Customers')
@section('subtitle', 'Manage customer profiles and their hire history.')

@section('actions')
    @can('customers.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Customer
        </button>
    @endcan
@endsection

@section('content')
    <div class="card border-0">
        <div class="card-header">
            <form method="GET" style="max-width: 280px;">
                <div class="position-relative">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search by name, phone or email...">
                </div>
            </form>
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Customer</th>
                        <th>Phone</th>
                        <th>Email</th>
                        <th>NIC / Passport</th>
                        <th>Hires</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($customers as $customer)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #eef2ff; color: #4f46e5;">
                                        <i class="bi bi-person"></i>
                                    </div>
                                    <span class="fw-semibold" style="font-size: .8rem;">{{ $customer->name }}</span>
                                </div>
                            </td>
                            <td class="text-muted small">{{ $customer->phone }}</td>
                            <td class="text-muted small">{{ $customer->email ?: '—' }}</td>
                            <td class="text-muted small">{{ $customer->nic_passport ?: '—' }}</td>
                            <td>
                                @if ($customer->hires_count > 0)
                                    <button type="button" class="btn btn-link btn-sm p-0" style="font-size: .78rem;" data-bs-toggle="modal" data-bs-target="#modal-history-{{ $customer->id }}">
                                        {{ $customer->hires_count }} hire{{ $customer->hires_count === 1 ? '' : 's' }}
                                    </button>
                                @else
                                    <span class="text-muted small">None yet</span>
                                @endif
                            </td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('customers.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $customer->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('customers.delete')
                                        <form method="POST" action="{{ route('admin.customers.destroy', $customer) }}" onsubmit="return confirm('Delete this customer?');">
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
                            <td colspan="6" class="text-center text-muted py-4">
                                <i class="bi bi-person-lines-fill fs-4 d-block mb-1"></i>
                                No customers found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($customers->hasPages())
            <div class="card-footer bg-white">
                {{ $customers->links() }}
            </div>
        @endif
    </div>

    @can('customers.create')
        <x-modal id="modal-create" title="New Customer" size="lg">
            <form id="form-create-customer" method="POST" action="{{ route('admin.customers.store') }}">
                @csrf
                @include('admin.customers._form', ['customer' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-customer" class="btn btn-primary">Create Customer</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @foreach ($customers as $customer)
        <x-modal id="modal-history-{{ $customer->id }}" title="{{ $customer->name }} — Hire History" size="lg">
            @if ($customer->hires->isEmpty())
                <div class="text-center text-muted py-5">
                    <i class="bi bi-journal-check fs-3 d-block mb-2"></i>
                    No hires recorded yet.
                </div>
            @else
                <div class="d-flex flex-column gap-2">
                    @foreach ($customer->hires as $hire)
                        <div class="d-flex align-items-center justify-content-between border rounded p-2">
                            <div>
                                <div class="fw-semibold" style="font-size: .82rem;">
                                    Hire #{{ $hire->id }}
                                    <span class="badge rounded-pill bg-primary-subtle text-primary-emphasis ms-1">{{ \App\Models\Hire::TOUR_TYPES[$hire->tour_type] ?? $hire->tour_type }}</span>
                                </div>
                                <div class="text-muted" style="font-size: .72rem;">
                                    {{ $hire->vehicle?->model ?? 'No vehicle' }} &middot; {{ $hire->created_at?->format('M j, Y') }}
                                </div>
                            </div>
                            <div class="text-end">
                                @php
                                    $statusColor = match ($hire->status) {
                                        'started' => 'primary',
                                        'completed' => 'success',
                                        default => 'secondary',
                                    };
                                @endphp
                                <span class="badge rounded-pill bg-{{ $statusColor }}-subtle text-{{ $statusColor }}-emphasis">{{ $hire->status_label }}</span>
                                <div class="text-muted mt-1" style="font-size: .72rem;">Rs. {{ number_format($hire->hire_full_value, 2) }}</div>
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif
        </x-modal>

        @can('customers.update')
            <x-modal id="modal-edit-{{ $customer->id }}" title="Edit Customer" size="lg">
                <form id="form-edit-customer-{{ $customer->id }}" method="POST" action="{{ route('admin.customers.update', $customer) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.customers._form', ['customer' => $customer, 'idPrefix' => 'edit-'.$customer->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-customer-{{ $customer->id }}" class="btn btn-primary">Update Customer</button>
                </x-slot:footer>
            </x-modal>
        @endcan
    @endforeach
@endsection
