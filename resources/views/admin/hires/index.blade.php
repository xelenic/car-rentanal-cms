@extends('layouts.admin')

@section('title', 'Hires')
@section('subtitle', 'Manage vehicle hires, tours, and payments.')

@section('actions')
    @can('hires.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Hire
        </button>
    @endcan
@endsection

@push('styles')
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">
    <style>
        [data-tour-section] { display: none; }
        .hire-track-map { height: 320px; border-radius: .6rem; border: 1px solid var(--border-color); overflow: hidden; }
        /* Google's suggestion dropdown defaults to z-index 1000 — below
           Bootstrap's modal (1055), so it would render behind the New/Edit
           Hire modal and be unclickable there. */
        .pac-container { z-index: 1080; }
        .upcoming-hires-card { cursor: pointer; transition: box-shadow .15s ease, transform .15s ease; }
        .upcoming-hires-card:hover { box-shadow: 0 4px 14px rgba(0,0,0,.08); transform: translateY(-1px); }
        .upcoming-hires-card.active { border-color: var(--primary); background: var(--primary-light); }
    </style>
@endpush

@section('content')
    <a href="{{ $showUpcoming ? route('admin.hires.index', request()->except(['upcoming', 'page'])) : route('admin.hires.index', array_merge(request()->except('page'), ['upcoming' => 1])) }}"
        class="card border-0 upcoming-hires-card mb-2 {{ $showUpcoming ? 'active' : '' }}" style="max-width: 320px;">
        <div class="card-body d-flex align-items-center gap-2">
            <div class="stat-icon" style="background: #fff7ed; color: #ea580c;">
                <i class="bi bi-calendar-event"></i>
            </div>
            <div class="flex-grow-1">
                <div class="text-muted small">Upcoming Hires</div>
                <div class="fs-5 fw-bold">{{ $upcomingCount }}</div>
            </div>
            @if ($showUpcoming)
                <span class="badge rounded-pill bg-primary">Showing <i class="bi bi-x-lg ms-1"></i></span>
            @endif
        </div>
    </a>

    <div class="card border-0">
        <div class="card-header d-flex align-items-center justify-content-between flex-wrap gap-2">
            <form method="GET" style="max-width: 280px;">
                @if ($showUpcoming)
                    <input type="hidden" name="upcoming" value="1">
                @endif
                <div class="position-relative">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search by customer or description...">
                </div>
            </form>
            @if ($showUpcoming)
                <span class="badge rounded-pill bg-primary-subtle text-primary-emphasis">
                    <i class="bi bi-calendar-event me-1"></i> Upcoming only — soonest first
                </span>
            @endif
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Hire</th>
                        <th>Status</th>
                        <th>Scheduled</th>
                        <th>Tour</th>
                        <th>Driver / Vehicle</th>
                        <th>Value</th>
                        <th>Payment</th>
                        <th>Tracking</th>
                        <th>Expenses</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($hires as $hire)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #eef2ff; color: #4f46e5;">
                                        <i class="bi bi-journal-check"></i>
                                    </div>
                                    <div>
                                        <span class="fw-semibold" style="font-size: .8rem;">Hire #{{ $hire->id }}</span>
                                        @if ($hire->customer)
                                            <div class="text-muted" style="font-size: .72rem;">{{ $hire->customer->name }}</div>
                                        @endif
                                    </div>
                                </div>
                            </td>
                            <td>
                                @php
                                    $statusColor = match ($hire->status) {
                                        'started' => 'primary',
                                        'completed' => 'success',
                                        default => 'secondary',
                                    };
                                @endphp
                                <span class="badge rounded-pill bg-{{ $statusColor }}-subtle text-{{ $statusColor }}-emphasis">{{ $hire->status_label }}</span>
                            </td>
                            <td class="text-muted" style="font-size: .78rem;">
                                @if ($hire->start_time)
                                    <div>{{ $hire->start_time->format('M j, Y') }}</div>
                                    <div style="font-size: .72rem;">{{ $hire->start_time->format('g:i A') }}</div>
                                    @if ($hire->is_upcoming)
                                        <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis mt-1">Upcoming</span>
                                    @endif
                                @else
                                    <span class="text-muted small">Not scheduled</span>
                                @endif
                            </td>
                            <td>
                                <span class="badge rounded-pill bg-primary-subtle text-primary-emphasis mb-1">{{ \App\Models\Hire::TOUR_TYPES[$hire->tour_type] ?? $hire->tour_type }}</span>
                                <div class="text-muted" style="font-size: .72rem; max-width: 220px;">
                                    @if ($hire->tour_type === 'package')
                                        {{ $hire->package?->name ?? '—' }}
                                    @elseif ($hire->tour_type === 'multi_day')
                                        {{ $hire->stayLocations->pluck('location.name')->join(' → ') ?: '—' }}
                                    @else
                                        {{ $hire->fromLocation?->location?->name }} → {{ $hire->toLocation?->location?->name }}
                                    @endif
                                </div>
                            </td>
                            <td class="text-muted" style="font-size: .78rem;">
                                {{ $hire->driver?->name ?? '—' }}<br>
                                <span class="text-muted" style="font-size: .72rem;">{{ $hire->vehicle?->model ?? '—' }}</span>
                            </td>
                            <td class="text-muted" style="font-size: .78rem;">
                                <div>Rs. {{ number_format($hire->hire_full_value, 2) }}</div>
                                <div style="font-size: .72rem;">Commission: Rs. {{ number_format($hire->commission, 2) }}</div>
                            </td>
                            <td>
                                <span class="badge rounded-pill bg-light text-dark border">{{ \App\Models\Hire::PAYMENT_TYPES[$hire->payment_type] ?? $hire->payment_type }}</span>
                            </td>
                            <td style="font-size: .78rem;">
                                @if ($hire->is_tracking)
                                    <span class="badge rounded-pill bg-success-subtle text-success-emphasis">
                                        <i class="bi bi-record-circle"></i> Active
                                    </span>
                                @elseif ($hire->tracking_started_at)
                                    <span class="badge rounded-pill bg-light text-dark border">Stopped</span>
                                @else
                                    <span class="text-muted small">Not started</span>
                                @endif
                                @if ($hire->trackingPoints->isNotEmpty())
                                    <div class="text-muted mt-1" style="font-size: .72rem;">{{ number_format($hire->total_distance_km, 1) }} km</div>
                                @endif
                            </td>
                            <td style="font-size: .78rem;">
                                @if ($hire->expenses->isNotEmpty())
                                    <div class="fw-semibold">Rs. {{ number_format($hire->expenses->sum('amount'), 2) }}</div>
                                    <button type="button" class="btn btn-link btn-sm p-0" style="font-size: .72rem;" data-bs-toggle="modal" data-bs-target="#modal-expenses-{{ $hire->id }}">
                                        {{ $hire->expenses->count() }} entr{{ $hire->expenses->count() === 1 ? 'y' : 'ies' }}
                                    </button>
                                @else
                                    <span class="text-muted small">None yet</span>
                                @endif
                            </td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-track-{{ $hire->id }}">
                                        <i class="bi bi-map"></i>
                                    </button>
                                    @can('hires.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $hire->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('hires.delete')
                                        <form method="POST" action="{{ route('admin.hires.destroy', $hire) }}" onsubmit="return confirm('Delete this hire?');">
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
                            <td colspan="10" class="text-center text-muted py-4">
                                <i class="bi bi-journal-check fs-4 d-block mb-1"></i>
                                @if ($showUpcoming)
                                    No upcoming hires scheduled.
                                @else
                                    No hires found.
                                @endif
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($hires->hasPages())
            <div class="card-footer bg-white">
                {{ $hires->links() }}
            </div>
        @endif
    </div>

    @foreach ($hires as $hire)
        <x-modal id="modal-expenses-{{ $hire->id }}" title="Hire #{{ $hire->id }} — Expenses" size="lg">
            <div class="row g-2 mb-3">
                <div class="col-6">
                    <div class="text-muted small">Total Expenses</div>
                    <div class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($hire->expenses->sum('amount'), 2) }}</div>
                </div>
                <div class="col-6">
                    <div class="text-muted small">Entries</div>
                    <div class="fw-semibold" style="font-size: .85rem;">{{ $hire->expenses->count() }}</div>
                </div>
            </div>

            @if ($hire->expenses->isEmpty())
                <div class="text-center text-muted py-5">
                    <i class="bi bi-receipt fs-3 d-block mb-2"></i>
                    No expenses recorded yet.
                </div>
            @else
                <div class="d-flex flex-column gap-2">
                    @foreach ($hire->expenses as $expense)
                        <div class="d-flex align-items-center gap-3 border rounded p-2">
                            @if ($expense->receipt_url)
                                <a href="{{ $expense->receipt_url }}" target="_blank" rel="noopener">
                                    <img src="{{ $expense->receipt_url }}" alt="Receipt" style="width: 56px; height: 56px; object-fit: cover; border-radius: .4rem;">
                                </a>
                            @else
                                <div class="d-flex align-items-center justify-content-center bg-light rounded" style="width: 56px; height: 56px;">
                                    <i class="bi bi-receipt text-muted"></i>
                                </div>
                            @endif
                            <div class="flex-grow-1">
                                <div class="fw-semibold" style="font-size: .82rem;">{{ $expense->category_label }} — Rs. {{ number_format($expense->amount, 2) }}</div>
                                <div class="text-muted" style="font-size: .72rem;">{{ $expense->created_at?->format('M j, Y g:i A') }}</div>
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif
        </x-modal>
    @endforeach

    @foreach ($hires as $hire)
        <x-modal id="modal-track-{{ $hire->id }}" title="Hire #{{ $hire->id }} — Location Track" size="lg">
            <div class="d-flex align-items-center justify-content-between mb-2">
                <div class="row g-2 flex-grow-1">
                    <div class="col-4">
                        <div class="text-muted small">Status</div>
                        <div class="fw-semibold track-status" style="font-size: .85rem;">
                            @if ($hire->is_tracking)
                                <span class="text-success"><i class="bi bi-record-circle"></i> Active</span>
                            @elseif ($hire->tracking_started_at)
                                Stopped
                            @else
                                Not started
                            @endif
                        </div>
                    </div>
                    <div class="col-4">
                        <div class="text-muted small">Distance</div>
                        <div class="fw-semibold track-distance" style="font-size: .85rem;">{{ number_format($hire->total_distance_km, 2) }} km</div>
                    </div>
                    <div class="col-4">
                        <div class="text-muted small">Points Logged</div>
                        <div class="fw-semibold track-points-count" style="font-size: .85rem;">{{ $hire->trackingPoints->count() }}</div>
                    </div>
                </div>
                <span class="badge rounded-pill bg-success-subtle text-success-emphasis track-live-badge ms-2" style="display: none; white-space: nowrap;">
                    <i class="bi bi-broadcast"></i> Live
                </span>
            </div>

            <div class="track-empty-state text-center text-muted py-5" style="{{ $hire->trackingPoints->isEmpty() ? '' : 'display: none;' }}">
                <i class="bi bi-geo-alt fs-3 d-block mb-2"></i>
                No location data yet. Tracking starts when the driver presses Start in the app.
            </div>
            <div id="map-track-{{ $hire->id }}" class="hire-track-map" style="{{ $hire->trackingPoints->isEmpty() ? 'display: none;' : '' }}"></div>
        </x-modal>
    @endforeach

    @can('hires.create')
        <x-modal id="modal-create" title="New Hire" size="xl">
            <form id="form-create-hire" method="POST" action="{{ route('admin.hires.store') }}">
                @csrf
                @include('admin.hires._form', ['hire' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-hire" class="btn btn-primary">Create Hire</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @can('hires.update')
        @foreach ($hires as $hire)
            <x-modal id="modal-edit-{{ $hire->id }}" title="Edit Hire #{{ $hire->id }}" size="xl">
                <form id="form-edit-hire-{{ $hire->id }}" method="POST" action="{{ route('admin.hires.update', $hire) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.hires._form', ['hire' => $hire, 'idPrefix' => 'edit-'.$hire->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-hire-{{ $hire->id }}" class="btn btn-primary">Update Hire</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan
@endsection

@push('scripts')
    @if ($googleMapsApiKey)
        <script>
            // Set by initLocationAutocomplete() (the Google Maps API's load
            // callback) once google.maps.places is actually available —
            // attachPlaceAutocomplete() no-ops before that. Every hire row's
            // edit modal renders its own full set of location inputs, so
            // instances are only bound lazily, on focus (see the 'focusin'
            // listener below) — not eagerly for all of them on page load,
            // which would mean dozens of idle Autocomplete instances across
            // modals the admin hasn't even opened.
            window.__placesReady = false;

            function initLocationAutocomplete() {
                window.__placesReady = true;
                if (document.activeElement?.matches('.location-place-input')) {
                    attachPlaceAutocomplete(document.activeElement);
                }
            }
        </script>
        <script src="https://maps.googleapis.com/maps/api/js?key={{ $googleMapsApiKey }}&libraries=places&callback=initLocationAutocomplete&loading=async" async defer></script>
    @endif
    <script>
        function updateHireSections(prefix) {
            const select = document.getElementById(prefix + '-tour_type');
            if (!select) return;
            const value = select.value;

            document.querySelectorAll(`[data-hire-form="${prefix}"] [data-tour-section]`).forEach((section) => {
                const isActive = section.dataset.tourSection === value;
                section.style.display = isActive ? 'block' : 'none';
                section.querySelectorAll('input, select, textarea').forEach((el) => {
                    el.disabled = !isActive;
                });
            });

            // Sections shown for every tour type except one (e.g. the
            // Scheduled Date & Time field — packages already have their own
            // start/end range, everything else can optionally use this).
            document.querySelectorAll(`[data-hire-form="${prefix}"] [data-tour-section-except]`).forEach((section) => {
                const isActive = value !== '' && value !== section.dataset.tourSectionExcept;
                section.style.display = isActive ? 'block' : 'none';
                section.querySelectorAll('input, select, textarea').forEach((el) => {
                    el.disabled = !isActive;
                });
            });
        }

        function updateStayRemoveVisibility(container) {
            const rows = container.querySelectorAll('.stay-location-row');
            rows.forEach((row) => {
                const btn = row.querySelector('.remove-stay-location-row');
                if (btn) {
                    btn.style.display = rows.length > 1 ? '' : 'none';
                }
            });
        }

        // A location search field (Google Places suggestions) plus its
        // hidden lat/lng companions — built for every dynamically-added
        // stay/day location row, matching the ones rendered server-side.
        // $name is the text input's own name (e.g. "stay_location_names[]");
        // the lat/lng inputs derive theirs from it.
        function buildLocationField(name) {
            const wrapper = document.createElement('div');
            wrapper.className = 'flex-grow-1';

            const nameInput = document.createElement('input');
            nameInput.type = 'text';
            nameInput.name = name;
            nameInput.className = 'form-control form-control-sm location-place-input';
            nameInput.placeholder = 'Search for a location...';
            nameInput.autocomplete = 'off';
            wrapper.appendChild(nameInput);

            const latInput = document.createElement('input');
            latInput.type = 'hidden';
            latInput.name = name.replace('_names', '_lats');
            latInput.className = 'location-lat-input';
            wrapper.appendChild(latInput);

            const lngInput = document.createElement('input');
            lngInput.type = 'hidden';
            lngInput.name = name.replace('_names', '_lngs');
            lngInput.className = 'location-lng-input';
            wrapper.appendChild(lngInput);

            // Not attached here — attachPlaceAutocomplete() binds lazily via
            // the 'focusin' listener below, the first time this field is
            // actually focused.

            return wrapper;
        }

        // Wires Google Places suggestions onto a "type the new location's
        // name" input — picking a suggestion fills the name and captures its
        // coordinates into the sibling hidden lat/lng inputs (see
        // resolveLocationId() in HireController, which saves them on
        // create). No-ops gracefully if the Maps API hasn't loaded (no key
        // configured, still loading, or blocked) — the input still works as
        // a plain free-text field either way.
        function attachPlaceAutocomplete(input) {
            if (!window.google?.maps?.places || input.dataset.placesBound) return;
            input.dataset.placesBound = '1';

            const autocomplete = new google.maps.places.Autocomplete(input, {
                fields: ['name', 'formatted_address', 'geometry'],
            });

            autocomplete.addListener('place_changed', function () {
                const place = autocomplete.getPlace();
                const wrapper = input.parentElement;
                const latInput = wrapper?.querySelector('.location-lat-input');
                const lngInput = wrapper?.querySelector('.location-lng-input');

                if (!place || !place.geometry || !place.geometry.location) {
                    if (latInput) latInput.value = '';
                    if (lngInput) lngInput.value = '';
                    return;
                }

                input.value = place.name || place.formatted_address || input.value;
                if (latInput) latInput.value = place.geometry.location.lat();
                if (lngInput) lngInput.value = place.geometry.location.lng();
            });
        }

        function buildRemoveButton(className) {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = `btn btn-sm btn-light border btn-icon text-danger ${className}`;
            btn.innerHTML = '<i class="bi bi-x-lg"></i>';
            return btn;
        }

        // Multi day tours: a day can hold more than one location — keep
        // each day's own "×" buttons hidden when it's down to one location.
        function updateDayLocationRemoveVisibility(dayLocationsEl) {
            const rows = dayLocationsEl.querySelectorAll('.stay-location-row');
            rows.forEach((row) => {
                const btn = row.querySelector('.remove-stay-location-row');
                if (btn) btn.style.display = rows.length > 1 ? '' : 'none';
            });
        }

        // Keep the "Day N" badges renumbered — and hide "Remove Day" when
        // only one day is left — as days are added, removed, or reordered.
        function updateStayDayGroups(container) {
            const groups = container.querySelectorAll('.stay-day-group');
            groups.forEach((group, index) => {
                const label = group.querySelector('.day-label');
                if (label) label.textContent = `Day ${index + 1}`;
                const removeBtn = group.querySelector('.remove-stay-day');
                if (removeBtn) removeBtn.style.display = groups.length > 1 ? '' : 'none';
            });
        }

        function updateCommissionDisplay(prefix) {
            const fullInput = document.getElementById(prefix + '-hire_full_value');
            const ourInput = document.getElementById(prefix + '-our_hire_value');
            const display = document.getElementById(prefix + '-commission-display');
            if (!fullInput || !ourInput || !display) return;

            const full = parseFloat(fullInput.value) || 0;
            const ours = parseFloat(ourInput.value) || 0;
            display.textContent = (full - ours).toFixed(2);
        }

        function updateCustomerFields(prefix) {
            const select = document.getElementById(prefix + '-customer_id');
            if (!select) return;
            const isNew = select.value === 'new';

            document.querySelectorAll(`[data-new-customer="${prefix}"]`).forEach((field) => {
                field.style.display = isNew ? 'block' : 'none';
                const input = field.querySelector('input');
                if (input) input.required = isNew;
            });
        }

        document.addEventListener('change', function (e) {
            if (e.target.matches('.hire-tour-type')) {
                updateHireSections(e.target.dataset.target);
            }
            if (e.target.matches('.hire-customer-select')) {
                updateCustomerFields(e.target.dataset.target);
            }
        });

        // Lazily binds Google Places suggestions to a location field the
        // first time it's actually focused, rather than to every location
        // field across every hire row's edit modal on page load.
        document.addEventListener('focusin', function (e) {
            if (e.target.matches?.('.location-place-input')) {
                attachPlaceAutocomplete(e.target);
            }
        });

        document.addEventListener('input', function (e) {
            if (e.target.matches('.hire-value-input')) {
                updateCommissionDisplay(e.target.dataset.target);
            }
        });

        document.addEventListener('click', function (e) {
            // Day tours' flat "Add Location" (one list, no day grouping).
            const addBtn = e.target.closest('.add-stay-location-row');
            if (addBtn) {
                const container = document.getElementById(addBtn.dataset.container);
                const row = document.createElement('div');
                row.className = 'stay-location-row d-flex gap-2 align-items-center mb-2';
                row.appendChild(buildLocationField('stay_location_names[]'));
                row.appendChild(buildRemoveButton('remove-stay-location-row'));
                container.appendChild(row);
                updateStayRemoveVisibility(container);
                return;
            }

            // Multi-day tours: "Add Location" within one specific day.
            const addDayLocBtn = e.target.closest('.add-day-location-row');
            if (addDayLocBtn) {
                const dayGroup = addDayLocBtn.closest('.stay-day-group');
                const dayLocationsEl = dayGroup.querySelector('.stay-day-locations');
                const dayKey = dayLocationsEl.dataset.dayKey;

                const row = document.createElement('div');
                row.className = 'stay-location-row d-flex gap-2 align-items-center mb-2';
                row.appendChild(buildLocationField(`day_location_names[${dayKey}][]`));
                row.appendChild(buildRemoveButton('remove-stay-location-row'));
                dayLocationsEl.appendChild(row);
                updateDayLocationRemoveVisibility(dayLocationsEl);
                return;
            }

            // Multi-day tours: "Add Day" — a new day with one empty location.
            const addDayBtn = e.target.closest('.add-stay-day');
            if (addDayBtn) {
                const container = document.getElementById(addDayBtn.dataset.container);
                const dayKey = container.dataset.nextDayKey;
                container.dataset.nextDayKey = String(parseInt(dayKey, 10) + 1);

                const group = document.createElement('div');
                group.className = 'stay-day-group border rounded-2 p-2 mb-2';

                const header = document.createElement('div');
                header.className = 'd-flex align-items-center justify-content-between mb-2';
                const label = document.createElement('span');
                label.className = 'badge rounded-pill bg-primary-subtle text-primary-emphasis day-label';
                label.textContent = 'Day';
                const removeDayBtn = buildRemoveButton('remove-stay-day');
                removeDayBtn.innerHTML = '<i class="bi bi-trash"></i>';
                header.appendChild(label);
                header.appendChild(removeDayBtn);

                const dayLocationsEl = document.createElement('div');
                dayLocationsEl.className = 'stay-day-locations';
                dayLocationsEl.dataset.dayKey = dayKey;
                const row = document.createElement('div');
                row.className = 'stay-location-row d-flex gap-2 align-items-center mb-2';
                row.appendChild(buildLocationField(`day_location_names[${dayKey}][]`));
                const rowRemoveBtn = buildRemoveButton('remove-stay-location-row');
                rowRemoveBtn.style.display = 'none';
                row.appendChild(rowRemoveBtn);
                dayLocationsEl.appendChild(row);

                const addLocBtn = document.createElement('button');
                addLocBtn.type = 'button';
                addLocBtn.className = 'btn btn-sm btn-light border add-day-location-row';
                addLocBtn.innerHTML = '<i class="bi bi-plus-lg"></i> Add Location';

                group.appendChild(header);
                group.appendChild(dayLocationsEl);
                group.appendChild(addLocBtn);
                container.appendChild(group);
                updateStayDayGroups(container);
                return;
            }

            // Multi-day tours: remove a whole day.
            const removeDayBtn = e.target.closest('.remove-stay-day');
            if (removeDayBtn) {
                const container = removeDayBtn.closest('[data-day-wise="1"]');
                removeDayBtn.closest('.stay-day-group').remove();
                updateStayDayGroups(container);
                return;
            }

            const removeBtn = e.target.closest('.remove-stay-location-row');
            if (removeBtn) {
                const dayLocationsEl = removeBtn.closest('.stay-day-locations');
                if (dayLocationsEl) {
                    // Multi-day: removing one location from within a day.
                    removeBtn.closest('.stay-location-row').remove();
                    updateDayLocationRemoveVisibility(dayLocationsEl);
                } else {
                    // Day tours: removing a stop from the flat list.
                    const container = removeBtn.closest('[id^="stay-rows-"]');
                    removeBtn.closest('.stay-location-row').remove();
                    updateStayRemoveVisibility(container);
                }
            }
        });

        document.getElementById('modal-create')?.addEventListener('shown.bs.modal', function () {
            updateHireSections('create');
            updateCustomerFields('create');
        });

        @foreach ($hires as $hire)
            document.getElementById('modal-edit-{{ $hire->id }}')?.addEventListener('shown.bs.modal', function () {
                updateHireSections('edit-{{ $hire->id }}');
                updateCustomerFields('edit-{{ $hire->id }}');
            });
        @endforeach
    </script>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
    <script>
        window.__hireTrackMaps = window.__hireTrackMaps || {};
        window.__hireTrackLayers = window.__hireTrackLayers || {};
        window.__hireTrackPollers = window.__hireTrackPollers || {};

        // Draws (or redraws) a hire's path from a fresh set of points —
        // cheap and simple to just clear and redraw for a single trip's
        // worth of points, rather than diffing. Only fits the map's view on
        // the very first render, so live updates don't yank the viewport
        // out from under an admin who's panned/zoomed to look at something.
        function renderHireTrackPoints(hireId, points) {
            const container = document.getElementById('map-track-' + hireId);
            if (!container) return;
            const emptyState = container.parentElement.querySelector('.track-empty-state');

            if (!points.length) {
                if (emptyState) emptyState.style.display = '';
                container.style.display = 'none';
                return;
            }

            if (emptyState) emptyState.style.display = 'none';
            container.style.display = '';

            let map = window.__hireTrackMaps[hireId];
            const isFirstRender = !map;

            if (isFirstRender) {
                map = L.map(container);
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '&copy; OpenStreetMap contributors',
                    maxZoom: 19,
                }).addTo(map);
                window.__hireTrackMaps[hireId] = map;
                window.__hireTrackLayers[hireId] = {};
            }

            const layers = window.__hireTrackLayers[hireId];
            ['polyline', 'startMarker', 'latestMarker', 'singleMarker'].forEach((key) => {
                if (layers[key]) {
                    map.removeLayer(layers[key]);
                    layers[key] = null;
                }
            });

            const latlngs = points.map((p) => [p.lat, p.lng]);

            if (latlngs.length === 1) {
                layers.singleMarker = L.marker(latlngs[0]).addTo(map).bindPopup('Point 1');
                if (isFirstRender) map.setView(latlngs[0], 15);
            } else {
                layers.polyline = L.polyline(latlngs, { color: '#4f46e5', weight: 4 }).addTo(map);
                layers.startMarker = L.circleMarker(latlngs[0], { radius: 7, color: '#059669', fillColor: '#059669', fillOpacity: 1 })
                    .addTo(map).bindPopup('Start');
                layers.latestMarker = L.circleMarker(latlngs[latlngs.length - 1], { radius: 7, color: '#dc2626', fillColor: '#dc2626', fillOpacity: 1 })
                    .addTo(map).bindPopup('Latest');
                if (isFirstRender) map.fitBounds(latlngs, { padding: [24, 24] });
            }

            if (isFirstRender) setTimeout(() => map.invalidateSize(), 150);
        }

        function updateHireTrackStats(hireId, data) {
            const modal = document.getElementById('modal-track-' + hireId);
            if (!modal) return;

            const statusEl = modal.querySelector('.track-status');
            if (statusEl) {
                statusEl.innerHTML = data.is_tracking
                    ? '<span class="text-success"><i class="bi bi-record-circle"></i> Active</span>'
                    : (data.status === 'pending' ? 'Not started' : 'Stopped');
            }
            const distanceEl = modal.querySelector('.track-distance');
            if (distanceEl) distanceEl.textContent = Number(data.total_distance_km).toFixed(2) + ' km';
            const countEl = modal.querySelector('.track-points-count');
            if (countEl) countEl.textContent = data.points.length;
            const liveBadge = modal.querySelector('.track-live-badge');
            if (liveBadge) liveBadge.style.display = data.is_tracking ? '' : 'none';
        }

        async function pollHireTracking(hireId, url) {
            try {
                const res = await fetch(url, { headers: { Accept: 'application/json' } });
                if (!res.ok) return;
                const data = await res.json();

                updateHireTrackStats(hireId, data);
                renderHireTrackPoints(hireId, data.points);

                // Nothing more will ever change for a completed hire —
                // stop polling it.
                if (data.status === 'completed' && window.__hireTrackPollers[hireId]) {
                    clearInterval(window.__hireTrackPollers[hireId]);
                    delete window.__hireTrackPollers[hireId];
                }
            } catch (e) {
                // Skip this tick — will retry on the next poll.
            }
        }

        @foreach ($hires as $hire)
            (function () {
                const hireId = {{ $hire->id }};
                const trackingUrl = @json(route('admin.hires.tracking', $hire));
                const modalEl = document.getElementById('modal-track-' + hireId);
                if (!modalEl) return;

                // Renders whatever the page already has instantly, then
                // starts polling for live updates while the modal is open.
                modalEl.addEventListener('shown.bs.modal', function () {
                    renderHireTrackPoints(hireId, @json($hire->trackingPoints->map(fn ($p) => ['lat' => $p->latitude, 'lng' => $p->longitude])->values()));

                    pollHireTracking(hireId, trackingUrl);
                    window.__hireTrackPollers[hireId] = setInterval(() => pollHireTracking(hireId, trackingUrl), 10000);
                });

                modalEl.addEventListener('hidden.bs.modal', function () {
                    if (window.__hireTrackPollers[hireId]) {
                        clearInterval(window.__hireTrackPollers[hireId]);
                        delete window.__hireTrackPollers[hireId];
                    }
                });
            })();
        @endforeach
    </script>
@endpush
