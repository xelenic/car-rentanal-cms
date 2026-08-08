@extends('layouts.admin')

@section('title', 'Roles')
@section('subtitle', 'Define roles and control what each one can access.')

@section('actions')
    @can('roles.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Role
        </button>
    @endcan
@endsection

@section('content')
    <div class="card border-0">
        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Role</th>
                        <th>Permissions</th>
                        <th>Users</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($roles as $role)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #ecfdf5; color: #059669;">
                                        <i class="bi bi-shield-check"></i>
                                    </div>
                                    <span class="fw-semibold" style="font-size: .8rem;">{{ $role->name }}</span>
                                </div>
                            </td>
                            <td><span class="badge rounded-pill bg-light text-dark border">{{ $role->permissions_count }} permissions</span></td>
                            <td class="text-muted small">{{ $role->users_count }} users</td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('roles.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $role->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('roles.delete')
                                        <form method="POST" action="{{ route('admin.roles.destroy', $role) }}" onsubmit="return confirm('Delete this role?');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit" class="btn btn-sm btn-light border btn-icon text-danger">
                                                <i class="bi bi-trash"></i>
                                            </button>
                                        </form>
                                    @endcan
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="4" class="text-center text-muted py-4">
                                <i class="bi bi-shield fs-4 d-block mb-1"></i>
                                No roles found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($roles->hasPages())
            <div class="card-footer bg-white">
                {{ $roles->links() }}
            </div>
        @endif
    </div>

    @can('roles.create')
        <x-modal id="modal-create" title="New Role" size="lg">
            <form id="form-create-role" method="POST" action="{{ route('admin.roles.store') }}">
                @csrf
                @include('admin.roles._form', ['role' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-role" class="btn btn-primary">Create Role</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @can('roles.update')
        @foreach ($roles as $role)
            <x-modal id="modal-edit-{{ $role->id }}" title="Edit Role" size="lg">
                <form id="form-edit-role-{{ $role->id }}" method="POST" action="{{ route('admin.roles.update', $role) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.roles._form', ['role' => $role, 'idPrefix' => 'edit-'.$role->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-role-{{ $role->id }}" class="btn btn-primary">Update Role</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan
@endsection
