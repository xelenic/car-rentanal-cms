<?php

use App\Models\Customer;
use App\Models\Driver;
use App\Models\Hire;
use App\Models\HireLocation;
use App\Models\Location;
use App\Models\Package;
use App\Models\User;
use App\Models\Vehicle;
use App\Services\HireService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function editor(array $permissions = ['hires.view', 'hires.update', 'hires.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function zzzCustomer(string $name = 'ZZZ Test Customer'): Customer
{
    return Customer::create(['name' => $name, 'phone' => '0770000000']);
}

function zzzVehicle(string $model = 'ZZZ Test Van'): Vehicle
{
    return Vehicle::create(['model' => $model, 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

function zzzDriver(string $name = 'ZZZ Test Driver'): Driver
{
    $user = User::factory()->create();

    return Driver::create([
        'user_id' => $user->id, 'name' => $name, 'license' => 'B1', 'contact_number' => '077',
        'email' => uniqid('zzz').'@example.test', 'password' => 'secret-pass',
    ]);
}

/** A drop-and-pickup hire with its two places, made through the same service the API uses. */
function zzzHire(array $overrides = []): Hire
{
    return app(HireService::class)->create($overrides + [
        'tour_type' => 'drop_pickup',
        'customer_id' => zzzCustomer()->id,
        'vehicle_id' => zzzVehicle()->id,
        'hire_full_value' => 1000, 'our_hire_value' => 800, 'payment_type' => 'cash',
        'from_location_name' => 'ZZZ Old From', 'to_location_name' => 'ZZZ Old To',
        'description' => 'ZZZ before',
    ]);
}

/** The body of a full edit: everything the form sends, with $changes on top. */
function editBody(Hire $hire, array $changes = []): array
{
    return $changes + [
        'tour_type' => 'drop_pickup',
        'customer_id' => $hire->customer_id,
        'vehicle_id' => $hire->vehicle_id,
        'driver_id' => $hire->driver_id,
        'hire_full_value' => 1000, 'our_hire_value' => 800, 'payment_type' => 'cash',
        'from_location_name' => 'ZZZ Old From', 'to_location_name' => 'ZZZ Old To',
        'description' => 'ZZZ before',
    ];
}

describe('editing a hire', function () {
    it('needs a signed-in user', function () {
        $hire = zzzHire();

        $this->putJson("/api/admin/hires/{$hire->id}", [])->assertUnauthorized();
    });

    it('needs hires.update', function () {
        $hire = zzzHire();
        editor(['hires.view', 'hires.delete']);

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, ['description' => 'ZZZ nope']))->assertForbidden();
        expect($hire->fresh()->description)->toBe('ZZZ before');
    });

    it('is 404 for a hire that does not exist', function () {
        editor();

        $this->putJson('/api/admin/hires/999', [])->assertNotFound();
    });

    it('changes the values, payment type, description, driver and vehicle', function () {
        $hire = zzzHire();
        $driver = zzzDriver();
        $car = zzzVehicle('ZZZ Test Car');
        editor();

        $response = $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, [
            'hire_full_value' => 2500, 'our_hire_value' => 2000, 'payment_type' => 'credit',
            'description' => 'ZZZ after', 'driver_id' => $driver->id, 'vehicle_id' => $car->id,
        ]))->assertOk();

        $response->assertJsonPath('data.id', $hire->id)
            ->assertJsonPath('data.hire_full_value', 2500)
            ->assertJsonPath('data.our_hire_value', 2000)
            ->assertJsonPath('data.commission', 500)
            ->assertJsonPath('data.payment_type', 'credit')
            ->assertJsonPath('data.description', 'ZZZ after')
            ->assertJsonPath('data.driver.id', $driver->id)
            ->assertJsonPath('data.vehicle.id', $car->id);

        $fresh = $hire->fresh();
        expect((float) $fresh->hire_full_value)->toBe(2500.0)
            ->and($fresh->payment_type)->toBe('credit')
            ->and($fresh->driver_id)->toBe($driver->id)
            ->and($fresh->vehicle_id)->toBe($car->id)
            ->and(Hire::count())->toBe(1);
    });

    it('moves a hire to another customer, or to a brand new one', function () {
        $hire = zzzHire();
        $other = zzzCustomer('ZZZ Other Customer');
        editor();

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, ['customer_id' => $other->id]))
            ->assertOk()->assertJsonPath('data.customer.name', 'ZZZ Other Customer');

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, [
            'customer_id' => 'new', 'new_customer_name' => 'ZZZ Brand New', 'new_customer_phone' => '0771111111',
        ]))->assertOk()->assertJsonPath('data.customer.name', 'ZZZ Brand New');

        expect(Customer::where('name', 'ZZZ Brand New')->count())->toBe(1);
    });

    it('sets and clears the scheduled time', function () {
        $hire = zzzHire();
        editor();

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, ['start_time' => '2026-10-02 09:30:00']))->assertOk();
        expect($hire->fresh()->start_time->format('Y-m-d H:i'))->toBe('2026-10-02 09:30');

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire))->assertOk();
        expect($hire->fresh()->start_time)->toBeNull();
    });

    it('replaces the route, keeping a place that already existed with its coordinates', function () {
        $kept = Location::create(['name' => 'ZZZ Kept Place', 'latitude' => 6.9344, 'longitude' => 79.8428]);
        $hire = zzzHire(['from_location_name' => 'ZZZ Kept Place']);
        editor();

        // The app sends the names back without coordinates when they weren't picked from suggestions again.
        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, [
            'from_location_name' => 'ZZZ Kept Place', 'to_location_name' => 'ZZZ New Destination',
        ]))->assertOk()
            ->assertJsonPath('data.from_location', 'ZZZ Kept Place')
            ->assertJsonPath('data.to_location', 'ZZZ New Destination');

        expect($kept->fresh()->latitude)->toEqual(6.9344)
            ->and($kept->fresh()->longitude)->toEqual(79.8428)
            ->and(Location::where('name', 'ZZZ Kept Place')->count())->toBe(1)
            ->and(HireLocation::where('hire_id', $hire->id)->count())->toBe(2); // old rows replaced, not added to
    });

    it('edits a day tour\'s stay locations', function () {
        $hire = zzzHire([
            'tour_type' => 'day_tour', 'stay_location_names' => ['ZZZ Stay A', 'ZZZ Stay B'],
        ]);
        editor();

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, [
            'tour_type' => 'day_tour', 'stay_location_names' => ['ZZZ Stay C'],
        ]))->assertOk()->assertJsonPath('data.stay_locations', ['ZZZ Stay C']);
    });

    it('edits a multi-day tour\'s days', function () {
        $hire = zzzHire(['tour_type' => 'multi_day', 'day_location_names' => [['ZZZ Day1 A'], ['ZZZ Day2 A']]]);
        editor();

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, [
            'tour_type' => 'multi_day', 'day_location_names' => [['ZZZ Day1 A', 'ZZZ Day1 B'], ['ZZZ Day2 A'], ['ZZZ Day3 A']],
        ]))->assertOk()->assertJsonPath('data.day_locations', [['ZZZ Day1 A', 'ZZZ Day1 B'], ['ZZZ Day2 A'], ['ZZZ Day3 A']]);
    });

    it('can change the tour type, and a package tour needs its package and dates', function () {
        $hire = zzzHire();
        $package = Package::create(['name' => 'ZZZ Test Package', 'hours' => 8, 'price' => 5000]);
        editor();

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, ['tour_type' => 'package']))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['package_id', 'start_time', 'end_time']);

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, [
            'tour_type' => 'package', 'package_id' => $package->id,
            'start_time' => '2026-10-01 08:00:00', 'end_time' => '2026-10-03 18:00:00',
        ]))->assertOk()
            ->assertJsonPath('data.tour_type', 'package')
            ->assertJsonPath('data.package_id', $package->id)
            ->assertJsonPath('data.package', 'ZZZ Test Package');
    });

    it('rejects bad input and changes nothing', function (array $changes, string $field) {
        $hire = zzzHire();
        editor();

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, $changes))
            ->assertUnprocessable()->assertJsonValidationErrors($field);

        expect($hire->fresh()->description)->toBe('ZZZ before');
    })->with([
        'no value' => [['hire_full_value' => ''], 'hire_full_value'],
        'negative value' => [['our_hire_value' => -5], 'our_hire_value'],
        'unknown customer' => [['customer_id' => 9999], 'customer_id'],
        'unknown vehicle' => [['vehicle_id' => 9999], 'vehicle_id'],
        'no pickup place' => [['from_location_name' => ''], 'from_location_name'],
        'bad payment type' => [['payment_type' => 'barter'], 'payment_type'],
        'unknown tour type' => [['tour_type' => 'space'], 'tour_type'],
    ]);

    it('leaves the driver\'s side alone: status, tracking and cancellation', function () {
        $running = zzzHire();
        $running->forceFill(['status' => 'started', 'tracking_started_at' => now()->subHour()])->save();
        $cancelled = zzzHire();
        $cancelled->forceFill(['status' => 'cancelled', 'cancelled_at' => now(), 'cancel_reason' => 'ZZZ reason'])->save();
        editor();

        $this->putJson("/api/admin/hires/{$running->id}", editBody($running, ['description' => 'ZZZ edited']))->assertOk();
        $this->putJson("/api/admin/hires/{$cancelled->id}", editBody($cancelled, ['description' => 'ZZZ edited']))->assertOk();

        expect($running->fresh()->status)->toBe('started')
            ->and($running->fresh()->tracking_started_at)->not->toBeNull()
            ->and($cancelled->fresh()->status)->toBe('cancelled')
            ->and($cancelled->fresh()->cancel_reason)->toBe('ZZZ reason');
    });

    it('does not touch other hires', function () {
        $hire = zzzHire();
        $other = zzzHire(['description' => 'ZZZ other']);
        editor();

        $this->putJson("/api/admin/hires/{$hire->id}", editBody($hire, ['description' => 'ZZZ changed']))->assertOk();

        expect($other->fresh()->description)->toBe('ZZZ other')
            ->and(HireLocation::where('hire_id', $other->id)->count())->toBe(2);
    });
});

