<?php

use Illuminate\Database\Migrations\Migration;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

return new class extends Migration
{
    /**
     * Adds the "logs.view" permission (admin Logs page) and grants it to
     * Super Admin. Done here rather than by re-running RolePermissionSeeder,
     * which would also reset the Admin and Driver roles to their seeded
     * permissions.
     */
    public function up(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $permission = Permission::firstOrCreate(['name' => 'logs.view']);

        Role::where('name', 'Super Admin')->get()->each->givePermissionTo($permission);

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }

    public function down(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        Permission::where('name', 'logs.view')->delete();

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }
};
