@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();

    $tourType = $isActive ? old('tour_type') : $hire?->tour_type;
    $fromLocationId = $isActive ? old('from_location_id') : $hire?->fromLocation?->location_id;
    $toLocationId = $isActive ? old('to_location_id') : $hire?->toLocation?->location_id;
    $customerId = $isActive ? old('customer_id') : $hire?->customer_id;

    if ($isActive) {
        $stayLocationIds = old('stay_locations', []);
    } elseif ($hire) {
        $stayLocationIds = $hire->stayLocations->pluck('location_id')->all();
    } else {
        $stayLocationIds = [];
    }
    $stayLocationIds = array_values($stayLocationIds) ?: [''];

    // Multi-day tours: one group of locations per day — a day can hold
    // more than one location, in order.
    if ($isActive) {
        $dayLocationGroups = old('day_locations', []);
    } elseif ($hire) {
        $dayLocationGroups = $hire->stayLocationsByDay()
            ->map(fn ($group) => $group->pluck('location_id')->all())
            ->values()
            ->all();
    } else {
        $dayLocationGroups = [];
    }
    $dayLocationGroups = array_map(fn ($group) => array_values($group) ?: [''], $dayLocationGroups);
    $dayLocationGroups = $dayLocationGroups ?: [['']];

    // Custom location names typed against a "+ Add new location" selection,
    // only ever present on a validation-failure repost — a saved hire's
    // locations are always already-resolved ids by the time it's re-edited.
    $stayLocationNames = $isActive ? array_values(old('stay_location_names', [])) : [];
    $dayLocationNameGroups = $isActive ? old('day_location_names', []) : [];

    // Shared option list for every location <select> in this form — keeps
    // the "+ Add new location" escape hatch consistent everywhere locations
    // are picked (see resolveLocationId() in HireController).
    $locationSelectOptions = function ($selectedId) use ($locations) {
        $html = '<option value="">Select location</option>';
        foreach ($locations as $loc) {
            $selected = (string) $selectedId === (string) $loc->id ? ' selected' : '';
            $html .= '<option value="'.$loc->id.'"'.$selected.'>'.e($loc->name).'</option>';
        }
        $html .= '<option value="new"'.($selectedId === 'new' ? ' selected' : '').'>+ Add new location</option>';

        return $html;
    };
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="mb-3">
    <label for="{{ $idPrefix }}-tour_type" class="form-label">Tour Type</label>
    <select id="{{ $idPrefix }}-tour_type" name="tour_type" class="form-select hire-tour-type @if ($formErrors->has('tour_type')) is-invalid @endif" data-target="{{ $idPrefix }}" required>
        <option value="">Select tour type</option>
        @foreach (\App\Models\Hire::TOUR_TYPES as $value => $label)
            <option value="{{ $value }}" {{ $tourType === $value ? 'selected' : '' }}>{{ $label }}</option>
        @endforeach
    </select>
    @if ($formErrors->has('tour_type'))
        <div class="invalid-feedback">{{ $formErrors->first('tour_type') }}</div>
    @endif
</div>

