<?php

use App\Models\Customer;
use App\Models\Hire;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

const ALL_ADMIN_PERMISSIONS = ['vehicles.view', 'vehicles.create', 'hires.view', 'hires.create'];

beforeEach(function () {
    // Wednesday midday — every "today" / "this month" figure below is
    // relative to it.
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function signedInAdmin(array $permissions = ALL_ADMIN_PERMISSIONS): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function fleetVehicle(string $model = 'ZZZ Test Van', array $attributes = []): Vehicle
{
    return Vehicle::create($attributes + ['model' => $model, 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

function vehicleHire(Vehicle $vehicle, array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 1000, 'our_hire_value' => 800,
        'payment_type' => 'cash', 'vehicle_id' => $vehicle->id,
    ]);
}

function vehicleStats(array $vehicleJson): array
{
    return $vehicleJson['stats'];
}

describe('access', function () {
    it('needs a signed-in user', function () {
        $this->getJson('/api/admin/vehicles')->assertUnauthorized();
        $this->postJson('/api/admin/vehicles', [])->assertUnauthorized();
    });

    it('needs vehicles.view to see the fleet, one vehicle or its hires', function () {
        $vehicle = fleetVehicle();
        signedInAdmin(['hires.view']);

        $this->getJson('/api/admin/vehicles')->assertForbidden();
        $this->getJson("/api/admin/vehicles/{$vehicle->id}")->assertForbidden();
        $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires")->assertForbidden();
    });

    it('needs hires.view as well to list a vehicle\'s hires', function () {
        $vehicle = fleetVehicle();
        signedInAdmin(['vehicles.view']);

        $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires")->assertForbidden();
    });

    it('tells the app what the user may do', function () {
        signedInAdmin(['hires.view', 'vehicles.view']);

        $this->getJson('/api/admin/me')
            ->assertOk()
            ->assertJsonPath('can_view_vehicles', true)
            ->assertJsonPath('can_create_vehicles', false)
            ->assertJsonPath('can_create_hires', false);
    });
});

describe('the fleet list', function () {
    it('lists vehicles A to Z with their details', function () {
        signedInAdmin();
        fleetVehicle('ZZZ Test Van', ['condition' => 'Excellent', 'seats' => 9, 'pax' => 8, 'description' => 'ZZZ roomy']);
        fleetVehicle('ZZZ Test Car');

        $response = $this->getJson('/api/admin/vehicles')->assertOk();

        expect(collect($response->json('data'))->pluck('model')->all())->toBe(['ZZZ Test Car', 'ZZZ Test Van']);
        $response->assertJsonPath('data.1.condition', 'Excellent')
            ->assertJsonPath('data.1.seats', 9)
            ->assertJsonPath('data.1.pax', 8)
            ->assertJsonPath('data.1.description', 'ZZZ roomy');
    });

    it('counts a vehicle\'s hires per tab', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();

        vehicleHire($vehicle, ['start_time' => '2026-09-16 09:00:00']);                     // today
        vehicleHire($vehicle, ['start_time' => null]);                                       // no date: today
        vehicleHire($vehicle, ['start_time' => '2026-09-10 09:00:00']);                     // overdue: today
        vehicleHire($vehicle, ['start_time' => '2026-09-16 08:00:00', 'status' => 'started']); // running
        vehicleHire($vehicle, ['start_time' => '2026-09-17 09:00:00']);                     // scheduled
        vehicleHire($vehicle, ['start_time' => '2026-10-30 09:00:00']);                     // scheduled
        vehicleHire($vehicle, ['start_time' => '2026-09-01 09:00:00', 'status' => 'completed']);
        vehicleHire($vehicle, ['start_time' => '2026-09-02 09:00:00', 'status' => 'completed']);
        vehicleHire($vehicle, ['start_time' => '2026-09-16 10:00:00', 'status' => 'cancelled']);

        $stats = vehicleStats($this->getJson('/api/admin/vehicles')->assertOk()->json('data.0'));

        expect($stats['counts'])->toBe([
            'all' => 9, 'today' => 4, 'scheduled' => 2, 'completed' => 2, 'cancelled' => 1, 'running' => 1,
        ]);
    });

    it('puts the day boundary at midnight', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();

        vehicleHire($vehicle, ['start_time' => '2026-09-16 23:59:59']); // still today
        vehicleHire($vehicle, ['start_time' => '2026-09-17 00:00:00']); // already tomorrow

        $counts = vehicleStats($this->getJson('/api/admin/vehicles')->json('data.0'))['counts'];

        expect($counts['today'])->toBe(1)->and($counts['scheduled'])->toBe(1);
    });

    it('adds up money over the hires that earn — a cancelled hire earns nothing', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();

        vehicleHire($vehicle, ['hire_full_value' => 1000, 'our_hire_value' => 800, 'start_time' => '2026-09-05 09:00:00', 'status' => 'completed']);
        vehicleHire($vehicle, ['hire_full_value' => 500, 'our_hire_value' => 400, 'start_time' => '2026-09-20 09:00:00']);
        vehicleHire($vehicle, ['hire_full_value' => 7000, 'our_hire_value' => 1000, 'start_time' => '2026-09-06 09:00:00', 'status' => 'cancelled']);

        $stats = vehicleStats($this->getJson('/api/admin/vehicles')->json('data.0'));

        expect($stats['hire_count'])->toBe(2)
            ->and($stats['hire_full_value_total'])->toEqual(1500)
            ->and($stats['our_hire_value_total'])->toEqual(1200)
            ->and($stats['commission_total'])->toEqual(300)
            ->and($stats['counts']['cancelled'])->toBe(1)
            ->and($stats['counts']['all'])->toBe(3);
    });

    it('reports this month separately from all time', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();

        vehicleHire($vehicle, ['hire_full_value' => 1000, 'our_hire_value' => 700, 'start_time' => '2026-09-03 09:00:00', 'status' => 'completed']);
        vehicleHire($vehicle, ['hire_full_value' => 200, 'our_hire_value' => 150, 'start_time' => '2026-09-28 09:00:00']);
        vehicleHire($vehicle, ['hire_full_value' => 9000, 'our_hire_value' => 8000, 'start_time' => '2026-08-30 09:00:00', 'status' => 'completed']);
        vehicleHire($vehicle, ['hire_full_value' => 300, 'our_hire_value' => 250, 'start_time' => null]); // no date: booked now, so this month

        $stats = vehicleStats($this->getJson('/api/admin/vehicles')->json('data.0'));

        expect($stats['month'])->toEqual(['hire_count' => 3, 'hire_full_value_total' => 1500, 'commission_total' => 400])
            ->and($stats['hire_count'])->toBe(4)
            ->and($stats['hire_full_value_total'])->toEqual(10500);
    });

    it('does not mix one vehicle\'s numbers into another\'s', function () {
        signedInAdmin();
        $van = fleetVehicle('ZZZ Test Van');
        $car = fleetVehicle('ZZZ Test Car');
        vehicleHire($van, ['start_time' => '2026-09-16 09:00:00']);
        vehicleHire($van, ['start_time' => '2026-09-16 10:00:00']);
        vehicleHire($car, ['start_time' => '2026-09-20 10:00:00']);

        $data = collect($this->getJson('/api/admin/vehicles')->json('data'))->keyBy('model');

        expect($data['ZZZ Test Van']['stats']['counts']['today'])->toBe(2)
            ->and($data['ZZZ Test Car']['stats']['counts']['today'])->toBe(0)
            ->and($data['ZZZ Test Car']['stats']['counts']['scheduled'])->toBe(1);
    });

    it('shows zeros for a vehicle with no hires', function () {
        signedInAdmin();
        fleetVehicle();

        $stats = vehicleStats($this->getJson('/api/admin/vehicles')->json('data.0'));

        expect($stats['hire_count'])->toBe(0)
            ->and($stats['hire_full_value_total'])->toEqual(0)
            ->and($stats['commission_total'])->toEqual(0)
            ->and($stats['counts']['all'])->toBe(0);
    });

    it('searches by model or condition', function () {
        signedInAdmin();
        fleetVehicle('ZZZ Test Van', ['condition' => 'Good']);
        fleetVehicle('ZZZ Test Car', ['condition' => 'Poor']);

        $byModel = $this->getJson('/api/admin/vehicles?search=Van')->json('data');
        $byCondition = $this->getJson('/api/admin/vehicles?search=Poor')->json('data');

        expect(collect($byModel)->pluck('model')->all())->toBe(['ZZZ Test Van'])
            ->and(collect($byCondition)->pluck('model')->all())->toBe(['ZZZ Test Car']);
    });

    it('pages the list', function () {
        signedInAdmin();
        foreach (range(1, 23) as $number) {
            fleetVehicle(sprintf('ZZZ Test Vehicle %02d', $number));
        }

        $first = $this->getJson('/api/admin/vehicles')->assertOk();
        $second = $this->getJson('/api/admin/vehicles?page=2')->assertOk();

        expect($first->json('data'))->toHaveCount(20)
            ->and($first->json('meta.last_page'))->toBe(2)
            ->and($second->json('data'))->toHaveCount(3);
    });
});

