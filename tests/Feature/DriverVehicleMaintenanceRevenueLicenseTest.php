<?php

use App\Models\Driver;
use App\Models\User;
use App\Models\Vehicle;
use App\Models\VehicleMaintenanceRecord;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

function revenueLicenseDriver(): Driver
{
    $user = User::factory()->create();
    $driver = Driver::create([
        'user_id' => $user->id, 'name' => 'ZZZ Driver', 'license' => 'ZZZ-B1', 'contact_number' => '0770000000',
        'email' => uniqid('driver').'@example.test', 'password' => 'secret-pass',
    ]);
    Sanctum::actingAs($user);

    return $driver;
}

function revenueLicenseVehicle(): Vehicle
{
    return Vehicle::create(['model' => 'ZZZ Prius', 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

test('a driver can log a revenue license renewal with a photo of the license', function () {
    Storage::fake('public');
    $driver = revenueLicenseDriver();
    $vehicle = revenueLicenseVehicle();

    $response = $this->postJson('/api/driver/vehicle-maintenance', [
        'vehicle_id' => $vehicle->id,
        'type' => 'revenue_license',
        'cost' => 3500,
        'description' => 'Annual revenue license renewal',
        'bill' => UploadedFile::fake()->image('license.jpg'),
    ]);

    $response->assertCreated()
        ->assertJsonPath('data.type', 'revenue_license')
        ->assertJsonPath('data.type_label', 'Revenue License')
        ->assertJsonPath('data.cost', 3500);

    $record = VehicleMaintenanceRecord::where('type', 'revenue_license')->first();
    expect($record)->not->toBeNull();
    Storage::disk('public')->assertExists($record->bill_path);
});

test('a revenue license entry needs no mileage, unlike a service entry', function () {
    Storage::fake('public');
    $driver = revenueLicenseDriver();
    $vehicle = revenueLicenseVehicle();

    $this->postJson('/api/driver/vehicle-maintenance', [
        'vehicle_id' => $vehicle->id,
        'type' => 'revenue_license',
        'cost' => 3500,
        'bill' => UploadedFile::fake()->image('license.jpg'),
    ])->assertCreated();
});

test('still requires a photo of the license, same as every other maintenance type', function () {
    $driver = revenueLicenseDriver();
    $vehicle = revenueLicenseVehicle();

    $this->postJson('/api/driver/vehicle-maintenance', [
        'vehicle_id' => $vehicle->id,
        'type' => 'revenue_license',
        'cost' => 3500,
    ])->assertUnprocessable()->assertJsonValidationErrors('bill');
});

test('the list can be filtered down to just revenue license entries', function () {
    $driver = revenueLicenseDriver();
    $vehicle = revenueLicenseVehicle();
    VehicleMaintenanceRecord::create([
        'vehicle_id' => $vehicle->id, 'driver_id' => $driver->id, 'type' => 'revenue_license',
        'cost' => 3500, 'bill_path' => 'x.jpg',
    ]);
    VehicleMaintenanceRecord::create([
        'vehicle_id' => $vehicle->id, 'driver_id' => $driver->id, 'type' => 'repair',
        'cost' => 500, 'bill_path' => 'y.jpg',
    ]);

    $response = $this->getJson('/api/driver/vehicle-maintenance?type=revenue_license')->assertOk();

    expect($response->json('data'))->toHaveCount(1);
    $response->assertJsonPath('data.0.type', 'revenue_license');
});
