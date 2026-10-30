<?php

use App\Models\Customer;
use App\Models\Driver;
use App\Models\Hire;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

function customerInfoDriver(): Driver
{
    $user = User::factory()->create();
    $driver = Driver::create([
        'user_id' => $user->id, 'name' => 'ZZZ Driver', 'license' => 'ZZZ-B1', 'contact_number' => '0770000000',
        'email' => uniqid('driver').'@example.test', 'password' => 'secret-pass',
    ]);
    Sanctum::actingAs($user);

    return $driver;
}

test('the hire list includes the customer\'s name and phone, for the Call Customer button', function () {
    $driver = customerInfoDriver();
    $customer = Customer::create(['name' => 'ZZZ Amal Perera', 'phone' => '0712345678']);
    Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => 1000, 'our_hire_value' => 800,
        'payment_type' => 'cash', 'driver_id' => $driver->id, 'customer_id' => $customer->id,
    ]);

    $this->getJson('/api/driver/hires')->assertOk()
        ->assertJsonPath('data.0.customer_name', 'ZZZ Amal Perera')
        ->assertJsonPath('data.0.customer_phone', '0712345678');
});

test('a single hire\'s own page includes the customer\'s name and phone too', function () {
    $driver = customerInfoDriver();
    $customer = Customer::create(['name' => 'ZZZ Nimal Silva', 'phone' => '0719876543']);
    $hire = Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => 1000, 'our_hire_value' => 800,
        'payment_type' => 'cash', 'driver_id' => $driver->id, 'customer_id' => $customer->id,
    ]);

    $this->getJson("/api/driver/hires/{$hire->id}")->assertOk()
        ->assertJsonPath('data.customer_name', 'ZZZ Nimal Silva')
        ->assertJsonPath('data.customer_phone', '0719876543');
});

test('a hire with no customer on record reports null rather than erroring', function () {
    $driver = customerInfoDriver();
    Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => 1000, 'our_hire_value' => 800,
        'payment_type' => 'cash', 'driver_id' => $driver->id,
    ]);

    $this->getJson('/api/driver/hires')->assertOk()
        ->assertJsonPath('data.0.customer_name', null)
        ->assertJsonPath('data.0.customer_phone', null);
});