<div data-hire-form="{{ $idPrefix }}">
    @if ($formErrors->has('new_location_name'))
        <div class="alert alert-danger py-2 px-3 small mb-2">{{ $formErrors->first('new_location_name') }}</div>
    @endif
    {{-- Drop and Pickup --}}
    <div class="border rounded-3 p-2 mb-2" data-tour-section="drop_pickup">
        <div class="fw-semibold mb-2" style="font-size: .8rem;">Drop and Pickup Locations</div>
        <div class="row g-2">
            <div class="col-md-6">
                <label class="form-label">From Location</label>
                <select name="from_location_id" class="form-select location-select @if ($formErrors->has('from_location_id')) is-invalid @endif">
                    {!! $locationSelectOptions($fromLocationId) !!}
                </select>
                <input type="text" name="new_from_location_name" class="form-control form-control-sm new-location-input mt-2"
                    value="{{ $isActive ? old('new_from_location_name') : '' }}" placeholder="Type the new location's name"
                    style="display: {{ (string) $fromLocationId === 'new' ? 'block' : 'none' }};">
                @if ($formErrors->has('from_location_id'))
                    <div class="invalid-feedback">{{ $formErrors->first('from_location_id') }}</div>
                @endif
            </div>
            <div class="col-md-6">
                <label class="form-label">To Location</label>
                <select name="to_location_id" class="form-select location-select @if ($formErrors->has('to_location_id')) is-invalid @endif">
                    {!! $locationSelectOptions($toLocationId) !!}
                </select>
                <input type="text" name="new_to_location_name" class="form-control form-control-sm new-location-input mt-2"
                    value="{{ $isActive ? old('new_to_location_name') : '' }}" placeholder="Type the new location's name"
                    style="display: {{ (string) $toLocationId === 'new' ? 'block' : 'none' }};">
                @if ($formErrors->has('to_location_id'))
                    <div class="invalid-feedback">{{ $formErrors->first('to_location_id') }}</div>
                @endif
            </div>
        </div>
    </div>

    {{-- Multi day tours --}}
    <div class="border rounded-3 p-2 mb-2" data-tour-section="multi_day">
        <div class="fw-semibold mb-2" style="font-size: .8rem;">Tour Locations — Day by Day</div>
        <div class="text-muted mb-2" style="font-size: .72rem;">Add a day, then add one or more locations visited that day, in order.</div>
        @if ($formErrors->has('day_locations') && $tourType === 'multi_day')
            <div class="text-danger small mb-2">{{ $formErrors->first('day_locations') }}</div>
        @endif
        <div id="day-groups-{{ $idPrefix }}" data-day-wise="1" data-next-day-key="{{ count($dayLocationGroups) }}">
            @foreach ($dayLocationGroups as $dayIndex => $dayLocationIds)
                <div class="stay-day-group border rounded-2 p-2 mb-2">
                    <div class="d-flex align-items-center justify-content-between mb-2">
                        <span class="badge rounded-pill bg-primary-subtle text-primary-emphasis day-label">Day {{ $dayIndex + 1 }}</span>
                        <button type="button" class="btn btn-sm btn-light border btn-icon text-danger remove-stay-day" {{ count($dayLocationGroups) <= 1 ? 'style=display:none' : '' }}>
                            <i class="bi bi-trash"></i>
                        </button>
                    </div>
                    <div class="stay-day-locations" data-day-key="{{ $dayIndex }}">
                        @foreach ($dayLocationIds as $locIndex => $locId)
                            @php $dayLocName = $dayLocationNameGroups[$dayIndex][$locIndex] ?? ''; @endphp
                            <div class="stay-location-row d-flex gap-2 align-items-center mb-2">
                                <div class="flex-grow-1">
                                    <select name="day_locations[{{ $dayIndex }}][]" class="form-select form-select-sm location-select">
                                        {!! $locationSelectOptions($locId) !!}
                                    </select>
                                    <input type="text" name="day_location_names[{{ $dayIndex }}][]" class="form-control form-control-sm new-location-input mt-1"
                                        value="{{ $dayLocName }}" placeholder="Type the new location's name"
                                        style="display: {{ (string) $locId === 'new' ? 'block' : 'none' }};">
                                </div>
                                <button type="button" class="btn btn-sm btn-light border btn-icon text-danger remove-stay-location-row" {{ count($dayLocationIds) <= 1 ? 'style=display:none' : '' }}>
                                    <i class="bi bi-x-lg"></i>
                                </button>
                            </div>
                        @endforeach
                    </div>
                    <button type="button" class="btn btn-sm btn-light border add-day-location-row">
                        <i class="bi bi-plus-lg"></i> Add Location
                    </button>
                </div>
            @endforeach
        </div>
        <button type="button" class="btn btn-sm btn-primary add-stay-day" data-container="day-groups-{{ $idPrefix }}">
            <i class="bi bi-plus-lg"></i> Add Day
        </button>
    </div>

    {{-- Day tours --}}
    <div class="border rounded-3 p-2 mb-2" data-tour-section="day_tour">
        <div class="fw-semibold mb-2" style="font-size: .8rem;">Day Tour</div>
        <div class="row g-2 mb-2">
            <div class="col-md-6">
                <label class="form-label">From</label>
                <select name="from_location_id" class="form-select location-select @if ($formErrors->has('from_location_id')) is-invalid @endif">
                    {!! $locationSelectOptions($fromLocationId) !!}
                </select>
                <input type="text" name="new_from_location_name" class="form-control form-control-sm new-location-input mt-2"
                    value="{{ $isActive ? old('new_from_location_name') : '' }}" placeholder="Type the new location's name"
                    style="display: {{ (string) $fromLocationId === 'new' ? 'block' : 'none' }};">
            </div>
            <div class="col-md-6">
                <label class="form-label">To</label>
                <select name="to_location_id" class="form-select location-select @if ($formErrors->has('to_location_id')) is-invalid @endif">
                    {!! $locationSelectOptions($toLocationId) !!}
                </select>
                <input type="text" name="new_to_location_name" class="form-control form-control-sm new-location-input mt-2"
                    value="{{ $isActive ? old('new_to_location_name') : '' }}" placeholder="Type the new location's name"
                    style="display: {{ (string) $toLocationId === 'new' ? 'block' : 'none' }};">
            </div>
        </div>
        <div class="fw-semibold mb-2" style="font-size: .8rem;">Stay Locations</div>
        @if ($formErrors->has('stay_locations') && $tourType === 'day_tour')
            <div class="text-danger small mb-2">{{ $formErrors->first('stay_locations') }}</div>
        @endif
        <div id="stay-rows-{{ $idPrefix }}-day">
            @foreach ($stayLocationIds as $locIndex => $locId)
                <div class="stay-location-row d-flex gap-2 align-items-center mb-2">
                    <div class="flex-grow-1">
                        <select name="stay_locations[]" class="form-select form-select-sm location-select">
                            {!! $locationSelectOptions($locId) !!}
                        </select>
                        <input type="text" name="stay_location_names[]" class="form-control form-control-sm new-location-input mt-1"
                            value="{{ $stayLocationNames[$locIndex] ?? '' }}" placeholder="Type the new location's name"
                            style="display: {{ (string) $locId === 'new' ? 'block' : 'none' }};">
                    </div>
                    <button type="button" class="btn btn-sm btn-light border btn-icon text-danger remove-stay-location-row" {{ count($stayLocationIds) <= 1 ? 'style=display:none' : '' }}>
                        <i class="bi bi-x-lg"></i>
                    </button>
                </div>
            @endforeach
        </div>
        <button type="button" class="btn btn-sm btn-light border add-stay-location-row" data-container="stay-rows-{{ $idPrefix }}-day">
            <i class="bi bi-plus-lg"></i> Add Location
        </button>
    </div>

    {{-- Packages --}}
    <div class="border rounded-3 p-2 mb-2" data-tour-section="package">
        <div class="fw-semibold mb-2" style="font-size: .8rem;">Package</div>
        <div class="row g-2">
            <div class="col-12">
                <label class="form-label">Package Selection</label>
                <select name="package_id" class="form-select @if ($formErrors->has('package_id')) is-invalid @endif">
                    <option value="">Select package</option>
                    @foreach ($packages as $pkg)
                        <option value="{{ $pkg->id }}" {{ (string) ($isActive ? old('package_id') : $hire?->package_id) === (string) $pkg->id ? 'selected' : '' }}>{{ $pkg->name }}</option>
                    @endforeach
                </select>
                @if ($formErrors->has('package_id'))
                    <div class="invalid-feedback">{{ $formErrors->first('package_id') }}</div>
                @endif
            </div>
            <div class="col-md-6">
                <label class="form-label">Start Time</label>
                <input type="datetime-local" name="start_time" class="form-control @if ($formErrors->has('start_time')) is-invalid @endif"
                    value="{{ $isActive ? old('start_time') : $hire?->start_time?->format('Y-m-d\TH:i') }}">
                @if ($formErrors->has('start_time'))
                    <div class="invalid-feedback">{{ $formErrors->first('start_time') }}</div>
                @endif
            </div>
            <div class="col-md-6">
                <label class="form-label">End Time</label>
                <input type="datetime-local" name="end_time" class="form-control @if ($formErrors->has('end_time')) is-invalid @endif"
                    value="{{ $isActive ? old('end_time') : $hire?->end_time?->format('Y-m-d\TH:i') }}">
                @if ($formErrors->has('end_time'))
                    <div class="invalid-feedback">{{ $formErrors->first('end_time') }}</div>
                @endif
            </div>
        </div>
    </div>
