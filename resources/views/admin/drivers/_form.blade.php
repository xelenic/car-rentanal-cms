@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-name" class="form-label">Driver's Name</label>
        <input id="{{ $idPrefix }}-name" type="text" name="name" value="{{ $isActive ? old('name') : $driver?->name }}"
            class="form-control @if ($formErrors->has('name')) is-invalid @endif" placeholder="Juan Dela Cruz" required>
        @if ($formErrors->has('name'))
            <div class="invalid-feedback">{{ $formErrors->first('name') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-license" class="form-label">License</label>
        <input id="{{ $idPrefix }}-license" type="text" name="license" value="{{ $isActive ? old('license') : $driver?->license }}"
            class="form-control @if ($formErrors->has('license')) is-invalid @endif" placeholder="License number" required>
        @if ($formErrors->has('license'))
            <div class="invalid-feedback">{{ $formErrors->first('license') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-contact_number" class="form-label">Driver Contact Number</label>
        <input id="{{ $idPrefix }}-contact_number" type="text" name="contact_number" value="{{ $isActive ? old('contact_number') : $driver?->contact_number }}"
            class="form-control @if ($formErrors->has('contact_number')) is-invalid @endif" placeholder="+63 900 000 0000" required>
        @if ($formErrors->has('contact_number'))
            <div class="invalid-feedback">{{ $formErrors->first('contact_number') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-additional_phone_number" class="form-label">Additional Phone Number</label>
        <input id="{{ $idPrefix }}-additional_phone_number" type="text" name="additional_phone_number" value="{{ $isActive ? old('additional_phone_number') : $driver?->additional_phone_number }}"
            class="form-control @if ($formErrors->has('additional_phone_number')) is-invalid @endif" placeholder="Optional">
        @if ($formErrors->has('additional_phone_number'))
            <div class="invalid-feedback">{{ $formErrors->first('additional_phone_number') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-email" class="form-label">Email Address</label>
        <input id="{{ $idPrefix }}-email" type="email" name="email" value="{{ $isActive ? old('email') : $driver?->email }}"
            class="form-control @if ($formErrors->has('email')) is-invalid @endif" placeholder="driver@example.com" required>
        @if ($formErrors->has('email'))
            <div class="invalid-feedback">{{ $formErrors->first('email') }}</div>
        @endif
    </div>

    <div class="col-md-6"></div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-password" class="form-label">Password</label>
        <input id="{{ $idPrefix }}-password" type="password" name="password"
            class="form-control @if ($formErrors->has('password')) is-invalid @endif" {{ $driver ? '' : 'required' }}>
        @if ($formErrors->has('password'))
            <div class="invalid-feedback">{{ $formErrors->first('password') }}</div>
        @elseif ($driver)
            <div class="form-text">Leave blank to keep the current password.</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-password_confirmation" class="form-label">Confirm Password</label>
        <input id="{{ $idPrefix }}-password_confirmation" type="password" name="password_confirmation" class="form-control">
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-driver_id_softcopy" class="form-label">Driver ID Softcopy</label>
        <input id="{{ $idPrefix }}-driver_id_softcopy" type="file" name="driver_id_softcopy"
            class="form-control @if ($formErrors->has('driver_id_softcopy')) is-invalid @endif" accept=".pdf,.jpg,.jpeg,.png">
        @if ($formErrors->has('driver_id_softcopy'))
            <div class="invalid-feedback">{{ $formErrors->first('driver_id_softcopy') }}</div>
        @elseif ($driver?->driver_id_softcopy_path)
            <div class="form-text">
                <a href="{{ \Illuminate\Support\Facades\Storage::url($driver->driver_id_softcopy_path) }}" target="_blank">View current file</a> — upload a new one to replace it.
            </div>
        @else
            <div class="form-text">PDF, JPG or PNG. Max 5MB.</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-tourism_board_license" class="form-label">Tourism Board License</label>
        <input id="{{ $idPrefix }}-tourism_board_license" type="file" name="tourism_board_license"
            class="form-control @if ($formErrors->has('tourism_board_license')) is-invalid @endif" accept=".pdf,.jpg,.jpeg,.png">
        @if ($formErrors->has('tourism_board_license'))
            <div class="invalid-feedback">{{ $formErrors->first('tourism_board_license') }}</div>
        @elseif ($driver?->tourism_board_license_path)
            <div class="form-text">
                <a href="{{ \Illuminate\Support\Facades\Storage::url($driver->tourism_board_license_path) }}" target="_blank">View current file</a> — upload a new one to replace it.
            </div>
        @else
            <div class="form-text">PDF, JPG or PNG. Max 5MB.</div>
        @endif
    </div>
</div>
