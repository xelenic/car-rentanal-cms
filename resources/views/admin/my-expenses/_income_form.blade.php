@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-12">
        <label for="{{ $idPrefix }}-title" class="form-label">Income</label>
        <input id="{{ $idPrefix }}-title" type="text" name="title" value="{{ $isActive ? old('title') : $income?->title }}"
            class="form-control @if ($formErrors->has('title')) is-invalid @endif" placeholder="e.g. Shop rent received" maxlength="255" required>
        @if ($formErrors->has('title'))
            <div class="invalid-feedback">{{ $formErrors->first('title') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-amount" class="form-label">Amount (Rs.)</label>
        <input id="{{ $idPrefix }}-amount" type="number" step="0.01" min="0.01" name="amount" value="{{ $isActive ? old('amount') : $income?->amount }}"
            class="form-control @if ($formErrors->has('amount')) is-invalid @endif" placeholder="0.00" required>
        @if ($formErrors->has('amount'))
            <div class="invalid-feedback">{{ $formErrors->first('amount') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-date" class="form-label">Date</label>
        <input id="{{ $idPrefix }}-date" type="date" name="income_date"
            value="{{ $isActive ? old('income_date') : ($income?->income_date?->format('Y-m-d') ?? $defaultDate) }}"
            class="form-control @if ($formErrors->has('income_date')) is-invalid @endif" required>
        @if ($formErrors->has('income_date'))
            <div class="invalid-feedback">{{ $formErrors->first('income_date') }}</div>
        @else
            <div class="form-text">Counts toward this date's month.</div>
        @endif
    </div>

    <div class="col-12">
        <label for="{{ $idPrefix }}-notes" class="form-label">Notes</label>
        <textarea id="{{ $idPrefix }}-notes" name="notes" rows="2" maxlength="2000"
            class="form-control @if ($formErrors->has('notes')) is-invalid @endif" placeholder="Optional details…">{{ $isActive ? old('notes') : $income?->notes }}</textarea>
        @if ($formErrors->has('notes'))
            <div class="invalid-feedback">{{ $formErrors->first('notes') }}</div>
        @endif
    </div>
</div>