describe('adding a vehicle', function () {
    it('creates one and answers with its card', function () {
        signedInAdmin();

        $response = $this->postJson('/api/admin/vehicles', [
            'model' => 'ZZZ Test Bus', 'condition' => 'Excellent', 'seats' => 30, 'pax' => 28, 'description' => 'ZZZ big',
        ])->assertCreated();

        $response->assertJsonPath('data.model', 'ZZZ Test Bus')
            ->assertJsonPath('data.condition', 'Excellent')
            ->assertJsonPath('data.seats', 30)
            ->assertJsonPath('data.stats.hire_count', 0)
            ->assertJsonPath('data.stats.counts.all', 0);
        expect(Vehicle::where('model', 'ZZZ Test Bus')->exists())->toBeTrue();
    });

    it('accepts a vehicle without a description', function () {
        signedInAdmin();

        $this->postJson('/api/admin/vehicles', ['model' => 'ZZZ Test Bus', 'condition' => 'Good', 'seats' => 2, 'pax' => 2])
            ->assertCreated()
            ->assertJsonPath('data.description', null);
    });

    it('needs vehicles.create', function () {
        signedInAdmin(['vehicles.view', 'hires.view']);

        $this->postJson('/api/admin/vehicles', ['model' => 'ZZZ Test Bus', 'condition' => 'Good', 'seats' => 2, 'pax' => 2])
            ->assertForbidden();
        expect(Vehicle::count())->toBe(0);
    });

    it('rejects bad input with the reason', function (array $payload, string $field) {
        signedInAdmin();

        $this->postJson('/api/admin/vehicles', $payload + ['model' => 'ZZZ Test Bus', 'condition' => 'Good', 'seats' => 4, 'pax' => 4])
            ->assertUnprocessable()
            ->assertJsonValidationErrors($field);
        expect(Vehicle::count())->toBe(0);
    })->with([
        'no model' => [['model' => ''], 'model'],
        'unknown condition' => [['condition' => 'Shiny'], 'condition'],
        'no seats' => [['seats' => 0], 'seats'],
        'too many seats' => [['seats' => 101], 'seats'],
        'passengers not a number' => [['pax' => 'lots'], 'pax'],
    ]);
});

