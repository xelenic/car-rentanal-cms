@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();

    if ($isActive) {
        $itineraryRows = old('itinerary', []);
    } elseif ($package) {
        $itineraryRows = $package->itineraries->map(fn ($stop) => [
            'location_id' => $stop->location_id,
            'note' => $stop->note,
        ])->all();
    } else {
        $itineraryRows = [['location_id' => '', 'note' => '']];
    }
    $itineraryRows = array_values($itineraryRows) ?: [['location_id' => '', 'note' => '']];
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-name" class="form-label">Package Name</label>
        <input id="{{ $idPrefix }}-name" type="text" name="name" value="{{ $isActive ? old('name') : $package?->name }}"
            class="form-control @if ($formErrors->has('name')) is-invalid @endif" placeholder="e.g. Half Day City Tour" required>
        @if ($formErrors->has('name'))
            <div class="invalid-feedback">{{ $formErrors->first('name') }}</div>
        @endif
    </div>

    <div class="col-md-3">
        <label for="{{ $idPrefix }}-hours" class="form-label">Hours</label>
        <input id="{{ $idPrefix }}-hours" type="number" min="1" step="1" name="hours" value="{{ $isActive ? old('hours') : $package?->hours }}"
            class="form-control @if ($formErrors->has('hours')) is-invalid @endif" placeholder="e.g. 4" required>
        @if ($formErrors->has('hours'))
            <div class="invalid-feedback">{{ $formErrors->first('hours') }}</div>
        @endif
    </div>

    <div class="col-md-3">
        <label for="{{ $idPrefix }}-price" class="form-label">Price</label>
        <input id="{{ $idPrefix }}-price" type="number" min="0" step="0.01" name="price" value="{{ $isActive ? old('price') : $package?->price }}"
            class="form-control @if ($formErrors->has('price')) is-invalid @endif" placeholder="e.g. 50.00" required>
        @if ($formErrors->has('price'))
            <div class="invalid-feedback">{{ $formErrors->first('price') }}</div>
        @endif
    </div>

    <div class="col-12">
        <label class="form-label d-block">Itinerary</label>

        @if ($formErrors->has('itinerary'))
            <div class="text-danger small mb-2">{{ $formErrors->first('itinerary') }}</div>
        @endif

        <div id="itinerary-rows-{{ $idPrefix }}">
            @foreach ($itineraryRows as $i => $row)
                @php $rowError = $formErrors->first("itinerary.$i.location_id"); @endphp
                <div class="itinerary-row d-flex gap-2 align-items-start mb-2">
                    <span class="text-muted small pt-2" style="width: 1.25rem;">{{ $i + 1 }}.</span>
                    <select name="itinerary[{{ $i }}][location_id]" class="form-select form-select-sm @if ($rowError) is-invalid @endif" required>
                        <option value="">Select location</option>
                        @foreach ($locations as $loc)
                            <option value="{{ $loc->id }}" {{ (string) ($row['location_id'] ?? '') === (string) $loc->id ? 'selected' : '' }}>{{ $loc->name }}</option>
                        @endforeach
                    </select>
                    <input type="text" name="itinerary[{{ $i }}][note]" value="{{ $row['note'] ?? '' }}" class="form-control form-control-sm" placeholder="Note (optional)">
                    <button type="button" class="btn btn-sm btn-light border btn-icon text-danger remove-itinerary-row" {{ count($itineraryRows) <= 1 ? 'style=display:none' : '' }}>
                        <i class="bi bi-x-lg"></i>
                    </button>
                </div>
                @if ($rowError)
                    <div class="text-danger small mb-2" style="margin-left: 1.5rem;">{{ $rowError }}</div>
                @endif
            @endforeach
        </div>
        <button type="button" class="btn btn-sm btn-light border add-itinerary-row" data-prefix="{{ $idPrefix }}" data-next-index="{{ count($itineraryRows) }}">
            <i class="bi bi-plus-lg"></i> Add Stop
        </button>
    </div>
</div>