</div>

<div class="border rounded-3 p-2 mb-2">
    <div class="fw-semibold mb-2" style="font-size: .8rem;">Financials</div>
    <div class="row g-2">
        <div class="col-md-4">
            <label for="{{ $idPrefix }}-hire_full_value" class="form-label">Hire Full Value</label>
            <input id="{{ $idPrefix }}-hire_full_value" type="number" min="0" step="0.01" name="hire_full_value"
                value="{{ $isActive ? old('hire_full_value') : $hire?->hire_full_value }}"
                class="form-control hire-value-input @if ($formErrors->has('hire_full_value')) is-invalid @endif" data-target="{{ $idPrefix }}" placeholder="e.g. 100.00" required>
            @if ($formErrors->has('hire_full_value'))
                <div class="invalid-feedback">{{ $formErrors->first('hire_full_value') }}</div>
            @endif
        </div>
        <div class="col-md-4">
            <label for="{{ $idPrefix }}-our_hire_value" class="form-label">Our Hire Value</label>
            <input id="{{ $idPrefix }}-our_hire_value" type="number" min="0" step="0.01" name="our_hire_value"
                value="{{ $isActive ? old('our_hire_value') : $hire?->our_hire_value }}"
                class="form-control hire-value-input @if ($formErrors->has('our_hire_value')) is-invalid @endif" data-target="{{ $idPrefix }}" placeholder="e.g. 80.00" required>
            @if ($formErrors->has('our_hire_value'))
                <div class="invalid-feedback">{{ $formErrors->first('our_hire_value') }}</div>
            @endif
        </div>
        <div class="col-md-4">
            <label class="form-label">Commission</label>
            <div class="form-control bg-light" id="{{ $idPrefix }}-commission-display">{{ number_format($hire?->commission ?? 0, 2) }}</div>
        </div>
    </div>
