@php
    $isActive = old('form_id') === $idPrefix;
    $formErrors = $isActive ? $errors : new \Illuminate\Support\MessageBag();
    $rolePermissions = $role?->permissions->pluck('name')->toArray() ?? [];
    $selectedPermissions = $isActive ? (old('permissions') ?? []) : $rolePermissions;
@endphp

<input type="hidden" name="form_id" value="{{ $idPrefix }}">

<div class="mb-3">
    <label for="{{ $idPrefix }}-name" class="form-label">Role Name</label>
    <input id="{{ $idPrefix }}-name" type="text" name="name" value="{{ $isActive ? old('name') : $role?->name }}"
        class="form-control @if ($formErrors->has('name')) is-invalid @endif" style="max-width: 280px;" placeholder="e.g. Editor" required>
    @if ($formErrors->has('name'))
        <div class="invalid-feedback">{{ $formErrors->first('name') }}</div>
    @endif
</div>

<label class="form-label d-block">Permissions</label>
<div class="d-flex flex-column gap-2">
    @forelse ($permissions as $group => $groupPermissions)
        <div class="border rounded-3 p-2">
            <div class="fw-semibold text-capitalize mb-1 d-flex align-items-center gap-1" style="font-size: .75rem;">
                <i class="bi bi-folder2 text-muted"></i> {{ $group }}
            </div>
            <div class="d-flex flex-wrap gap-1">
                @foreach ($groupPermissions as $permission)
                    <label class="chip-check mb-0" style="cursor: pointer;">
                        <input type="checkbox" name="permissions[]" value="{{ $permission->name }}"
                            class="form-check-input mt-0" {{ in_array($permission->name, $selectedPermissions) ? 'checked' : '' }}>
                        <span class="fw-medium" style="font-size: .75rem;">{{ $permission->name }}</span>
                    </label>
                @endforeach
            </div>
        </div>
    @empty
        <p class="text-muted small mb-0">No permissions have been created yet.</p>
    @endforelse
</div>
