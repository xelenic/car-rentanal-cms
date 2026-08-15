@extends('layouts.admin')

@section('title', 'Locations')
@section('subtitle', 'Manage pickup and drop-off locations.')

@section('actions')
    @can('locations.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Location
        </button>
    @endcan
@endsection

@push('styles')
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
    <style>
        .location-map-picker, .location-map-view {
            height: 260px;
            border-radius: .6rem;
            border: 1px solid var(--border-color);
            overflow: hidden;
        }
    </style>
@endpush

@section('content')
    <div class="card border-0">
        <div class="card-header">
            <form method="GET" style="max-width: 280px;">
                <div class="position-relative">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search by name or description...">
                </div>
            </form>
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Location</th>
                        <th>Description</th>
                        <th>Coordinates</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($locations as $location)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #eef2ff; color: #4f46e5;">
                                        <i class="bi bi-geo-alt"></i>
                                    </div>
                                    <span class="fw-semibold" style="font-size: .8rem;">{{ $location->name }}</span>
                                </div>
                            </td>
                            <td class="text-muted" style="max-width: 260px;">
                                <span class="d-inline-block text-truncate" style="max-width: 260px;">{{ $location->description ?: '—' }}</span>
                            </td>
                            <td class="text-muted small">
                                @if ($location->latitude !== null && $location->longitude !== null)
                                    {{ number_format($location->latitude, 5) }}, {{ number_format($location->longitude, 5) }}
                                @else
                                    <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis">Not pinned yet</span>
                                @endif
                            </td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-view-{{ $location->id }}">
                                        <i class="bi bi-map"></i>
                                    </button>
                                    @can('locations.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $location->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('locations.delete')
                                        <form method="POST" action="{{ route('admin.locations.destroy', $location) }}" onsubmit="return confirm('Delete this location?');">
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
                            <td colspan="4" class="text-center text-muted py-4">
                                <i class="bi bi-geo-alt fs-4 d-block mb-1"></i>
                                No locations found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($locations->hasPages())
            <div class="card-footer bg-white">
                {{ $locations->links() }}
            </div>
        @endif
    </div>

    @can('locations.create')
        <x-modal id="modal-create" title="New Location" size="lg">
            <form id="form-create-location" method="POST" action="{{ route('admin.locations.store') }}">
                @csrf
                @include('admin.locations._form', ['location' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-location" class="btn btn-primary">Create Location</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @foreach ($locations as $location)
        <x-modal id="modal-view-{{ $location->id }}" title="{{ $location->name }}">
            @if ($location->description)
                <p class="text-muted small mb-2">{{ $location->description }}</p>
            @endif
            @if ($location->latitude !== null && $location->longitude !== null)
                <div id="map-view-{{ $location->id }}" class="location-map-view"></div>
                <div class="form-text mt-2">{{ number_format($location->latitude, 6) }}, {{ number_format($location->longitude, 6) }}</div>
            @else
                <div class="text-muted small border rounded-3 p-3 text-center">
                    <i class="bi bi-geo-alt fs-4 d-block mb-1"></i>
                    This location hasn't been pinned on the map yet.
                    @can('locations.update')
                        Edit it to set its coordinates.
                    @endcan
                </div>
            @endif
        </x-modal>

        @can('locations.update')
            <x-modal id="modal-edit-{{ $location->id }}" title="Edit Location" size="lg">
                <form id="form-edit-location-{{ $location->id }}" method="POST" action="{{ route('admin.locations.update', $location) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.locations._form', ['location' => $location, 'idPrefix' => 'edit-'.$location->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-location-{{ $location->id }}" class="btn btn-primary">Update Location</button>
                </x-slot:footer>
            </x-modal>
        @endcan
    @endforeach
@endsection

@push('scripts')
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
    <script>
        window.__locationMaps = window.__locationMaps || {};

        function initLocationPickerMap(prefix, initialLat, initialLng) {
            if (window.__locationMaps[prefix]) {
                window.__locationMaps[prefix].invalidateSize();
                return;
            }

            const latInput = document.getElementById(prefix + '-latitude');
            const lngInput = document.getElementById(prefix + '-longitude');
            const hasCoords = initialLat !== null && initialLng !== null && initialLat !== '' && initialLng !== '';
            const startLat = hasCoords ? parseFloat(initialLat) : 20;
            const startLng = hasCoords ? parseFloat(initialLng) : 0;

            const map = L.map('map-' + prefix).setView([startLat, startLng], hasCoords ? 14 : 2);
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '&copy; OpenStreetMap contributors',
                maxZoom: 19,
            }).addTo(map);

            let marker = hasCoords ? L.marker([startLat, startLng], { draggable: true }).addTo(map) : null;
            if (marker) {
                marker.on('dragend', function () {
                    const pos = marker.getLatLng();
                    latInput.value = pos.lat.toFixed(7);
                    lngInput.value = pos.lng.toFixed(7);
                });
            }

            map.on('click', function (e) {
                latInput.value = e.latlng.lat.toFixed(7);
                lngInput.value = e.latlng.lng.toFixed(7);

                if (marker) {
                    marker.setLatLng(e.latlng);
                } else {
                    marker = L.marker(e.latlng, { draggable: true }).addTo(map);
                    marker.on('dragend', function () {
                        const pos = marker.getLatLng();
                        latInput.value = pos.lat.toFixed(7);
                        lngInput.value = pos.lng.toFixed(7);
                    });
                }
            });

            window.__locationMaps[prefix] = map;
            setTimeout(() => map.invalidateSize(), 150);
        }

        function initLocationViewMap(prefix, lat, lng, label) {
            if (window.__locationMaps[prefix]) {
                window.__locationMaps[prefix].invalidateSize();
                return;
            }

            const map = L.map('map-' + prefix, { scrollWheelZoom: false }).setView([lat, lng], 14);
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '&copy; OpenStreetMap contributors',
                maxZoom: 19,
            }).addTo(map);
            L.marker([lat, lng]).addTo(map).bindPopup(label);

            window.__locationMaps[prefix] = map;
            setTimeout(() => map.invalidateSize(), 150);
        }

        document.getElementById('modal-create')?.addEventListener('shown.bs.modal', function () {
            initLocationPickerMap('create', null, null);
        });

        @foreach ($locations as $location)
            @if ($location->latitude !== null && $location->longitude !== null)
                document.getElementById('modal-view-{{ $location->id }}')?.addEventListener('shown.bs.modal', function () {
                    initLocationViewMap('view-{{ $location->id }}', {{ $location->latitude }}, {{ $location->longitude }}, @json($location->name));
                });
            @endif

            document.getElementById('modal-edit-{{ $location->id }}')?.addEventListener('shown.bs.modal', function () {
                initLocationPickerMap('edit-{{ $location->id }}', {{ $location->latitude === null ? 'null' : $location->latitude }}, {{ $location->longitude === null ? 'null' : $location->longitude }});
            });
        @endforeach
    </script>
@endpush