</div>

<div class="border rounded-3 p-2 mb-2">
    <div class="fw-semibold mb-2" style="font-size: .8rem;">Customer</div>
    <div class="row g-2">
        <div class="col-12">
            <label for="{{ $idPrefix }}-customer_id" class="form-label">Select Customer</label>
            <select id="{{ $idPrefix }}-customer_id" name="customer_id" class="form-select hire-customer-select @if ($formErrors->has('customer_id')) is-invalid @endif" data-target="{{ $idPrefix }}" required>
                <option value="">Select customer</option>
                <option value="new" {{ (string) $customerId === 'new' ? 'selected' : '' }}>+ Add a new customer</option>
                @foreach ($customers as $cust)
                    <option value="{{ $cust->id }}" {{ (string) $customerId === (string) $cust->id ? 'selected' : '' }}>{{ $cust->name }} — {{ $cust->phone }}</option>
                @endforeach
            </select>
            @if ($formErrors->has('customer_id'))
                <div class="invalid-feedback">{{ $formErrors->first('customer_id') }}</div>
            @endif
        </div>

        <div class="col-md-6 hire-new-customer-field" data-new-customer="{{ $idPrefix }}" style="display: none;">
            <label for="{{ $idPrefix }}-new_customer_name" class="form-label">New Customer Name</label>
            <input id="{{ $idPrefix }}-new_customer_name" type="text" name="new_customer_name" value="{{ $isActive ? old('new_customer_name') : '' }}"
                class="form-control @if ($formErrors->has('new_customer_name')) is-invalid @endif" placeholder="Customer full name">
            @if ($formErrors->has('new_customer_name'))
                <div class="invalid-feedback">{{ $formErrors->first('new_customer_name') }}</div>
            @endif
        </div>
        <div class="col-md-6 hire-new-customer-field" data-new-customer="{{ $idPrefix }}" style="display: none;">
            <label for="{{ $idPrefix }}-new_customer_phone" class="form-label">New Customer Phone</label>
            <input id="{{ $idPrefix }}-new_customer_phone" type="text" name="new_customer_phone" value="{{ $isActive ? old('new_customer_phone') : '' }}"
                class="form-control @if ($formErrors->has('new_customer_phone')) is-invalid @endif" placeholder="+94 71 234 5678">
            @if ($formErrors->has('new_customer_phone'))
                <div class="invalid-feedback">{{ $formErrors->first('new_customer_phone') }}</div>
            @endif
        </div>
    </div>
