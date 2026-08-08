@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();

    $field = fn (string $name, $default = null) => $isActive ? old($name) : ($leasing?->{$name} ?? $default);
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-vehicle_id" class="form-label">Vehicle</label>
        <select id="{{ $idPrefix }}-vehicle_id" name="vehicle_id" class="form-select @if ($formErrors->has('vehicle_id')) is-invalid @endif" required>
            <option value="">Select vehicle</option>
            @foreach ($vehicles as $veh)
                <option value="{{ $veh->id }}" {{ (string) $field('vehicle_id') === (string) $veh->id ? 'selected' : '' }}>{{ $veh->model }}</option>
            @endforeach
        </select>
        @if ($formErrors->has('vehicle_id'))
            <div class="invalid-feedback">{{ $formErrors->first('vehicle_id') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-type" class="form-label">Type</label>
        <select id="{{ $idPrefix }}-type" name="type" class="form-select @if ($formErrors->has('type')) is-invalid @endif" required>
            @foreach ($types as $key => $label)
                <option value="{{ $key }}" {{ ($field('type', 'leasing')) === $key ? 'selected' : '' }}>{{ $label }}</option>
            @endforeach
        </select>
        @if ($formErrors->has('type'))
            <div class="invalid-feedback">{{ $formErrors->first('type') }}</div>
        @else
            <div class="form-text">Leasing: finance company holds ownership. Loan: vehicle owned outright.</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-company" class="form-label">Finance Company</label>
        <input id="{{ $idPrefix }}-company" type="text" name="company" value="{{ $field('company') }}"
            class="form-control @if ($formErrors->has('company')) is-invalid @endif" placeholder="e.g. LOLC Finance" required>
        @if ($formErrors->has('company'))
            <div class="invalid-feedback">{{ $formErrors->first('company') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-agreement_number" class="form-label">Agreement / Card Number</label>
        <input id="{{ $idPrefix }}-agreement_number" type="text" name="agreement_number" value="{{ $field('agreement_number') }}"
            class="form-control @if ($formErrors->has('agreement_number')) is-invalid @endif" placeholder="e.g. LC-2026-0451">
        @if ($formErrors->has('agreement_number'))
            <div class="invalid-feedback">{{ $formErrors->first('agreement_number') }}</div>
        @endif
    </div>

    <div class="col-md-4">
        <label for="{{ $idPrefix }}-loan_amount" class="form-label">Loan Amount</label>
        <input id="{{ $idPrefix }}-loan_amount" type="number" min="0" step="0.01" name="loan_amount" value="{{ $field('loan_amount') }}"
            class="form-control leasing-amount-input @if ($formErrors->has('loan_amount')) is-invalid @endif" data-target="{{ $idPrefix }}" placeholder="e.g. 2500000.00" required>
        @if ($formErrors->has('loan_amount'))
            <div class="invalid-feedback">{{ $formErrors->first('loan_amount') }}</div>
        @endif
    </div>

    <div class="col-md-4">
        <label for="{{ $idPrefix }}-monthly_installment" class="form-label">Monthly Installment</label>
        <input id="{{ $idPrefix }}-monthly_installment" type="number" min="0" step="0.01" name="monthly_installment" value="{{ $field('monthly_installment') }}"
            class="form-control @if ($formErrors->has('monthly_installment')) is-invalid @endif" placeholder="e.g. 85000.00" required>
        @if ($formErrors->has('monthly_installment'))
            <div class="invalid-feedback">{{ $formErrors->first('monthly_installment') }}</div>
        @endif
    </div>

    <div class="col-md-4">
        <label for="{{ $idPrefix }}-interest_rate" class="form-label">Interest Rate (%)</label>
        <input id="{{ $idPrefix }}-interest_rate" type="number" min="0" max="100" step="0.01" name="interest_rate" value="{{ $field('interest_rate') }}"
            class="form-control @if ($formErrors->has('interest_rate')) is-invalid @endif" placeholder="e.g. 14.5">
        @if ($formErrors->has('interest_rate'))
            <div class="invalid-feedback">{{ $formErrors->first('interest_rate') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-balance_remaining" class="form-label">Balance Remaining</label>
        <input id="{{ $idPrefix }}-balance_remaining" type="number" min="0" step="0.01" name="balance_remaining"
            value="{{ $isActive ? old('balance_remaining') : ($leasing->balance_remaining ?? '') }}"
            class="form-control @if ($formErrors->has('balance_remaining')) is-invalid @endif" placeholder="Defaults to the loan amount">
        @if ($formErrors->has('balance_remaining'))
            <div class="invalid-feedback">{{ $formErrors->first('balance_remaining') }}</div>
        @else
            <div class="form-text">Leave blank on creation to start at the full loan amount.</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-status" class="form-label">Status</label>
        <select id="{{ $idPrefix }}-status" name="status" class="form-select @if ($formErrors->has('status')) is-invalid @endif" required>
            @foreach ($statuses as $key => $label)
                <option value="{{ $key }}" {{ ($field('status', 'active')) === $key ? 'selected' : '' }}>{{ $label }}</option>
            @endforeach
        </select>
        @if ($formErrors->has('status'))
            <div class="invalid-feedback">{{ $formErrors->first('status') }}</div>
        @endif
    </div>

    <div class="col-md-4">
        <label for="{{ $idPrefix }}-start_date" class="form-label">Start Date</label>
        <input id="{{ $idPrefix }}-start_date" type="date" name="start_date"
            value="{{ $isActive ? old('start_date') : $leasing?->start_date?->format('Y-m-d') }}"
            class="form-control @if ($formErrors->has('start_date')) is-invalid @endif" required>
        @if ($formErrors->has('start_date'))
            <div class="invalid-feedback">{{ $formErrors->first('start_date') }}</div>
        @endif
    </div>

    <div class="col-md-4">
        <label for="{{ $idPrefix }}-term_months" class="form-label">Term (Months)</label>
        <input id="{{ $idPrefix }}-term_months" type="number" min="1" name="term_months" value="{{ $field('term_months') }}"
            class="form-control @if ($formErrors->has('term_months')) is-invalid @endif" placeholder="e.g. 48">
        @if ($formErrors->has('term_months'))
            <div class="invalid-feedback">{{ $formErrors->first('term_months') }}</div>
        @endif
    </div>

    <div class="col-md-4">
        <label for="{{ $idPrefix }}-end_date" class="form-label">End Date</label>
        <input id="{{ $idPrefix }}-end_date" type="date" name="end_date"
            value="{{ $isActive ? old('end_date') : $leasing?->end_date?->format('Y-m-d') }}"
            class="form-control @if ($formErrors->has('end_date')) is-invalid @endif">
        @if ($formErrors->has('end_date'))
            <div class="invalid-feedback">{{ $formErrors->first('end_date') }}</div>
        @endif
    </div>

    <div class="col-12">
        <label for="{{ $idPrefix }}-notes" class="form-label">Notes</label>
        <textarea id="{{ $idPrefix }}-notes" name="notes" class="form-control @if ($formErrors->has('notes')) is-invalid @endif" rows="2" placeholder="Additional details...">{{ $field('notes') }}</textarea>
        @if ($formErrors->has('notes'))
            <div class="invalid-feedback">{{ $formErrors->first('notes') }}</div>
        @endif
    </div>
</div>
