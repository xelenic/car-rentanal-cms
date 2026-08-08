@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="mb-3">
    <label for="{{ $idPrefix }}-name" class="form-label">Permission Name</label>
    <input id="{{ $idPrefix }}-name" type="text" name="name" value="{{ $isActive ? old('name') : $permission?->name }}"
        class="form-control @if ($formErrors->has('name')) is-invalid @endif" placeholder="e.g. reports.view" required>
    @if ($formErrors->has('name'))
        <div class="invalid-feedback">{{ $formErrors->first('name') }}</div>
    @endif
    <div class="form-text">Convention: <code>module.action</code> (e.g. <code>users.view</code>).</div>
</div>
