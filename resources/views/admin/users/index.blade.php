@extends('layouts.admin')

@section('title', 'Users')
@section('subtitle', 'Manage user accounts and their assigned roles.')

@section('actions')
    @can('users.create')
        <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
            <i class="bi bi-plus-lg me-1"></i> New User
        </button>
    @endcan
@endsection

@section('content')
    <div class="card border-0">
        <div class="card-header">
            <form method="GET" style="max-width: 280px;">
                <div class="position-relative">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search by name or email...">
                </div>
            </form>
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>User</th>
                        <th>Roles</th>
                        <th>Joined</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($users as $user)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <x-avatar :name="$user->name" :size="30" />
                                    <div>
                                        <div class="fw-semibold" style="font-size: .8rem;">{{ $user->name }}</div>
                                        <div class="text-muted" style="font-size: .78rem;">{{ $user->email }}</div>
                                    </div>
                                </div>
                            </td>
                            <td>
                                @forelse ($user->roles as $role)
                                    <span class="badge rounded-pill bg-primary-subtle text-primary-emphasis">{{ $role->name }}</span>
                                @empty
                                    <span class="text-muted small">&mdash;</span>
                                @endforelse
                            </td>
                            <td class="text-muted small">{{ $user->created_at->format('M j, Y') }}</td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('users.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $user->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('users.delete')
                                        <form method="POST" action="{{ route('admin.users.destroy', $user) }}" onsubmit="return confirm('Delete this user?');">
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
                                <i class="bi bi-people fs-4 d-block mb-1"></i>
                                No users found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($users->hasPages())
            <div class="card-footer bg-white">
                {{ $users->links() }}
            </div>
        @endif
    </div>

    @can('users.create')
        <x-modal id="modal-create" title="New User">
            <form id="form-create-user" method="POST" action="{{ route('admin.users.store') }}">
                @csrf
                @include('admin.users._form', ['user' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-user" class="btn btn-primary">Create User</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @can('users.update')
        @foreach ($users as $user)
            <x-modal id="modal-edit-{{ $user->id }}" title="Edit User">
                <form id="form-edit-user-{{ $user->id }}" method="POST" action="{{ route('admin.users.update', $user) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.users._form', ['user' => $user, 'idPrefix' => 'edit-'.$user->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-user-{{ $user->id }}" class="btn btn-primary">Update User</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan
@endsection
