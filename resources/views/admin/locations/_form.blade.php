@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
    $lat = $isActive ? old('latitude') : $location?->latitude;
    $lng = $isActive ? old('longitude') : $location?->longitude;
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-name" class="form-label">Location</label>
        <input id="{{ $idPrefix }}-name" type="text" name="name" value="{{ $isActive ? old('name') : $location?->name }}"
            class="form-control @if ($formErrors->has('name')) is-invalid @endif" placeholder="e.g. Colombo Airport" required>
        @if ($formErrors->has('name'))
            <div class="invalid-feedback">{{ $formErrors->first('name') }}</div>
        @endif
    </div>

    <div class="col-md-3">
        <label for="{{ $idPrefix }}-latitude" class="form-label">Latitude</label>
        <input id="{{ $idPrefix }}-latitude" type="number" step="any" name="latitude" value="{{ $lat }}"
            class="form-control @if ($formErrors->has('latitude')) is-invalid @endif" placeholder="e.g. 6.9271" required>
        @if ($formErrors->has('latitude'))
            <div class="invalid-feedback">{{ $formErrors->first('latitude') }}</div>
        @endif
    </div>

    <div class="col-md-3">
        <label for="{{ $idPrefix }}-longitude" class="form-label">Longitude</label>
        <input id="{{ $idPrefix }}-longitude" type="number" step="any" name="longitude" value="{{ $lng }}"
            class="form-control @if ($formErrors->has('longitude')) is-invalid @endif" placeholder="e.g. 79.8612" required>
        @if ($formErrors->has('longitude'))
            <div class="invalid-feedback">{{ $formErrors->first('longitude') }}</div>
        @endif
    </div>

    <div class="col-12">
        <label for="{{ $idPrefix }}-description" class="form-label">Description</label>
        <textarea id="{{ $idPrefix }}-description" name="description" class="form-control @if ($formErrors->has('description')) is-invalid @endif" rows="2" placeholder="Additional details about this location...">{{ $isActive ? old('description') : $location?->description }}</textarea>
        @if ($formErrors->has('description'))
            <div class="invalid-feedback">{{ $formErrors->first('description') }}</div>
        @endif
    </div>

    <div class="col-12">
        <label class="form-label d-block">Pick location on map</label>
        <div id="map-{{ $idPrefix }}" class="location-map-picker"></div>
        <div class="form-text">Click on the map or drag the marker to set coordinates.</div>
    </div>
</div>