describe('one vehicle', function () {
    it('shows its card with the numbers', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();
        vehicleHire($vehicle, ['start_time' => '2026-09-16 09:00:00']);
        vehicleHire($vehicle, ['start_time' => '2026-09-20 09:00:00']);

        $this->getJson("/api/admin/vehicles/{$vehicle->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $vehicle->id)
            ->assertJsonPath('data.stats.counts.today', 1)
            ->assertJsonPath('data.stats.counts.scheduled', 1)
            ->assertJsonPath('data.stats.hire_count', 2);
    });

    it('is 404 for a vehicle that does not exist', function () {
        signedInAdmin();

        $this->getJson('/api/admin/vehicles/999')->assertNotFound();
    });
});

describe('a vehicle\'s hires by tab', function () {
    function tabbedVehicle(): Vehicle
    {
        $vehicle = fleetVehicle();
        vehicleHire($vehicle, ['description' => 'ZZZ today', 'start_time' => '2026-09-16 09:00:00']);
        vehicleHire($vehicle, ['description' => 'ZZZ running', 'start_time' => '2026-09-16 15:00:00', 'status' => 'started']);
        vehicleHire($vehicle, ['description' => 'ZZZ later', 'start_time' => '2026-09-22 09:00:00']);
        vehicleHire($vehicle, ['description' => 'ZZZ soon', 'start_time' => '2026-09-18 09:00:00']);
        vehicleHire($vehicle, ['description' => 'ZZZ done old', 'start_time' => '2026-08-01 09:00:00', 'status' => 'completed']);
        vehicleHire($vehicle, ['description' => 'ZZZ done new', 'start_time' => '2026-09-10 09:00:00', 'status' => 'completed']);
        vehicleHire($vehicle, ['description' => 'ZZZ off', 'start_time' => '2026-09-12 09:00:00', 'status' => 'cancelled', 'cancelled_at' => '2026-09-11 10:00:00', 'cancel_reason' => 'ZZZ customer changed plans']);

        return $vehicle;
    }

    function tabDescriptions(string $tab, Vehicle $vehicle): array
    {
        return collect(test()->getJson("/api/admin/vehicles/{$vehicle->id}/hires?tab={$tab}")->assertOk()->json('data'))
            ->pluck('description')->all();
    }

    it('lists every hire under "all", latest day first', function () {
        signedInAdmin();
        $vehicle = tabbedVehicle();

        expect(tabDescriptions('all', $vehicle))->toBe([
            'ZZZ later', 'ZZZ soon', 'ZZZ running', 'ZZZ today', 'ZZZ off', 'ZZZ done new', 'ZZZ done old',
        ]);
    });

    it('defaults to "all"', function () {
        signedInAdmin();
        $vehicle = tabbedVehicle();

        $response = $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires")->assertOk();

        expect($response->json('data'))->toHaveCount(7);
    });

    it('lists today\'s hires with the running one first', function () {
        signedInAdmin();
        $vehicle = tabbedVehicle();

        expect(tabDescriptions('today', $vehicle))->toBe(['ZZZ running', 'ZZZ today']);
    });

    it('lists scheduled hires soonest first', function () {
        signedInAdmin();
        $vehicle = tabbedVehicle();

        expect(tabDescriptions('scheduled', $vehicle))->toBe(['ZZZ soon', 'ZZZ later']);
    });

    it('lists completed and cancelled hires', function () {
        signedInAdmin();
        $vehicle = tabbedVehicle();

        expect(tabDescriptions('completed', $vehicle))->toBe(['ZZZ done new', 'ZZZ done old'])
            ->and(tabDescriptions('cancelled', $vehicle))->toBe(['ZZZ off']);
    });

    it('agrees with the tab counts on the card', function () {
        signedInAdmin();
        $vehicle = tabbedVehicle();

        $counts = $this->getJson("/api/admin/vehicles/{$vehicle->id}")->json('data.stats.counts');

        foreach (['all', 'today', 'scheduled', 'completed', 'cancelled'] as $tab) {
            expect(count(tabDescriptions($tab, $vehicle)))->toBe($counts[$tab], $tab);
        }
    });

    it('only ever lists this vehicle\'s hires', function () {
        signedInAdmin();
        $vehicle = fleetVehicle('ZZZ Test Van');
        $other = fleetVehicle('ZZZ Test Car');
        vehicleHire($vehicle, ['description' => 'ZZZ mine']);
        vehicleHire($other, ['description' => 'ZZZ theirs']);
        vehicleHire($other, ['description' => 'ZZZ nobody', 'vehicle_id' => null]);

        expect(tabDescriptions('all', $vehicle))->toBe(['ZZZ mine']);
    });

    it('carries the cancellation with a cancelled hire', function () {
        signedInAdmin();
        $vehicle = tabbedVehicle();

        $hire = $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?tab=cancelled")->json('data.0');

        expect($hire['status'])->toBe('cancelled')
            ->and($hire['cancel_reason'])->toBe('ZZZ customer changed plans')
            ->and($hire['cancelled_at'])->not->toBeNull();
    });

    it('carries the customer, driver and vehicle on each hire', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();
        $customer = Customer::create(['name' => 'ZZZ Test Customer', 'phone' => '0770000000']);
        vehicleHire($vehicle, ['customer_id' => $customer->id]);

        $hire = $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires")->json('data.0');

        expect($hire['customer']['name'])->toBe('ZZZ Test Customer')
            ->and($hire['vehicle']['id'])->toBe($vehicle->id);
    });

    it('pages a long tab', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();
        foreach (range(1, 25) as $day) {
            vehicleHire($vehicle, ['start_time' => Carbon::parse('2026-10-01 09:00:00')->addDays($day)]);
        }

        $first = $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?tab=scheduled&per_page=10")->assertOk();
        $last = $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?tab=scheduled&per_page=10&page=3")->assertOk();

        expect($first->json('data'))->toHaveCount(10)
            ->and($first->json('meta.last_page'))->toBe(3)
            ->and($last->json('data'))->toHaveCount(5);
    });

    it('rejects an unknown tab or an absurd page size', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();

        $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?tab=someday")->assertUnprocessable();
        $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?per_page=500")->assertUnprocessable();
    });
});

