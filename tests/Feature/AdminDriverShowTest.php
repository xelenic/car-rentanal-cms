<?php

use App\Models\Customer;
use App\Models\Driver;
use App\Models\Hire;
use App\Models\HireExpense;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function driverShowAdmin(array $permissions = ['drivers.view']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function driverShowDriver(string $name = 'ZZZ Nimal'): Driver
{
    return Driver::create([
        'name' => $name,
        'license' => 'ZZZ-'.$name,
        'contact_number' => '0770000000',
        'email' => strtolower(str_replace(' ', '.', $name)).'@example.com',
        'password' => bcrypt('testpass123'),
    ]);
}

function driverShowVehicle(string $model = 'ZZZ Prius'): Vehicle
{
    return Vehicle::create(['model' => $model, 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

function driverShowCustomer(string $name = 'ZZZ Customer'): Customer
{
    return Customer::create(['name' => $name, 'phone' => '0770000000']);
}

function driverShowHire(array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 3500,
        'payment_type' => 'cash', 'start_time' => now()->subDay(),
    ]);
}

it('is forbidden without the drivers.view permission', function () {
    $driver = driverShowDriver();
    driverShowAdmin([]);

    $this->get('/admin/drivers/'.$driver->id)->assertForbidden();
});

it('shows the driver\'s name, license and contact details', function () {
    driverShowAdmin();
    $driver = driverShowDriver('ZZZ Sunil');

    $response = $this->get('/admin/drivers/'.$driver->id);

    $response->assertOk();
    $response->assertSee('ZZZ Sunil');
    $response->assertSee('ZZZ-ZZZ Sunil');
    $response->assertSee('0770000000');
    $response->assertSee('zzz.sunil@example.com');
});

it('totals this driver\'s hires across all time for the summary cards, excluding cancelled ones', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $someoneElse = driverShowDriver('ZZZ Kamal');

    driverShowHire(['driver_id' => $driver->id, 'hire_full_value' => 5000, 'our_hire_value' => 3500]);
    driverShowHire(['driver_id' => $driver->id, 'hire_full_value' => 3000, 'our_hire_value' => 2000]);
    driverShowHire(['driver_id' => $driver->id, 'hire_full_value' => 9999, 'our_hire_value' => 9999, 'status' => 'cancelled']);
    driverShowHire(['driver_id' => $someoneElse->id, 'hire_full_value' => 7777, 'our_hire_value' => 7777]);

    $response = $this->get('/admin/drivers/'.$driver->id);

    $response->assertOk();
    $response->assertViewHas('summary', function (array $summary) {
        return $summary['hire_count'] === 2
            && $summary['hire_full_value_total'] === 8000.0
            && $summary['commission_total'] === 2500.0;
    });
});

it('lists only the selected driver\'s hires for the selected month', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $customer = driverShowCustomer('ZZZ Amal');
    $vehicle = driverShowVehicle();

    driverShowHire([
        'driver_id' => $driver->id, 'customer_id' => $customer->id, 'vehicle_id' => $vehicle->id,
        'start_time' => '2026-09-15 10:00:00', 'hire_full_value' => 4001,
    ]);
    driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-08-15 10:00:00', 'hire_full_value' => 4002]);
    driverShowHire([
        'driver_id' => driverShowDriver('ZZZ Kamal')->id, 'start_time' => '2026-09-15 10:00:00', 'hire_full_value' => 4003,
    ]);

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

    $response->assertOk();
    $response->assertSee('Rs. 4,001.00');
    $response->assertDontSee('Rs. 4,002.00');
    $response->assertDontSee('Rs. 4,003.00');
    $response->assertSee('ZZZ Amal');
    $response->assertSee('ZZZ Prius');
});

it('matches an unscheduled hire into the month it was recorded', function () {
    driverShowAdmin();
    $driver = driverShowDriver();

    $unscheduled = driverShowHire(['driver_id' => $driver->id, 'start_time' => null, 'hire_full_value' => 4567]);
    $unscheduled->forceFill(['created_at' => '2026-09-20 10:00:00'])->saveQuietly();

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

    $response->assertOk();
    $response->assertSee('Rs. 4,567.00');
});

it('lists only the selected driver\'s expenses for the selected month, with category and amount', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $someoneElse = driverShowDriver('ZZZ Kamal');

    test()->travelTo(\Illuminate\Support\Carbon::parse('2026-09-16 12:00:00'));
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 1500]);
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'parking', 'amount' => 250]);
    HireExpense::create(['driver_id' => $someoneElse->id, 'category' => 'fuel', 'amount' => 9999]);

    test()->travelTo(\Illuminate\Support\Carbon::parse('2026-08-16 12:00:00'));
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'repair', 'amount' => 7777]);

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

    $response->assertOk();
    $response->assertSee('Fuel');
    $response->assertSee('Rs. 1,500.00');
    $response->assertSee('Parking Tickets');
    $response->assertSee('Rs. 250.00');
    $response->assertDontSee('Rs. 9,999.00');
    $response->assertDontSee('Rs. 7,777.00');
    $response->assertViewHas('periodSummary', fn (array $summary) => $summary['expenses_total'] === 1750.0);
});

it('totals this driver\'s expenses across all time for the summary card', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $someoneElse = driverShowDriver('ZZZ Kamal');

    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 1000]);
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'repair', 'amount' => 2000]);
    HireExpense::create(['driver_id' => $someoneElse->id, 'category' => 'fuel', 'amount' => 9999]);

    $response = $this->get('/admin/drivers/'.$driver->id);

    $response->assertOk();
    $response->assertViewHas('summary', fn (array $summary) => $summary['expenses_total'] === 3000.0);
});

it('links to the receipt when an expense has one, and shows a hire\'s tour type when tied to one', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $hire = driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00']);

    test()->travelTo(\Illuminate\Support\Carbon::parse('2026-09-16 12:00:00'));
    HireExpense::create([
        'driver_id' => $driver->id, 'hire_id' => $hire->id, 'category' => 'fuel', 'amount' => 800,
        'receipt_path' => 'hire-expenses/'.$hire->id.'/receipt.jpg',
    ]);

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

    $response->assertOk();
    $response->assertSee('Drop and Pickup');
    $response->assertSee(route('hire-expenses.receipt', HireExpense::first()));
});
