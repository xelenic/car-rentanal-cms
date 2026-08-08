<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;
use Spatie\Permission\Models\Permission;

class PermissionController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:permissions.view', only: ['index', 'show']),
            new Middleware('permission:permissions.create', only: ['store']),
            new Middleware('permission:permissions.update', only: ['update']),
            new Middleware('permission:permissions.delete', only: ['destroy']),
        ];
    }

    public function index(): View
    {
        return view('admin.permissions.index', [
            'permissions' => Permission::withCount('roles')->orderBy('name')->paginate(15),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:permissions,name'],
        ]);

        $permission = Permission::create(['name' => $data['name']]);

        return redirect()->route('admin.permissions.index')->with('status', "Permission \"{$permission->name}\" was created.");
    }

    public function update(Request $request, Permission $permission): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:permissions,name,'.$permission->id],
        ]);

        $permission->update(['name' => $data['name']]);

        return redirect()->route('admin.permissions.index')->with('status', "Permission \"{$permission->name}\" was updated.");
    }

    public function destroy(Permission $permission): RedirectResponse
    {
        if ($permission->roles()->exists()) {
            return redirect()->route('admin.permissions.index')->with('error', "Permission \"{$permission->name}\" is still assigned to roles and cannot be deleted.");
        }

        $permission->delete();

        return redirect()->route('admin.permissions.index')->with('status', "Permission \"{$permission->name}\" was deleted.");
    }
}
