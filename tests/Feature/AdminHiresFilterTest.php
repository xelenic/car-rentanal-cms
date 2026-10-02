<?php

use App\Models\Customer;
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

function filterCustomer(string $name = 'ZZZ Customer'): Customer
{
    return Customer::create(['name' => $name, 'phone' => '0770000000']);
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

it('shows only one customer\'s hires when filtered by customer', function () {
    hiresAdmin();
    $amal = filterCustomer('ZZZ Amal');
    $bimal = filterCustomer('ZZZ Bimal');
    $amalHire = filterHire(['customer_id' => $amal->id]);
    $bimalHire = filterHire(['customer_id' => $bimal->id]);

    $response = $this->get('/admin/hires?customer_id='.$amal->id);

    $response->assertSee('Hire #'.$amalHire->id);
    $response->assertDontSee('Hire #'.$bimalHire->id);
});

it('shows only cash or only credit hires when filtered by payment type', function () {
    hiresAdmin();
    $cashHire = filterHire(['payment_type' => 'cash']);
    $creditHire = filterHire(['payment_type' => 'credit']);

    $cashOnly = $this->get('/admin/hires?payment_type=cash');
    $cashOnly->assertSee('Hire #'.$cashHire->id);
    $cashOnly->assertDontSee('Hire #'.$creditHire->id);

    $creditOnly = $this->get('/admin/hires?payment_type=credit');
    $creditOnly->assertSee('Hire #'.$creditHire->id);
    $creditOnly->assertDontSee('Hire #'.$cashHire->id);
});

it('ignores a payment_type value that is not cash or credit', function () {
    hiresAdmin();
    $cashHire = filterHire(['payment_type' => 'cash']);
    $creditHire = filterHire(['payment_type' => 'credit']);

    $response = $this->get('/admin/hires?payment_type=nonsense');

    $response->assertSee('Hire #'.$cashHire->id);
    $response->assertSee('Hire #'.$creditHire->id);
});

describe('the date range filter', function () {
    it('only shows hires scheduled within the given range', function () {
        hiresAdmin();
        $inRange = filterHire(['start_time' => '2026-09-15 10:00:00']);
        $before = filterHire(['start_time' => '2026-08-20 10:00:00']);
        $after = filterHire(['start_time' => '2026-10-05 10:00:00']);

        $response = $this->get('/admin/hires?date_from=2026-09-01&date_to=2026-09-30');

        $response->assertSee('Hire #'.$inRange->id);
        $response->assertDontSee('Hire #'.$before->id);
        $response->assertDontSee('Hire #'.$after->id);
    });

    it('works with only a from date, or only a to date', function () {
        hiresAdmin();
        $early = filterHire(['start_time' => '2026-09-01 10:00:00']);
        $late = filterHire(['start_time' => '2026-09-20 10:00:00']);

        $fromOnly = $this->get('/admin/hires?date_from=2026-09-10');
        $fromOnly->assertSee('Hire #'.$late->id);
        $fromOnly->assertDontSee('Hire #'.$early->id);

        $toOnly = $this->get('/admin/hires?date_to=2026-09-10');
        $toOnly->assertSee('Hire #'.$early->id);
        $toOnly->assertDontSee('Hire #'.$late->id);
    });

    it('excludes hires with no scheduled date at all', function () {
        hiresAdmin();
        $scheduled = filterHire(['start_time' => '2026-09-15 10:00:00']);
        $unscheduled = filterHire(['start_time' => null]);

        $response = $this->get('/admin/hires?date_from=2026-09-01&date_to=2026-09-30');

        $response->assertSee('Hire #'.$scheduled->id);
        $response->assertDontSee('Hire #'.$unscheduled->id);
    });

    it('does not error out on a malformed date value', function () {
        hiresAdmin();
        $hire = filterHire(['start_time' => '2026-09-15 10:00:00']);

        $response = $this->get('/admin/hires?date_from=not-a-date');

        $response->assertOk();
        $response->assertSee('Hire #'.$hire->id);
    });
});

it('combines every new filter together', function () {
    hiresAdmin();
    $nimal = filterDriver('ZZZ Nimal');
    $amal = filterCustomer('ZZZ Amal');
    $match = filterHire([
        'driver_id' => $nimal->id, 'customer_id' => $amal->id,
        'payment_type' => 'credit', 'start_time' => '2026-09-15 10:00:00',
    ]);
    $wrongPaymentType = filterHire([
        'driver_id' => $nimal->id, 'customer_id' => $amal->id,
        'payment_type' => 'cash', 'start_time' => '2026-09-15 10:00:00',
    ]);

    $response = $this->get('/admin/hires?driver_id='.$nimal->id.'&customer_id='.$amal->id
        .'&payment_type=credit&date_from=2026-09-01&date_to=2026-09-30');

    $response->assertSee('Hire #'.$match->id);
    $response->assertDontSee('Hire #'.$wrongPaymentType->id);
});