describe('deleting a hire', function () {
    it('needs a signed-in user', function () {
        $hire = zzzHire();

        $this->deleteJson("/api/admin/hires/{$hire->id}")->assertUnauthorized();
        expect(Hire::count())->toBe(1);
    });

    it('needs hires.delete', function () {
        $hire = zzzHire();
        editor(['hires.view', 'hires.update']);

        $this->deleteJson("/api/admin/hires/{$hire->id}")->assertForbidden();
        expect(Hire::count())->toBe(1);
    });

    it('is 404 for a hire that does not exist', function () {
        editor();

        $this->deleteJson('/api/admin/hires/999')->assertNotFound();
    });

    it('deletes the hire and says so', function () {
        $hire = zzzHire();
        editor();

        $this->deleteJson("/api/admin/hires/{$hire->id}")
            ->assertOk()->assertJsonPath('message', "Hire #{$hire->id} was deleted.");

        expect(Hire::find($hire->id))->toBeNull();
        $this->getJson("/api/admin/hires/{$hire->id}")->assertNotFound();
    });

    it('takes its places, payments, expenses and tracking with it — and nothing else', function () {
        $hire = zzzHire();
        $keep = zzzHire(['description' => 'ZZZ keep me']);
        DB::table('hire_payments')->insert(['hire_id' => $hire->id, 'amount' => 100, 'paid_at' => '2026-09-01', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('hire_expenses')->insert(['hire_id' => $hire->id, 'category' => 'fuel', 'amount' => 50, 'created_at' => now(), 'updated_at' => now()]);
        DB::table('hire_tracking_points')->insert(['hire_id' => $hire->id, 'latitude' => 6.9, 'longitude' => 79.8, 'recorded_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
        editor();

        $this->deleteJson("/api/admin/hires/{$hire->id}")->assertOk();

        foreach (['hire_locations', 'hire_payments', 'hire_expenses', 'hire_tracking_points'] as $table) {
            expect(DB::table($table)->where('hire_id', $hire->id)->count())->toBe(0, $table);
        }
        // Customers, vehicles and the places themselves are shared with other hires and stay.
        expect(Hire::find($keep->id))->not->toBeNull()
            ->and(HireLocation::where('hire_id', $keep->id)->count())->toBe(2)
            ->and(Customer::count())->toBe(2)
            ->and(Vehicle::count())->toBe(2)
            ->and(Location::where('name', 'ZZZ Old From')->exists())->toBeTrue();
    });

    it('is gone from its vehicle\'s tabs and counts', function () {
        $vehicle = zzzVehicle();
        $hire = zzzHire(['vehicle_id' => $vehicle->id]);
        editor(['hires.view', 'hires.delete', 'vehicles.view']);

        expect($this->getJson("/api/admin/vehicles/{$vehicle->id}")->json('data.stats.counts.all'))->toBe(1);

        $this->deleteJson("/api/admin/hires/{$hire->id}")->assertOk();

        expect($this->getJson("/api/admin/vehicles/{$vehicle->id}")->json('data.stats.counts.all'))->toBe(0)
            ->and($this->getJson("/api/admin/vehicles/{$vehicle->id}/hires")->json('data'))->toBe([]);
    });
});

it('tells the app whether the user may edit or delete hires', function () {
    editor(['hires.view', 'hires.update']);

    $this->getJson('/api/admin/me')
        ->assertOk()
        ->assertJsonPath('can_update_hires', true)
        ->assertJsonPath('can_delete_hires', false);
});
