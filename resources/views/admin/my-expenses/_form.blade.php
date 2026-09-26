@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
    $selectedCategory = $isActive ? old('category') : ($expense?->category ?? $defaultCategory);
    $addingCategory = $selectedCategory === \App\Models\MyExpenseCategory::NEW_OPTION;
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-12">
        <label for="{{ $idPrefix }}-title" class="form-label">Expense</label>
        <input id="{{ $idPrefix }}-title" type="text" name="title" value="{{ $isActive ? old('title') : $expense?->title }}"
            class="form-control @if ($formErrors->has('title')) is-invalid @endif" placeholder="e.g. Office rent" maxlength="255" required>
        @if ($formErrors->has('title'))
            <div class="invalid-feedback">{{ $formErrors->first('title') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-category" class="form-label">Category</label>
        <select id="{{ $idPrefix }}-category" name="category" data-category-select="{{ $idPrefix }}"
            class="form-select @if ($formErrors->has('category')) is-invalid @endif" required>
            @foreach ($categories as $key => $label)
                <option value="{{ $key }}" {{ $selectedCategory === $key ? 'selected' : '' }}>{{ $label }}</option>
            @endforeach
            @can('my-expenses.create')
                <option value="{{ \App\Models\MyExpenseCategory::NEW_OPTION }}" {{ $addingCategory ? 'selected' : '' }}>＋ Add new category…</option>
            @endcan
        </select>
        @if ($formErrors->has('category'))
            <div class="invalid-feedback">{{ $formErrors->first('category') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-amount" class="form-label">Amount (Rs.)</label>
        <input id="{{ $idPrefix }}-amount" type="number" step="0.01" min="0.01" name="amount" value="{{ $isActive ? old('amount') : $expense?->amount }}"
            class="form-control @if ($formErrors->has('amount')) is-invalid @endif" placeholder="0.00" required>
        @if ($formErrors->has('amount'))
            <div class="invalid-feedback">{{ $formErrors->first('amount') }}</div>
        @endif
    </div>

    <div class="col-12" id="{{ $idPrefix }}-new-category-wrap" style="{{ $addingCategory ? '' : 'display: none;' }}">
        <label for="{{ $idPrefix }}-new-category" class="form-label">New category name</label>
        <input id="{{ $idPrefix }}-new-category" type="text" name="new_category" value="{{ $isActive ? old('new_category') : '' }}"
            class="form-control @if ($formErrors->has('new_category')) is-invalid @endif" placeholder="e.g. Bank charges" maxlength="{{ \App\Models\MyExpenseCategory::NAME_MAX }}"
            @if ($addingCategory) required @endif>
        @if ($formErrors->has('new_category'))
            <div class="invalid-feedback">{{ $formErrors->first('new_category') }}</div>
        @else
            <div class="form-text">It is added to your categories when you save this expense.</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-date" class="form-label">Date</label>
        <input id="{{ $idPrefix }}-date" type="date" name="expense_date"
            value="{{ $isActive ? old('expense_date') : ($expense?->expense_date?->format('Y-m-d') ?? $defaultDate) }}"
            class="form-control @if ($formErrors->has('expense_date')) is-invalid @endif" required>
        @if ($formErrors->has('expense_date'))
            <div class="invalid-feedback">{{ $formErrors->first('expense_date') }}</div>
        @else
            <div class="form-text">Counts toward this date's month.</div>
        @endif
    </div>

    <div class="col-12">
        <label for="{{ $idPrefix }}-notes" class="form-label">Notes</label>
        <textarea id="{{ $idPrefix }}-notes" name="notes" rows="2" maxlength="2000"
            class="form-control @if ($formErrors->has('notes')) is-invalid @endif" placeholder="Optional details…">{{ $isActive ? old('notes') : $expense?->notes }}</textarea>
        @if ($formErrors->has('notes'))
            <div class="invalid-feedback">{{ $formErrors->first('notes') }}</div>
        @endif
    </div>
</div>
