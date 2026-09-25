<?php

use App\Models\Driver;
use App\Models\Hire;
use App\Models\HireTrackingPoint;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

function trackedHireFor(User $user, array $attributes = []): Hire
{
    $driver = Driver::create([
        'user_id' => $user->id,
        'name' => 'Driver '.$user->id,
        'license' => 'B'.$user->id,
        'contact_number' => '0770000000',
        'email' => "driver{$user->id}@example.test",
        'password' => 'secret-pass',
    ]);

    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup',
        'hire_full_value' => 1000,
        'our_hire_value' => 800,
        'payment_type' => 'cash',
        'driver_id' => $driver->id,
        'status' => 'started',
        'tracking_started_at' => now()->subHour(),
    ]);
}

test('a driver can read the path recorded so far on their own hire, oldest point first', function () {
    $user = User::factory()->create();
    $hire = trackedHireFor($user);
    // saved out of order on purpose — the path must come back in time order
    HireTrackingPoint::create(['hire_id' => $hire->id, 'latitude' => 6.95, 'longitude' => 79.90, 'recorded_at' => now()->subMinutes(10)]);
    HireTrackingPoint::create(['hire_id' => $hire->id, 'latitude' => 6.93, 'longitude' => 79.84, 'recorded_at' => now()->subMinutes(30)]);
    Sanctum::actingAs($user);

    $this->getJson("/api/driver/hires/{$hire->id}/tracking")
        ->assertOk()
        ->assertJsonPath('status', 'started')
        ->assertJsonPath('is_tracking', true)
        ->assertJsonPath('points', [
            ['lat' => 6.93, 'lng' => 79.84],
            ['lat' => 6.95, 'lng' => 79.9],
        ]);
});

test('it is read-only: reading the path changes nothing', function () {
    $user = User::factory()->create();
    $hire = trackedHireFor($user);
    Sanctum::actingAs($user);

    $this->getJson("/api/driver/hires/{$hire->id}/tracking")->assertOk();

    $hire->refresh();
    expect($hire->tracking_stopped_at)->toBeNull()->and($hire->status)->toBe('started');
    expect(HireTrackingPoint::count())->toBe(0);
});

test('a driver cannot read another driver\'s path', function () {
    $owner = User::factory()->create();
    $hire = trackedHireFor($owner);
    HireTrackingPoint::create(['hire_id' => $hire->id, 'latitude' => 6.93, 'longitude' => 79.84, 'recorded_at' => now()]);

    $intruder = User::factory()->create();
    Driver::create(['user_id' => $intruder->id, 'name' => 'Other', 'license' => 'X1', 'contact_number' => '1', 'email' => 'other@example.test', 'password' => 'secret-pass']);
    Sanctum::actingAs($intruder);

    $this->getJson("/api/driver/hires/{$hire->id}/tracking")->assertForbidden();
});

test('a signed-out request is rejected', function () {
    $hire = trackedHireFor(User::factory()->create());

    $this->getJson("/api/driver/hires/{$hire->id}/tracking")->assertUnauthorized();
});