</div>

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-driver_id" class="form-label">Driver</label>
        <select id="{{ $idPrefix }}-driver_id" name="driver_id" class="form-select @if ($formErrors->has('driver_id')) is-invalid @endif">
            <option value="">Select driver</option>
            @foreach ($drivers as $drv)
                <option value="{{ $drv->id }}" {{ (string) ($isActive ? old('driver_id') : $hire?->driver_id) === (string) $drv->id ? 'selected' : '' }}>{{ $drv->name }}</option>
            @endforeach
        </select>
        @if ($formErrors->has('driver_id'))
            <div class="invalid-feedback">{{ $formErrors->first('driver_id') }}</div>
        @endif
    </div>
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-vehicle_id" class="form-label">Vehicle</label>
        <select id="{{ $idPrefix }}-vehicle_id" name="vehicle_id" class="form-select @if ($formErrors->has('vehicle_id')) is-invalid @endif">
            <option value="">Select vehicle</option>
            @foreach ($vehicles as $veh)
                <option value="{{ $veh->id }}" {{ (string) ($isActive ? old('vehicle_id') : $hire?->vehicle_id) === (string) $veh->id ? 'selected' : '' }}>{{ $veh->model }}</option>
            @endforeach
        </select>
        @if ($formErrors->has('vehicle_id'))
            <div class="invalid-feedback">{{ $formErrors->first('vehicle_id') }}</div>
        @endif
    </div>

    <div class="col-12">
        <label for="{{ $idPrefix }}-description" class="form-label">Description</label>
        <textarea id="{{ $idPrefix }}-description" name="description" class="form-control @if ($formErrors->has('description')) is-invalid @endif" rows="2" placeholder="Additional details about this hire...">{{ $isActive ? old('description') : $hire?->description }}</textarea>
        @if ($formErrors->has('description'))
            <div class="invalid-feedback">{{ $formErrors->first('description') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-payment_type" class="form-label">Payment Type</label>
        @php $paymentType = $isActive ? old('payment_type') : $hire?->payment_type; @endphp
        <select id="{{ $idPrefix }}-payment_type" name="payment_type" class="form-select @if ($formErrors->has('payment_type')) is-invalid @endif" required>
            <option value="">Select payment type</option>
            @foreach (\App\Models\Hire::PAYMENT_TYPES as $value => $label)
                <option value="{{ $value }}" {{ $paymentType === $value ? 'selected' : '' }}>{{ $label }}</option>
            @endforeach
        </select>
        @if ($formErrors->has('payment_type'))
            <div class="invalid-feedback">{{ $formErrors->first('payment_type') }}</div>
        @endif
    </div>
</div>
