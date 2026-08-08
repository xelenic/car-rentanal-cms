@extends('layouts.admin')

@section('title', 'Packages')
@section('subtitle', 'Manage tour packages, pricing, and itineraries.')

@section('actions')
    @can('packages.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Package
        </button>
    @endcan
@endsection

@section('content')
    <div class="card border-0">
        <div class="card-header">
            <form method="GET" style="max-width: 280px;">
                <div class="position-relative">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search by package name...">
                </div>
            </form>
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Package</th>
                        <th>Hours</th>
                        <th>Price</th>
                        <th>Itinerary</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($packages as $package)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #fdf4ff; color: #a21caf;">
                                        <i class="bi bi-box-seam"></i>
                                    </div>
                                    <span class="fw-semibold" style="font-size: .8rem;">{{ $package->name }}</span>
                                </div>
                            </td>
                            <td class="text-muted">{{ $package->hours }} {{ \Illuminate\Support\Str::plural('hour', $package->hours) }}</td>
                            <td class="text-muted">${{ number_format($package->price, 2) }}</td>
                            <td class="text-muted" style="max-width: 280px;">
                                <span class="d-inline-block text-truncate" style="max-width: 280px;" title="{{ $package->itineraries->pluck('location.name')->join(' → ') }}">
                                    {{ $package->itineraries->pluck('location.name')->join(' → ') }}
                                </span>
                            </td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('packages.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $package->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('packages.delete')
                                        <form method="POST" action="{{ route('admin.packages.destroy', $package) }}" onsubmit="return confirm('Delete this package?');">
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
                            <td colspan="5" class="text-center text-muted py-4">
                                <i class="bi bi-box-seam fs-4 d-block mb-1"></i>
                                No packages found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($packages->hasPages())
            <div class="card-footer bg-white">
                {{ $packages->links() }}
            </div>
        @endif
    </div>

    @can('packages.create')
        <x-modal id="modal-create" title="New Package" size="lg">
            <form id="form-create-package" method="POST" action="{{ route('admin.packages.store') }}">
                @csrf
                @include('admin.packages._form', ['package' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-package" class="btn btn-primary">Create Package</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @can('packages.update')
        @foreach ($packages as $package)
            <x-modal id="modal-edit-{{ $package->id }}" title="Edit Package" size="lg">
                <form id="form-edit-package-{{ $package->id }}" method="POST" action="{{ route('admin.packages.update', $package) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.packages._form', ['package' => $package, 'idPrefix' => 'edit-'.$package->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-package-{{ $package->id }}" class="btn btn-primary">Update Package</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan
@endsection

@push('scripts')
    <script>
        window.__locationOptions = @json($locations->map(fn ($l) => ['id' => $l->id, 'name' => $l->name])->values());

        function updateItineraryRemoveVisibility(container) {
            const rows = container.querySelectorAll('.itinerary-row');
            rows.forEach((row) => {
                const btn = row.querySelector('.remove-itinerary-row');
                if (btn) {
                    btn.style.display = rows.length > 1 ? '' : 'none';
                }
            });
        }

        document.addEventListener('click', function (e) {
            const addBtn = e.target.closest('.add-itinerary-row');
            if (addBtn) {
                const prefix = addBtn.dataset.prefix;
                const container = document.getElementById('itinerary-rows-' + prefix);
                const index = parseInt(addBtn.dataset.nextIndex, 10);

                const row = document.createElement('div');
                row.className = 'itinerary-row d-flex gap-2 align-items-start mb-2';

                const label = document.createElement('span');
                label.className = 'text-muted small pt-2';
                label.style.width = '1.25rem';
                label.textContent = (index + 1) + '.';

                const select = document.createElement('select');
                select.name = `itinerary[${index}][location_id]`;
                select.className = 'form-select form-select-sm';
                select.required = true;

                const emptyOpt = document.createElement('option');
                emptyOpt.value = '';
                emptyOpt.textContent = 'Select location';
                select.appendChild(emptyOpt);

                window.__locationOptions.forEach((loc) => {
                    const opt = document.createElement('option');
                    opt.value = loc.id;
                    opt.textContent = loc.name;
                    select.appendChild(opt);
                });

                const noteInput = document.createElement('input');
                noteInput.type = 'text';
                noteInput.name = `itinerary[${index}][note]`;
                noteInput.className = 'form-control form-control-sm';
                noteInput.placeholder = 'Note (optional)';

                const removeBtn = document.createElement('button');
                removeBtn.type = 'button';
                removeBtn.className = 'btn btn-sm btn-light border btn-icon text-danger remove-itinerary-row';
                removeBtn.innerHTML = '<i class="bi bi-x-lg"></i>';

                row.appendChild(label);
                row.appendChild(select);
                row.appendChild(noteInput);
                row.appendChild(removeBtn);
                container.appendChild(row);

                addBtn.dataset.nextIndex = index + 1;
                updateItineraryRemoveVisibility(container);
                return;
            }

            const removeBtn = e.target.closest('.remove-itinerary-row');
            if (removeBtn) {
                const container = removeBtn.closest('[id^="itinerary-rows-"]');
                removeBtn.closest('.itinerary-row').remove();
                updateItineraryRemoveVisibility(container);
            }
        });
    </script>
@endpush
