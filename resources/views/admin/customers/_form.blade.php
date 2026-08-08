@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-name" class="form-label">Name</label>
        <input id="{{ $idPrefix }}-name" type="text" name="name" value="{{ $isActive ? old('name') : $customer?->name }}"
            class="form-control @if ($formErrors->has('name')) is-invalid @endif" placeholder="Customer full name" required>
        @if ($formErrors->has('name'))
            <div class="invalid-feedback">{{ $formErrors->first('name') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-phone" class="form-label">Phone</label>
        <input id="{{ $idPrefix }}-phone" type="text" name="phone" value="{{ $isActive ? old('phone') : $customer?->phone }}"
            class="form-control @if ($formErrors->has('phone')) is-invalid @endif" placeholder="+94 71 234 5678" required>
        @if ($formErrors->has('phone'))
            <div class="invalid-feedback">{{ $formErrors->first('phone') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-email" class="form-label">Email</label>
        <input id="{{ $idPrefix }}-email" type="email" name="email" value="{{ $isActive ? old('email') : $customer?->email }}"
            class="form-control @if ($formErrors->has('email')) is-invalid @endif" placeholder="customer@example.com">
        @if ($formErrors->has('email'))
            <div class="invalid-feedback">{{ $formErrors->first('email') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-nic_passport" class="form-label">NIC / Passport</label>
        <input id="{{ $idPrefix }}-nic_passport" type="text" name="nic_passport" value="{{ $isActive ? old('nic_passport') : $customer?->nic_passport }}"
            class="form-control @if ($formErrors->has('nic_passport')) is-invalid @endif" placeholder="e.g. 991234567V">
        @if ($formErrors->has('nic_passport'))
            <div class="invalid-feedback">{{ $formErrors->first('nic_passport') }}</div>
        @endif
    </div>

    <div class="col-12">
        <label for="{{ $idPrefix }}-address" class="form-label">Address</label>
        <textarea id="{{ $idPrefix }}-address" name="address" class="form-control @if ($formErrors->has('address')) is-invalid @endif" rows="2" placeholder="Street, city, postal code...">{{ $isActive ? old('address') : $customer?->address }}</textarea>
        @if ($formErrors->has('address'))
            <div class="invalid-feedback">{{ $formErrors->first('address') }}</div>
        @endif
    </div>

    <div class="col-12">
        <label for="{{ $idPrefix }}-notes" class="form-label">Notes</label>
        <textarea id="{{ $idPrefix }}-notes" name="notes" class="form-control @if ($formErrors->has('notes')) is-invalid @endif" rows="2" placeholder="Any additional notes about this customer...">{{ $isActive ? old('notes') : $customer?->notes }}</textarea>
        @if ($formErrors->has('notes'))
            <div class="invalid-feedback">{{ $formErrors->first('notes') }}</div>
        @endif
    </div>
</div>
