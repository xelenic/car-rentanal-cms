<?php

use App\Models\Customer;
use App\Models\Driver;
use App\Models\Hire;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function apiHiresAdmin(array $permissions = ['hires.view']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function apiFilterDriver(string $name = 'ZZZ Nimal'): Driver
{
    $userId = User::factory()->create()->id;

    return Driver::create([
        'user_id' => $userId,
        'name' => $name,
        'license' => 'ZZZ-'.$name,
        'contact_number' => '0770000000',
        'email' => strtolower(str_replace(' ', '.', $name)).'@example.com',
        'password' => bcrypt('testpass123'),
    ]);
}

function apiFilterVehicle(string $model = 'ZZZ Prius'): Vehicle
{
    return Vehicle::create(['model' => $model, 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

function apiFilterCustomer(string $name = 'ZZZ Customer'): Customer
{
    return Customer::create(['name' => $name, 'phone' => '0770000000']);
}

function apiFilterHire(array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 3500,
        'payment_type' => 'cash', 'start_time' => now()->subDay(),
    ]);
}

it('shows only one driver\'s hires when filtered by driver_id', function () {
    apiHiresAdmin();
    $nimal = apiFilterDriver('ZZZ Nimal');
    $kamal = apiFilterDriver('ZZZ Kamal');
    $nimalHire = apiFilterHire(['driver_id' => $nimal->id]);
    apiFilterHire(['driver_id' => $kamal->id]);

    $response = $this->getJson('/api/admin/hires?driver_id='.$nimal->id);

    $response->assertOk();
    $ids = collect($response->json('data'))->pluck('id');
    expect($ids)->toContain($nimalHire->id)->and($ids)->toHaveCount(1);
});

it('shows only one vehicle\'s hires when filtered by vehicle_id', function () {
    apiHiresAdmin();
    $prius = apiFilterVehicle('ZZZ Prius');
    $axio = apiFilterVehicle('ZZZ Axio');
    $priusHire = apiFilterHire(['vehicle_id' => $prius->id]);
    apiFilterHire(['vehicle_id' => $axio->id]);

    $response = $this->getJson('/api/admin/hires?vehicle_id='.$prius->id);

    $ids = collect($response->json('data'))->pluck('id');
    expect($ids)->toContain($priusHire->id)->and($ids)->toHaveCount(1);
});

it('shows only one customer\'s hires when filtered by customer_id', function () {
    apiHiresAdmin();
    $amal = apiFilterCustomer('ZZZ Amal');
    $bimal = apiFilterCustomer('ZZZ Bimal');
    $amalHire = apiFilterHire(['customer_id' => $amal->id]);
    apiFilterHire(['customer_id' => $bimal->id]);

    $response = $this->getJson('/api/admin/hires?customer_id='.$amal->id);

    $ids = collect($response->json('data'))->pluck('id');
    expect($ids)->toContain($amalHire->id)->and($ids)->toHaveCount(1);
});

describe('the date range filter', function () {
    it('only shows hires scheduled within the given range', function () {
        apiHiresAdmin();
        $inRange = apiFilterHire(['start_time' => '2026-09-15 10:00:00']);
        apiFilterHire(['start_time' => '2026-08-20 10:00:00']);
        apiFilterHire(['start_time' => '2026-10-05 10:00:00']);

        $response = $this->getJson('/api/admin/hires?date_from=2026-09-01&date_to=2026-09-30');

        $ids = collect($response->json('data'))->pluck('id');
        expect($ids)->toContain($inRange->id)->and($ids)->toHaveCount(1);
    });

    it('does not error out on a malformed date value', function () {
        apiHiresAdmin();
        $hire = apiFilterHire(['start_time' => '2026-09-15 10:00:00']);

        $response = $this->getJson('/api/admin/hires?date_from=not-a-date');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        expect($ids)->toContain($hire->id);
    });
});

it('combines driver, vehicle, customer and date filters together', function () {
    apiHiresAdmin();
    $nimal = apiFilterDriver('ZZZ Nimal');
    $kamal = apiFilterDriver('ZZZ Kamal');
    $prius = apiFilterVehicle('ZZZ Prius');
    $amal = apiFilterCustomer('ZZZ Amal');

    $match = apiFilterHire([
        'driver_id' => $nimal->id, 'vehicle_id' => $prius->id, 'customer_id' => $amal->id,
        'start_time' => '2026-09-15 10:00:00',
    ]);
    $wrongDriver = apiFilterHire([
        'driver_id' => $kamal->id, 'vehicle_id' => $prius->id, 'customer_id' => $amal->id,
        'start_time' => '2026-09-15 10:00:00',
    ]);

    $response = $this->getJson('/api/admin/hires?driver_id='.$nimal->id.'&vehicle_id='.$prius->id
        .'&customer_id='.$amal->id.'&date_from=2026-09-01&date_to=2026-09-30');

    $ids = collect($response->json('data'))->pluck('id');
    expect($ids)->toContain($match->id)
        ->and($ids)->not->toContain($wrongDriver->id);
});

it('shows every hire with no filter selected', function () {
    apiHiresAdmin();
    $nimal = apiFilterDriver('ZZZ Nimal');
    $kamal = apiFilterDriver('ZZZ Kamal');
    $hireOne = apiFilterHire(['driver_id' => $nimal->id]);
    $hireTwo = apiFilterHire(['driver_id' => $kamal->id]);

    $response = $this->getJson('/api/admin/hires');

    $ids = collect($response->json('data'))->pluck('id');
    expect($ids)->toContain($hireOne->id)->and($ids)->toContain($hireTwo->id);
});

it('is forbidden without the hires.view permission', function () {
    apiHiresAdmin([]);

    $this->getJson('/api/admin/hires')->assertForbidden();
});
