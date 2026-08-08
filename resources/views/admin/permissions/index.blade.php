@extends('layouts.admin')

@section('title', 'Permissions')
@section('subtitle', 'Fine-grained permissions that can be assigned to roles.')

@section('actions')
    @can('permissions.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New Permission
        </button>
    @endcan
@endsection

@section('content')
    <div class="card border-0">
        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Permission</th>
                        <th>Used By</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($permissions as $permission)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <div class="stat-icon" style="width: 28px; height: 28px; font-size: .85rem; background: #fffbeb; color: #d97706;">
                                        <i class="bi bi-key"></i>
                                    </div>
                                    <code>{{ $permission->name }}</code>
                                </div>
                            </td>
                            <td><span class="badge rounded-pill bg-light text-dark border">{{ $permission->roles_count }} roles</span></td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('permissions.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $permission->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('permissions.delete')
                                        <form method="POST" action="{{ route('admin.permissions.destroy', $permission) }}" onsubmit="return confirm('Delete this permission?');">
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
                            <td colspan="3" class="text-center text-muted py-4">
                                <i class="bi bi-key fs-4 d-block mb-1"></i>
                                No permissions found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($permissions->hasPages())
            <div class="card-footer bg-white">
                {{ $permissions->links() }}
            </div>
        @endif
    </div>

    @can('permissions.create')
        <x-modal id="modal-create" title="New Permission">
            <form id="form-create-permission" method="POST" action="{{ route('admin.permissions.store') }}">
                @csrf
                @include('admin.permissions._form', ['permission' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-permission" class="btn btn-primary">Create Permission</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @can('permissions.update')
        @foreach ($permissions as $permission)
            <x-modal id="modal-edit-{{ $permission->id }}" title="Edit Permission">
                <form id="form-edit-permission-{{ $permission->id }}" method="POST" action="{{ route('admin.permissions.update', $permission) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.permissions._form', ['permission' => $permission, 'idPrefix' => 'edit-'.$permission->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-permission-{{ $permission->id }}" class="btn btn-primary">Update Permission</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan
@endsection