describe('creating a hire for a vehicle', function () {
    it('lands in that vehicle\'s tabs', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();
        $customer = Customer::create(['name' => 'ZZZ Test Customer', 'phone' => '0770000000']);

        $this->postJson('/api/admin/hires', [
            'tour_type' => 'drop_pickup', 'customer_id' => $customer->id, 'vehicle_id' => $vehicle->id,
            'hire_full_value' => 1000, 'our_hire_value' => 800, 'payment_type' => 'cash',
            'from_location_name' => 'ZZZ Test From', 'to_location_name' => 'ZZZ Test To',
            'start_time' => '2026-09-25 09:00:00', 'description' => 'ZZZ from the vehicle page',
        ])->assertCreated()->assertJsonPath('data.vehicle.id', $vehicle->id);

        $counts = $this->getJson("/api/admin/vehicles/{$vehicle->id}")->json('data.stats.counts');
        $scheduled = $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?tab=scheduled")->json('data');

        expect($counts['scheduled'])->toBe(1)->and($counts['all'])->toBe(1)
            ->and($scheduled[0]['description'])->toBe('ZZZ from the vehicle page');
    });
});

describe('the tab scope', function () {
    it('splits open hires between today and scheduled with nothing lost or doubled', function () {
        $vehicle = fleetVehicle();
        foreach (['2026-09-15 00:00:00', '2026-09-16 00:00:00', '2026-09-16 23:59:59', '2026-09-17 00:00:00', '2026-12-31 10:00:00', null] as $start) {
            vehicleHire($vehicle, ['start_time' => $start]);
        }

        $today = Hire::tab('today')->count();
        $scheduled = Hire::tab('scheduled')->count();

        expect($today)->toBe(4)->and($scheduled)->toBe(2)->and($today + $scheduled)->toBe(Hire::statusGroup('open')->count());
    });

    it('leaves finished hires out of today and scheduled', function () {
        $vehicle = fleetVehicle();
        vehicleHire($vehicle, ['start_time' => '2026-09-16 09:00:00', 'status' => 'completed']);
        vehicleHire($vehicle, ['start_time' => '2026-09-20 09:00:00', 'status' => 'cancelled']);

        expect(Hire::tab('today')->count())->toBe(0)
            ->and(Hire::tab('scheduled')->count())->toBe(0)
            ->and(Hire::tab('all')->count())->toBe(2);
    });
});

