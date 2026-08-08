<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;

class RolePermissionSeeder extends Seeder
{
    /**
     * Seed roles, permissions, and a default admin user.
     */
    public function run(): void
    {
        app(PermissionRegistrar::class)->forgetCachedPermissions();

        $permissions = [
            'users.view', 'users.create', 'users.update', 'users.delete',
            'roles.view', 'roles.create', 'roles.update', 'roles.delete',
            'permissions.view', 'permissions.create', 'permissions.update', 'permissions.delete',
            'vehicles.view', 'vehicles.create', 'vehicles.update', 'vehicles.delete',
            'drivers.view', 'drivers.create', 'drivers.update', 'drivers.delete',
            'locations.view', 'locations.create', 'locations.update', 'locations.delete',
            'packages.view', 'packages.create', 'packages.update', 'packages.delete',
            'customers.view', 'customers.create', 'customers.update', 'customers.delete',
            'hires.view', 'hires.create', 'hires.update', 'hires.delete',
            'salary-advances.view', 'salary-advances.update',
            'payroll.manage',
        ];

        foreach ($permissions as $permission) {
            Permission::firstOrCreate(['name' => $permission]);
        }

        $superAdmin = Role::firstOrCreate(['name' => 'Super Admin']);
        $superAdmin->syncPermissions($permissions);

        $admin = Role::firstOrCreate(['name' => 'Admin']);
        $admin->syncPermissions([
            'users.view', 'users.create', 'users.update',
            'roles.view',
            'permissions.view',
            'vehicles.view', 'vehicles.create', 'vehicles.update',
            'drivers.view', 'drivers.create', 'drivers.update',
            'locations.view', 'locations.create', 'locations.update',
            'packages.view', 'packages.create', 'packages.update',
            'customers.view', 'customers.create', 'customers.update',
            'hires.view', 'hires.create', 'hires.update',
            'salary-advances.view', 'salary-advances.update',
            'payroll.manage',
        ]);

        $driver = Role::firstOrCreate(['name' => 'Driver']);
        $driver->syncPermissions([
            'vehicles.view',
            'drivers.view',
            'locations.view',
            'hires.view',
        ]);

        $user = User::firstOrCreate(
            ['email' => 'admin@example.com'],
            [
                'name' => 'Super Admin',
                'password' => Hash::make('password'),
                'email_verified_at' => now(),
            ]
        );

        $user->syncRoles([$superAdmin->name]);
    }
}
