<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class RoleController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:roles.view', only: ['index', 'show']),
            new Middleware('permission:roles.create', only: ['store']),
            new Middleware('permission:roles.update', only: ['update']),
            new Middleware('permission:roles.delete', only: ['destroy']),
        ];
    }

    public function index(): View
    {
        return view('admin.roles.index', [
            'roles' => Role::with('permissions')->withCount('permissions', 'users')->orderBy('name')->paginate(10),
            'permissions' => Permission::orderBy('name')->get()->groupBy(fn ($permission) => str($permission->name)->before('.')),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:roles,name'],
            'permissions' => ['array'],
            'permissions.*' => ['string', 'exists:permissions,name'],
        ]);

        $role = Role::create(['name' => $data['name']]);
        $role->syncPermissions($data['permissions'] ?? []);

        return redirect()->route('admin.roles.index')->with('status', "Role \"{$role->name}\" was created.");
    }

    public function update(Request $request, Role $role): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:roles,name,'.$role->id],
            'permissions' => ['array'],
            'permissions.*' => ['string', 'exists:permissions,name'],
        ]);

        $role->update(['name' => $data['name']]);
        $role->syncPermissions($data['permissions'] ?? []);

        return redirect()->route('admin.roles.index')->with('status', "Role \"{$role->name}\" was updated.");
    }

    public function destroy(Role $role): RedirectResponse
    {
        if ($role->users()->exists()) {
            return redirect()->route('admin.roles.index')->with('error', "Role \"{$role->name}\" is still assigned to users and cannot be deleted.");
        }

        $role->delete();

        return redirect()->route('admin.roles.index')->with('status', "Role \"{$role->name}\" was deleted.");
    }
}
