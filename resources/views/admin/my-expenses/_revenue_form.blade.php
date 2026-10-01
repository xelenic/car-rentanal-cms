@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
    $field = fn (string $name) => $isActive ? old($name) : $revenue?->{$name};
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-hire" class="form-label">Hire</label>
        <input id="{{ $idPrefix }}-hire" type="text" name="hire" value="{{ $field('hire') }}"
            class="form-control @if ($formErrors->has('hire')) is-invalid @endif" placeholder="e.g. Colombo to Kandy" maxlength="255" required>
        @if ($formErrors->has('hire'))
            <div class="invalid-feedback">{{ $formErrors->first('hire') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-booking-number" class="form-label">Booking Number</label>
        <input id="{{ $idPrefix }}-booking-number" type="text" name="booking_number" value="{{ $field('booking_number') }}"
            class="form-control @if ($formErrors->has('booking_number')) is-invalid @endif" placeholder="Their booking reference" maxlength="100" required>
        @if ($formErrors->has('booking_number'))
            <div class="invalid-feedback">{{ $formErrors->first('booking_number') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-vehicle" class="form-label">Vehicle</label>
        <input id="{{ $idPrefix }}-vehicle" type="text" name="vehicle" value="{{ $field('vehicle') }}"
            class="form-control @if ($formErrors->has('vehicle')) is-invalid @endif" placeholder="e.g. Toyota Aqua — ABC-1234" maxlength="255" required>
        @if ($formErrors->has('vehicle'))
            <div class="invalid-feedback">{{ $formErrors->first('vehicle') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-date" class="form-label">Date</label>
        <input id="{{ $idPrefix }}-date" type="date" name="revenue_date"
            value="{{ $isActive ? old('revenue_date') : ($revenue?->revenue_date?->format('Y-m-d') ?? $defaultDate) }}"
            class="form-control @if ($formErrors->has('revenue_date')) is-invalid @endif" required>
        @if ($formErrors->has('revenue_date'))
            <div class="invalid-feedback">{{ $formErrors->first('revenue_date') }}</div>
        @else
            <div class="form-text">Counts toward this date's month.</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-full-amount" class="form-label">Full Amount (Rs.)</label>
        <input id="{{ $idPrefix }}-full-amount" type="number" step="0.01" min="0" name="full_amount" value="{{ $field('full_amount') }}"
            class="form-control @if ($formErrors->has('full_amount')) is-invalid @endif" placeholder="0.00" required>
        @if ($formErrors->has('full_amount'))
            <div class="invalid-feedback">{{ $formErrors->first('full_amount') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-credited-amount" class="form-label">Credited Amount (Rs.)</label>
        <input id="{{ $idPrefix }}-credited-amount" type="number" step="0.01" min="0" name="credited_amount" value="{{ $field('credited_amount') }}"
            class="form-control @if ($formErrors->has('credited_amount')) is-invalid @endif" placeholder="0.00" required>
        @if ($formErrors->has('credited_amount'))
            <div class="invalid-feedback">{{ $formErrors->first('credited_amount') }}</div>
        @else
            <div class="form-text">Counts toward My Profit.</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-balance" class="form-label">Balance (Rs.)</label>
        <input id="{{ $idPrefix }}-balance" type="number" step="0.01" name="balance" value="{{ $field('balance') }}"
            class="form-control @if ($formErrors->has('balance')) is-invalid @endif" placeholder="0.00" required>
        @if ($formErrors->has('balance'))
            <div class="invalid-feedback">{{ $formErrors->first('balance') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-vehicle-amount" class="form-label">Vehicle Amount (Rs.)</label>
        <input id="{{ $idPrefix }}-vehicle-amount" type="number" step="0.01" min="0" name="vehicle_amount" value="{{ $field('vehicle_amount') }}"
            class="form-control @if ($formErrors->has('vehicle_amount')) is-invalid @endif" placeholder="0.00" required>
        @if ($formErrors->has('vehicle_amount'))
            <div class="invalid-feedback">{{ $formErrors->first('vehicle_amount') }}</div>
        @endif
    </div>
</div>
