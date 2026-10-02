<?php

use App\Models\Driver;
use App\Models\Hire;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function hiresAdmin(array $permissions = ['hires.view']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function filterDriver(string $name = 'ZZZ Nimal'): Driver
{
    return Driver::create([
        'name' => $name,
        'license' => 'ZZZ-'.$name,
        'contact_number' => '0770000000',
        'email' => strtolower(str_replace(' ', '.', $name)).'@example.com',
        'password' => bcrypt('testpass123'),
    ]);
}

function filterVehicle(string $model = 'ZZZ Prius'): Vehicle
{
    return Vehicle::create(['model' => $model, 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

function filterHire(array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 3500,
        'payment_type' => 'cash', 'start_time' => now()->subDay(),
    ]);
}

it('shows only one driver\'s hires when filtered by driver', function () {
    hiresAdmin();
    $nimal = filterDriver('ZZZ Nimal');
    $kamal = filterDriver('ZZZ Kamal');
    $nimalHire = filterHire(['driver_id' => $nimal->id]);
    $kamalHire = filterHire(['driver_id' => $kamal->id]);

    $response = $this->get('/admin/hires?driver_id='.$nimal->id);

    $response->assertOk();
    $response->assertSee('Hire #'.$nimalHire->id);
    $response->assertDontSee('Hire #'.$kamalHire->id);
});

it('shows only one vehicle\'s hires when filtered by vehicle', function () {
    hiresAdmin();
    $prius = filterVehicle('ZZZ Prius');
    $axio = filterVehicle('ZZZ Axio');
    $priusHire = filterHire(['vehicle_id' => $prius->id]);
    $axioHire = filterHire(['vehicle_id' => $axio->id]);

    $response = $this->get('/admin/hires?vehicle_id='.$prius->id);

    $response->assertOk();
    $response->assertSee('Hire #'.$priusHire->id);
    $response->assertDontSee('Hire #'.$axioHire->id);
});

it('combines driver and vehicle filters', function () {
    hiresAdmin();
    $nimal = filterDriver('ZZZ Nimal');
    $kamal = filterDriver('ZZZ Kamal');
    $prius = filterVehicle('ZZZ Prius');
    $axio = filterVehicle('ZZZ Axio');

    $match = filterHire(['driver_id' => $nimal->id, 'vehicle_id' => $prius->id]);
    $wrongVehicle = filterHire(['driver_id' => $nimal->id, 'vehicle_id' => $axio->id]);
    $wrongDriver = filterHire(['driver_id' => $kamal->id, 'vehicle_id' => $prius->id]);

    $response = $this->get('/admin/hires?driver_id='.$nimal->id.'&vehicle_id='.$prius->id);

    $response->assertSee('Hire #'.$match->id);
    $response->assertDontSee('Hire #'.$wrongVehicle->id);
    $response->assertDontSee('Hire #'.$wrongDriver->id);
});

it('shows every hire with no filter selected', function () {
    hiresAdmin();
    $nimal = filterDriver('ZZZ Nimal');
    $kamal = filterDriver('ZZZ Kamal');
    $hireOne = filterHire(['driver_id' => $nimal->id]);
    $hireTwo = filterHire(['driver_id' => $kamal->id]);

    $response = $this->get('/admin/hires');

    $response->assertSee('Hire #'.$hireOne->id);
    $response->assertSee('Hire #'.$hireTwo->id);
});

it('marks the selected driver and vehicle options as selected', function () {
    hiresAdmin();
    $nimal = filterDriver('ZZZ Nimal');
    $prius = filterVehicle('ZZZ Prius');
    filterHire(['driver_id' => $nimal->id, 'vehicle_id' => $prius->id]);

    $response = $this->get('/admin/hires?driver_id='.$nimal->id.'&vehicle_id='.$prius->id);

    $response->assertSee('<option value="'.$nimal->id.'" selected>ZZZ Nimal</option>', false);
    $response->assertSee('<option value="'.$prius->id.'" selected>ZZZ Prius</option>', false);
});

it('is forbidden without the hires.view permission', function () {
    hiresAdmin([]);

    $this->get('/admin/hires')->assertForbidden();
});
