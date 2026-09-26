<?php

use Illuminate\Database\Migrations\Migration;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

return new class extends Migration
{
    private const PERMISSIONS = ['my-expenses.view', 'my-expenses.create', 'my-expenses.update', 'my-expenses.delete'];

    /**
     * Adds the "my-expenses.*" permissions and grants them to Super Admin only —
     * these are the owner's own costs, so other roles get them only if someone
     * grants them on the Roles page. Done here rather than by re-running
     * RolePermissionSeeder, which would also reset the Admin and Driver roles.
     */
    public function up(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $permissions = collect(self::PERMISSIONS)->map(fn (string $name) => Permission::firstOrCreate(['name' => $name]));

        Role::where('name', 'Super Admin')->get()->each->givePermissionTo($permissions->all());

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }

    public function down(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        Permission::whereIn('name', self::PERMISSIONS)->delete();

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }
};
