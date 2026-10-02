<?php

use App\Models\Hire;
use App\Models\HireExpense;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    // Wednesday midday, mid-September — "this month" below is September 2026.
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function dashboardAdmin(array $permissions = ['drivers.view', 'vehicles.view']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function dashboardVehicle(array $attributes = []): Vehicle
{
    return Vehicle::create($attributes + [
        'model' => 'ZZZ Prius', 'condition' => 'Good', 'seats' => 4, 'pax' => 4,
    ]);
}

function dashboardHire(array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 10000, 'our_hire_value' => 7000,
        'payment_type' => 'cash', 'start_time' => '2026-09-10 09:00:00',
    ]);
}

describe('the six summary cards', function () {
    it('shows them in order: hire value, our hire value, commission, expenses, salary, profit', function () {
        dashboardAdmin();
        $hire = dashboardHire();
        HireExpense::create(['hire_id' => $hire->id, 'category' => 'fuel', 'amount' => 500]);

        $response = $this->get('/admin');

        $response->assertOk();
        $labels = ['Total Hire Value', 'Total Our Hire Value', 'Total Commission', 'Total Expenses', 'Total All Drivers Salary', 'Total Profit'];
        $content = $response->getContent();
        $positions = array_map(fn ($label) => strpos($content, $label), $labels);

        expect($positions)->not->toContain(false);
        expect($positions)->toBe(collect($positions)->sort()->values()->all());
    });

    it('includes this month\'s deductible expenses in the Total Expenses card', function () {
        dashboardAdmin();
        $hire = dashboardHire();
        HireExpense::create(['hire_id' => $hire->id, 'category' => 'fuel', 'amount' => 500]);
        HireExpense::create(['hire_id' => $hire->id, 'category' => 'parking', 'amount' => 150]);
        // Not deductible — must not show up in the total.
        HireExpense::create(['hire_id' => $hire->id, 'category' => 'repair', 'amount' => 9999]);

        $response = $this->get('/admin');

        $response->assertSee('Total Expenses');
        $response->assertSee('Rs. 650.00');
    });
});

describe('Vehicle Cards', function () {
    it('shows one card per vehicle, with its own hire figures', function () {
        dashboardAdmin();
        $prius = dashboardVehicle(['model' => 'ZZZ Prius']);
        $axio = dashboardVehicle(['model' => 'ZZZ Axio']);
        dashboardHire(['vehicle_id' => $prius->id, 'hire_full_value' => 10000, 'our_hire_value' => 7000]);
        dashboardHire(['vehicle_id' => $axio->id, 'hire_full_value' => 4000, 'our_hire_value' => 3000]);

        $response = $this->get('/admin');

        $response->assertSee('Vehicle Cards');
        $response->assertSeeInOrder(['ZZZ Prius', 'Rs. 10,000.00', 'Rs. 7,000.00']);
        $response->assertSeeInOrder(['ZZZ Axio', 'Rs. 4,000.00', 'Rs. 3,000.00']);
    });

    it('does not mix one vehicle\'s hires into another\'s card', function () {
        dashboardAdmin();
        $prius = dashboardVehicle(['model' => 'ZZZ Prius']);
        $axio = dashboardVehicle(['model' => 'ZZZ Axio']);
        dashboardHire(['vehicle_id' => $prius->id, 'hire_full_value' => 10000, 'our_hire_value' => 7000]);

        $response = $this->get('/admin');

        // Axio has no hires this month — its card's figures all read zero.
        $response->assertSeeInOrder(['ZZZ Axio', 'Rs. 0.00']);
    });

    it('shows a friendly empty state with no vehicles at all', function () {
        dashboardAdmin();

        $response = $this->get('/admin');

        $response->assertSee('Vehicle Cards');
        $response->assertSee('No vehicles yet');
    });

    it('is hidden without the vehicles.view permission, even with drivers.view', function () {
        dashboardAdmin(['drivers.view']);
        dashboardVehicle();

        $response = $this->get('/admin');

        $response->assertOk();
        $response->assertDontSee('Vehicle Cards');
    });
});

it('shows nothing financial without the drivers.view permission', function () {
    dashboardAdmin(['vehicles.view']);
    dashboardVehicle();

    $response = $this->get('/admin');

    $response->assertOk();
    $response->assertDontSee('Total Hire Value');
    $response->assertDontSee('Vehicle Cards');
});
