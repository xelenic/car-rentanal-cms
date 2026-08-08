@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
    $userRoles = $user?->roles->pluck('name')->toArray() ?? [];
    $selectedRoles = $isActive ? (old('roles') ?? []) : $userRoles;
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="row g-2">
    <div class="col-md-6">
        <label for="{{ $idPrefix }}-name" class="form-label">Full Name</label>
        <input id="{{ $idPrefix }}-name" type="text" name="name" value="{{ $isActive ? old('name') : $user?->name }}"
            class="form-control @if ($formErrors->has('name')) is-invalid @endif" placeholder="Jane Doe" required>
        @if ($formErrors->has('name'))
            <div class="invalid-feedback">{{ $formErrors->first('name') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-email" class="form-label">Email Address</label>
        <input id="{{ $idPrefix }}-email" type="email" name="email" value="{{ $isActive ? old('email') : $user?->email }}"
            class="form-control @if ($formErrors->has('email')) is-invalid @endif" placeholder="jane@example.com" required>
        @if ($formErrors->has('email'))
            <div class="invalid-feedback">{{ $formErrors->first('email') }}</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-password" class="form-label">Password</label>
        <input id="{{ $idPrefix }}-password" type="password" name="password"
            class="form-control @if ($formErrors->has('password')) is-invalid @endif" {{ $user ? '' : 'required' }}>
        @if ($formErrors->has('password'))
            <div class="invalid-feedback">{{ $formErrors->first('password') }}</div>
        @elseif ($user)
            <div class="form-text">Leave blank to keep the current password.</div>
        @endif
    </div>

    <div class="col-md-6">
        <label for="{{ $idPrefix }}-password_confirmation" class="form-label">Confirm Password</label>
        <input id="{{ $idPrefix }}-password_confirmation" type="password" name="password_confirmation" class="form-control">
    </div>

    <div class="col-12">
        <label class="form-label d-block">Roles</label>
        <div class="d-flex flex-wrap gap-2">
            @forelse ($roles as $role)
                <label class="chip-check mb-0" style="cursor: pointer;">
                    <input type="checkbox" name="roles[]" value="{{ $role->name }}"
                        class="form-check-input mt-0" {{ in_array($role->name, $selectedRoles) ? 'checked' : '' }}>
                    <span class="fw-medium" style="font-size: .75rem;">{{ $role->name }}</span>
                </label>
            @empty
                <p class="text-muted small mb-0">No roles have been created yet.</p>
            @endforelse
        </div>
    </div>
</div>
