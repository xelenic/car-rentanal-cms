<?php

use App\Models\Driver;
use App\Models\Hire;
use App\Models\User;
use App\Models\Vehicle;
use App\Support\SelectedPeriod;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function navbarAdmin(array $permissions = ['drivers.view', 'vehicles.view']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

describe('the navbar\'s period switcher control', function () {
    it('shows the current month by default, with that month and year pre-selected', function () {
        navbarAdmin();

        $response = $this->get('/admin');

        $response->assertSee('September 2026');
        $response->assertSee('<option value="9" selected>September</option>', false);
        $response->assertSee('<option value="2026" selected>2026</option>', false);
    });

    it('shows whatever period a page\'s own ?year=&month= asked for', function () {
        navbarAdmin();

        $response = $this->get('/admin?year=2026&month=3');

        $response->assertSee('March 2026');
    });
});

describe('SyncSelectedPeriod', function () {
    it('remembers a request\'s ?year=&month= in the session', function () {
        navbarAdmin();

        $this->get('/admin?year=2026&month=3');

        expect(SelectedPeriod::year())->toBe(2026)
            ->and(SelectedPeriod::month())->toBe(3);
    });

    it('ignores a month outside 1–12 rather than remembering nonsense', function () {
        navbarAdmin();
        SelectedPeriod::remember(2026, 9);

        $this->get('/admin?year=2026&month=15');

        expect(SelectedPeriod::month())->toBe(9);
    });

    it('leaves the remembered period alone when a request has no year/month at all', function () {
        navbarAdmin();
        SelectedPeriod::remember(2026, 3);

        $this->get('/admin/vehicles');

        expect(SelectedPeriod::year())->toBe(2026)
            ->and(SelectedPeriod::month())->toBe(3);
    });
});

describe('the Dashboard follows the selected period', function () {
    it('accepts an explicit ?year=&month= of its own', function () {
        navbarAdmin();
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 4000,
            'payment_type' => 'cash', 'start_time' => '2026-03-10 09:00:00',
        ]);

        $response = $this->get('/admin?year=2026&month=3');

        $response->assertSee('March 2026');
        $response->assertSee('Rs. 5,000.00');
    });

    it('defaults to the session\'s remembered period when asked for none', function () {
        navbarAdmin();
        SelectedPeriod::remember(2026, 3);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 4000,
            'payment_type' => 'cash', 'start_time' => '2026-03-10 09:00:00',
        ]);

        $response = $this->get('/admin');

        $response->assertSee('March 2026');
        $response->assertSee('Rs. 5,000.00');
    });
});

describe('the Drivers and Vehicles pages follow the selected period too', function () {
    it('scopes the Drivers roster\'s salary figures to the remembered period, not the most recent month with data', function () {
        navbarAdmin();
        $driver = Driver::create([
            'name' => 'ZZZ Nimal', 'license' => 'ZZZ-1', 'contact_number' => '0770000000',
            'email' => 'zzz.nimal@example.test', 'password' => bcrypt('testpass123'),
        ]);
        // The most recent month with data is October — but March is remembered.
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 9999, 'our_hire_value' => 9999,
            'payment_type' => 'cash', 'start_time' => '2026-10-05 09:00:00', 'driver_id' => $driver->id,
        ]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 3000, 'our_hire_value' => 2000,
            'payment_type' => 'cash', 'start_time' => '2026-03-10 09:00:00', 'driver_id' => $driver->id,
        ]);
        SelectedPeriod::remember(2026, 3);

        $response = $this->get('/admin/drivers');

        $response->assertSee('March 2026');
    });

    it('scopes a driver\'s own page to the remembered period', function () {
        navbarAdmin();
        $driver = Driver::create([
            'name' => 'ZZZ Nimal', 'license' => 'ZZZ-1', 'contact_number' => '0770000000',
            'email' => 'zzz.nimal@example.test', 'password' => bcrypt('testpass123'),
        ]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 3000, 'our_hire_value' => 2000,
            'payment_type' => 'cash', 'start_time' => '2026-03-10 09:00:00', 'driver_id' => $driver->id,
        ]);
        SelectedPeriod::remember(2026, 3);

        $response = $this->get('/admin/drivers/'.$driver->id);

        $response->assertSee('March 2026');
        $response->assertSee('Rs. 3,000.00');
    });

    it('scopes the Vehicles fleet list to the remembered period', function () {
        navbarAdmin();
        $vehicle = Vehicle::create(['model' => 'ZZZ Prius', 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 3000, 'our_hire_value' => 2000,
            'payment_type' => 'cash', 'start_time' => '2026-03-10 09:00:00', 'vehicle_id' => $vehicle->id,
        ]);
        SelectedPeriod::remember(2026, 3);

        $response = $this->get('/admin/vehicles');

        $response->assertSee('March 2026');
    });

    it('scopes a vehicle\'s own revenue page to the remembered period', function () {
        navbarAdmin();
        $vehicle = Vehicle::create(['model' => 'ZZZ Prius', 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 3000, 'our_hire_value' => 2000,
            'payment_type' => 'cash', 'start_time' => '2026-03-10 09:00:00', 'vehicle_id' => $vehicle->id,
        ]);
        SelectedPeriod::remember(2026, 3);

        $response = $this->get('/admin/vehicles/'.$vehicle->id);

        $response->assertSee('March 2026');
    });

    it('carries across pages: picking a period on the Dashboard then visiting Drivers reflects it', function () {
        navbarAdmin();
        $driver = Driver::create([
            'name' => 'ZZZ Nimal', 'license' => 'ZZZ-1', 'contact_number' => '0770000000',
            'email' => 'zzz.nimal@example.test', 'password' => bcrypt('testpass123'),
        ]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 3000, 'our_hire_value' => 2000,
            'payment_type' => 'cash', 'start_time' => '2026-03-10 09:00:00', 'driver_id' => $driver->id,
        ]);

        $this->get('/admin?year=2026&month=3');
        $response = $this->get('/admin/drivers');

        $response->assertSee('March 2026');
    });

    it('still lets a page\'s own stepper override the remembered period for that visit, and updates it too', function () {
        navbarAdmin();
        SelectedPeriod::remember(2026, 3);
        $vehicle = Vehicle::create(['model' => 'ZZZ Prius', 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 7000, 'our_hire_value' => 6000,
            'payment_type' => 'cash', 'start_time' => '2026-07-10 09:00:00', 'vehicle_id' => $vehicle->id,
        ]);

        $response = $this->get('/admin/vehicles?year=2026&month=7');

        $response->assertSee('July 2026');
        expect(SelectedPeriod::month())->toBe(7);
    });
});
