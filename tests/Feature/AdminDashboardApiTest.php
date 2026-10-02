<?php

use App\Models\Hire;
use App\Models\HireExpense;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    // Wednesday midday, mid-September — "this month" below is September 2026.
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function apiDashboardAdmin(array $permissions = ['drivers.view']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function apiDashboardVehicle(array $attributes = []): Vehicle
{
    return Vehicle::create($attributes + ['model' => 'ZZZ Prius', 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

function apiDashboardHire(array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 10000, 'our_hire_value' => 7000,
        'payment_type' => 'cash', 'start_time' => '2026-09-10 09:00:00',
    ]);
}

it('is forbidden without the drivers.view permission', function () {
    apiDashboardAdmin([]);

    $this->getJson('/api/admin/dashboard')->assertForbidden();
});

it('defaults to the current month and returns the six summary figures', function () {
    apiDashboardAdmin();
    $hire = apiDashboardHire();
    HireExpense::create(['hire_id' => $hire->id, 'category' => 'fuel', 'amount' => 500]);

    $response = $this->getJson('/api/admin/dashboard');

    $response->assertOk();
    $response->assertJson([
        'year' => 2026,
        'month' => 9,
        'period_label' => 'September 2026',
        'summary' => [
            'hire_full_value_total' => 10000,
            'our_hire_value_total' => 7000,
            'commission_total' => 3000,
            'expenses_total' => 500,
            'salary_total' => 1300, // 20% of (7000 - 500)
            'profit_total' => 5200, // (7000 - 500) - 1300
        ],
    ]);
});

it('accepts an explicit year and month', function () {
    apiDashboardAdmin();
    apiDashboardHire(['hire_full_value' => 20000, 'our_hire_value' => 15000, 'start_time' => '2026-07-10 09:00:00']);

    $response = $this->getJson('/api/admin/dashboard?year=2026&month=7');

    $response->assertOk();
    $response->assertJson([
        'year' => 2026,
        'month' => 7,
        'period_label' => 'July 2026',
        'summary' => [
            'hire_full_value_total' => 20000,
            'our_hire_value_total' => 15000,
        ],
    ]);
});

it('computes a percent delta against the previous month', function () {
    apiDashboardAdmin();
    apiDashboardHire(['hire_full_value' => 10000, 'our_hire_value' => 10000, 'start_time' => '2026-08-10 09:00:00']);
    apiDashboardHire(['hire_full_value' => 15000, 'our_hire_value' => 15000, 'start_time' => '2026-09-10 09:00:00']);

    $response = $this->getJson('/api/admin/dashboard');

    $response->assertJson(['deltas' => ['our_hire_value_total' => 50.0]]); // 10000 -> 15000
});

it('returns one vehicle card per vehicle, scoped to only that vehicle\'s hires', function () {
    apiDashboardAdmin();
    $prius = apiDashboardVehicle(['model' => 'ZZZ Prius']);
    $axio = apiDashboardVehicle(['model' => 'ZZZ Axio']);
    apiDashboardHire(['vehicle_id' => $prius->id, 'hire_full_value' => 10000, 'our_hire_value' => 7000]);
    apiDashboardHire(['vehicle_id' => $axio->id, 'hire_full_value' => 4000, 'our_hire_value' => 3000]);

    $response = $this->getJson('/api/admin/dashboard');

    $response->assertOk();
    $cards = collect($response->json('vehicle_cards'));
    expect($cards)->toHaveCount(2);

    $priusCard = $cards->firstWhere('id', $prius->id);
    expect($priusCard['hire_full_value_total'])->toEqual(10000);
    expect($priusCard['our_hire_value_total'])->toEqual(7000);

    $axioCard = $cards->firstWhere('id', $axio->id);
    expect($axioCard['hire_full_value_total'])->toEqual(4000);
    expect($axioCard['our_hire_value_total'])->toEqual(3000);
});

it('shows a vehicle card with all-zero figures when it has no hires this month', function () {
    apiDashboardAdmin();
    $idle = apiDashboardVehicle(['model' => 'ZZZ Idle']);

    $response = $this->getJson('/api/admin/dashboard');

    $card = collect($response->json('vehicle_cards'))->firstWhere('id', $idle->id);
    expect($card['hire_full_value_total'])->toEqual(0);
    expect($card['profit_total'])->toEqual(0);
});