describe('the condition filter', function () {
    it('lists only vehicles in that condition', function () {
        signedInAdmin();
        fleetVehicle('ZZZ Test Van', ['condition' => 'Good']);
        fleetVehicle('ZZZ Test Car', ['condition' => 'Poor']);
        fleetVehicle('ZZZ Test Bus', ['condition' => 'Good']);

        $good = $this->getJson('/api/admin/vehicles?condition=Good')->assertOk()->json('data');

        expect(collect($good)->pluck('model')->all())->toBe(['ZZZ Test Bus', 'ZZZ Test Van']);
    });

    it('combines with the search', function () {
        signedInAdmin();
        fleetVehicle('ZZZ Test Van', ['condition' => 'Good']);
        fleetVehicle('ZZZ Test Bus', ['condition' => 'Good']);
        fleetVehicle('ZZZ Test Van Two', ['condition' => 'Poor']);

        $found = $this->getJson('/api/admin/vehicles?condition=Good&search=Van')->json('data');

        expect(collect($found)->pluck('model')->all())->toBe(['ZZZ Test Van']);
    });

    it('rejects a condition that does not exist', function () {
        signedInAdmin();

        $this->getJson('/api/admin/vehicles?condition=Shiny')->assertUnprocessable();
    });
});

describe('the period filter on one vehicle', function () {
    function periodVehicle(): Vehicle
    {
        $vehicle = fleetVehicle();
        vehicleHire($vehicle, ['description' => 'ZZZ sep 1', 'start_time' => '2026-09-03 09:00:00', 'status' => 'completed', 'hire_full_value' => 1000, 'our_hire_value' => 700]);
        vehicleHire($vehicle, ['description' => 'ZZZ sep 2', 'start_time' => '2026-09-25 09:00:00', 'hire_full_value' => 500, 'our_hire_value' => 400]);
        vehicleHire($vehicle, ['description' => 'ZZZ aug', 'start_time' => '2026-08-30 09:00:00', 'status' => 'completed', 'hire_full_value' => 9000, 'our_hire_value' => 8000]);
        vehicleHire($vehicle, ['description' => 'ZZZ aug off', 'start_time' => '2026-08-12 09:00:00', 'status' => 'cancelled']);
        vehicleHire($vehicle, ['description' => 'ZZZ last year', 'start_time' => '2025-12-20 09:00:00', 'status' => 'completed']);

        return $vehicle;
    }

    it('lists only that month\'s hires, on any tab', function () {
        signedInAdmin();
        $vehicle = periodVehicle();

        $sept = collect($this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?year=2026&month=9")->json('data'))->pluck('description')->all();
        $augCompleted = collect($this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?tab=completed&year=2026&month=8")->json('data'))->pluck('description')->all();
        $augCancelled = collect($this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?tab=cancelled&year=2026&month=8")->json('data'))->pluck('description')->all();

        expect($sept)->toBe(['ZZZ sep 2', 'ZZZ sep 1'])
            ->and($augCompleted)->toBe(['ZZZ aug'])
            ->and($augCancelled)->toBe(['ZZZ aug off']);
    });

    it('lists a whole year when no month is given', function () {
        signedInAdmin();
        $vehicle = periodVehicle();

        $year = collect($this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?year=2026")->json('data'))->pluck('description');
        $lastYear = collect($this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?year=2025")->json('data'))->pluck('description')->all();

        expect($year)->toHaveCount(4)->and($lastYear)->toBe(['ZZZ last year']);
    });

    it('makes the vehicle\'s numbers follow the period', function () {
        signedInAdmin();
        $vehicle = periodVehicle();

        $august = $this->getJson("/api/admin/vehicles/{$vehicle->id}?year=2026&month=8")->assertOk()->json('data.stats');
        $september = $this->getJson("/api/admin/vehicles/{$vehicle->id}?year=2026&month=9")->json('data.stats');
        $allTime = $this->getJson("/api/admin/vehicles/{$vehicle->id}")->json('data.stats');

        expect($august['hire_count'])->toBe(1)
            ->and($august['hire_full_value_total'])->toEqual(9000)
            ->and($august['commission_total'])->toEqual(1000)
            ->and($august['counts'])->toBe(['all' => 2, 'today' => 0, 'scheduled' => 0, 'completed' => 1, 'cancelled' => 1, 'running' => 0])
            ->and($september['hire_count'])->toBe(2)
            ->and($september['hire_full_value_total'])->toEqual(1500)
            ->and($september['counts']['all'])->toBe(2)
            ->and($allTime['counts']['all'])->toBe(5);
    });

    it('leaves the "this month" figures relative to now', function () {
        signedInAdmin();
        $vehicle = periodVehicle();

        $stats = $this->getJson("/api/admin/vehicles/{$vehicle->id}?year=2025&month=12")->json('data.stats');

        expect($stats['month']['hire_count'])->toBe(2); // September 2026, whatever period is being viewed
    });

    it('needs a year when a month is given, and rejects nonsense', function (string $query) {
        signedInAdmin();
        $vehicle = fleetVehicle();

        $this->getJson("/api/admin/vehicles/{$vehicle->id}/hires?{$query}")->assertUnprocessable();
        $this->getJson("/api/admin/vehicles/{$vehicle->id}?{$query}")->assertUnprocessable();
    })->with(['month=9', 'year=2026&month=13', 'year=2026&month=0', 'year=abc']);

    it('offers the years and months this vehicle has hires in, latest first', function () {
        signedInAdmin();
        $vehicle = periodVehicle();

        $this->getJson("/api/admin/vehicles/{$vehicle->id}/periods")
            ->assertOk()
            ->assertExactJson(['years' => [2026, 2025], 'months_by_year' => ['2026' => [9, 8], '2025' => [12]]]);
    });

    it('offers no periods for a vehicle without hires — and an object, not a list', function () {
        signedInAdmin();
        $vehicle = fleetVehicle();

        $response = $this->get("/api/admin/vehicles/{$vehicle->id}/periods", ['Accept' => 'application/json'])->assertOk();

        expect($response->getContent())->toBe('{"years":[],"months_by_year":{}}');
    });

    it('does not offer another vehicle\'s periods', function () {
        signedInAdmin();
        $vehicle = fleetVehicle('ZZZ Test Van');
        $other = fleetVehicle('ZZZ Test Car');
        vehicleHire($other, ['start_time' => '2024-01-05 09:00:00']);

        $this->getJson("/api/admin/vehicles/{$vehicle->id}/periods")->assertExactJson(['years' => [], 'months_by_year' => []]);
    });

    it('needs hires.view to see periods', function () {
        $vehicle = fleetVehicle();
        signedInAdmin(['vehicles.view']);

        $this->getJson("/api/admin/vehicles/{$vehicle->id}/periods")->assertForbidden();
    });
});
