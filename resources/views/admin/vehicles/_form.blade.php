@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-model" class="form-label">Model</label>
        <input id="{{ $idPrefix }}-model" type="text" name="model" value="{{ $isActive ? old('model') : $vehicle?->model }}"
            class="form-control @if ($formErrors->has('model')) is-invalid @endif" placeholder="e.g. Toyota Hiace" required>
        @if ($formErrors->has('model'))
            <div class="invalid-feedback">{{ $formErrors->first('model') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-condition" class="form-label">Condition</label>
        @php $selectedCondition = $isActive ? old('condition') : $vehicle?->condition; @endphp
        <select id="{{ $idPrefix }}-condition" name="condition" class="form-select @if ($formErrors->has('condition')) is-invalid @endif" required>
            <option value="">Select condition</option>
            @foreach ($conditions as $condition)
                <option value="{{ $condition }}" {{ $selectedCondition === $condition ? 'selected' : '' }}>{{ $condition }}</option>
            @endforeach
        </select>
        @if ($formErrors->has('condition'))
            <div class="invalid-feedback">{{ $formErrors->first('condition') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-seats" class="form-label">Seats</label>
        <input id="{{ $idPrefix }}-seats" type="number" name="seats" value="{{ $isActive ? old('seats') : $vehicle?->seats }}"
            class="form-control @if ($formErrors->has('seats')) is-invalid @endif" min="1" max="100" placeholder="e.g. 4" required>
        @if ($formErrors->has('seats'))
            <div class="invalid-feedback">{{ $formErrors->first('seats') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-pax" class="form-label">PAX</label>
        <input id="{{ $idPrefix }}-pax" type="number" name="pax" value="{{ $isActive ? old('pax') : $vehicle?->pax }}"
            class="form-control @if ($formErrors->has('pax')) is-invalid @endif" min="1" max="100" placeholder="e.g. 4" required>
        @if ($formErrors->has('pax'))
            <div class="invalid-feedback">{{ $formErrors->first('pax') }}</div>
        @else
            <div class="form-text">Maximum passenger capacity.</div>
        @endif
    </div>

    <div class="col-12">
        <label for="{{ $idPrefix }}-description" class="form-label">Description</label>
        <textarea id="{{ $idPrefix }}-description" name="description" class="form-control @if ($formErrors->has('description')) is-invalid @endif" rows="3" placeholder="Additional details about this vehicle...">{{ $isActive ? old('description') : $vehicle?->description }}</textarea>
        @if ($formErrors->has('description'))
            <div class="invalid-feedback">{{ $formErrors->first('description') }}</div>
        @endif
    </div>
</div>
