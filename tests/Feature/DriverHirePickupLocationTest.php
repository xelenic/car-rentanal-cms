<?php

use App\Models\Driver;
use App\Models\Hire;
use App\Models\HireLocation;
use App\Models\Location;
use App\Models\Package;
use App\Models\PackageItinerary;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

function driverWithHire(array $hireAttributes = []): array
{
    $user = User::factory()->create();
    $driver = Driver::create([
        'user_id' => $user->id,
        'name' => 'Test Driver',
        'license' => 'B123',
        'contact_number' => '0770000000',
        'email' => 'driver@example.test',
        'password' => 'secret-pass',
    ]);
    $hire = Hire::create($hireAttributes + [
        'tour_type' => 'drop_pickup',
        'hire_full_value' => 1000,
        'our_hire_value' => 800,
        'payment_type' => 'cash',
        'driver_id' => $driver->id,
    ]);

    Sanctum::actingAs($user);

    return [$driver, $hire];
}

function hireLocation(Hire $hire, string $role, Location $location, array $extra = []): void
{
    HireLocation::create(['hire_id' => $hire->id, 'location_id' => $location->id, 'role' => $role] + $extra);
}

test('a drop-and-pickup hire reports its "from" location with coordinates as the pickup location', function () {
    [, $hire] = driverWithHire();
    hireLocation($hire, 'to', Location::create(['name' => 'Ella', 'latitude' => 6.87, 'longitude' => 81.05]));
    hireLocation($hire, 'from', Location::create(['name' => 'Colombo Fort', 'latitude' => 6.9344, 'longitude' => 79.8428]));

    $this->getJson('/api/driver/hires')
        ->assertOk()
        ->assertJsonPath('data.0.pickup_location', ['name' => 'Colombo Fort', 'latitude' => 6.9344, 'longitude' => 79.8428]);
});

test('a multi day hire uses its first stay, ordered by day then position', function () {
    [, $hire] = driverWithHire(['tour_type' => 'multi_day']);
    hireLocation($hire, 'stay', Location::create(['name' => 'Kandy', 'latitude' => 7.29, 'longitude' => 80.63]), ['day_number' => 2, 'order' => 1]);
    hireLocation($hire, 'stay', Location::create(['name' => 'Sigiriya', 'latitude' => 7.95, 'longitude' => 80.76]), ['day_number' => 1, 'order' => 2]);
    hireLocation($hire, 'stay', Location::create(['name' => 'Dambulla', 'latitude' => 7.86, 'longitude' => 80.65]), ['day_number' => 1, 'order' => 1]);

    $this->getJson('/api/driver/hires')->assertJsonPath('data.0.pickup_location.name', 'Dambulla');
});

test('a package hire falls back to the first stop of the package itinerary', function () {
    $package = Package::create(['name' => 'Hill Country', 'hours' => 24, 'price' => 5000]);
    PackageItinerary::create(['package_id' => $package->id, 'location_id' => Location::create(['name' => 'Nuwara Eliya', 'latitude' => 6.97, 'longitude' => 80.78])->id, 'order' => 2]);
    PackageItinerary::create(['package_id' => $package->id, 'location_id' => Location::create(['name' => 'Kandy', 'latitude' => 7.29, 'longitude' => 80.63])->id, 'order' => 1]);
    driverWithHire(['tour_type' => 'package', 'package_id' => $package->id]);

    $this->getJson('/api/driver/hires')->assertJsonPath('data.0.pickup_location.name', 'Kandy');
});

test('the pickup location is null when the location has no saved coordinates', function () {
    [, $hire] = driverWithHire();
    hireLocation($hire, 'from', Location::create(['name' => 'Somewhere', 'latitude' => null, 'longitude' => null]));

    $this->getJson('/api/driver/hires')
        ->assertOk()
        ->assertJsonPath('data.0.pickup_location', null)
        // the plain name is still there for the existing screens
        ->assertJsonPath('data.0.from_location', 'Somewhere');
});

test('the pickup location is null when the hire has no locations at all', function () {
    driverWithHire();

    $this->getJson('/api/driver/hires')->assertOk()->assertJsonPath('data.0.pickup_location', null);
});
