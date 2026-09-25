<?php

use App\Models\Driver;
use App\Models\Hire;
use App\Models\HireExpense;
use App\Models\HireTrackingPoint;
use App\Models\User;
use App\Services\DriverSalaryCalculator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

function cancellableHire(array $attributes = [], bool $signedIn = true): array
{
    $user = User::factory()->create();
    $driver = Driver::create([
        'user_id' => $user->id, 'name' => 'Driver', 'license' => 'B1', 'contact_number' => '077',
        'email' => uniqid('driver').'@example.test', 'password' => 'secret-pass',
    ]);
    $hire = Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 1000, 'our_hire_value' => 800,
        'payment_type' => 'cash', 'driver_id' => $driver->id,
    ]);

    if ($signedIn) {
        Sanctum::actingAs($user);
    }

    return [$user, $driver, $hire];
}

function runningHire(): array
{
    return cancellableHire(['status' => 'started', 'tracking_started_at' => now()->subMinutes(30)]);
}

describe('cancelling a hire', function () {
    test('a hire that has not been started can be cancelled', function () {
        [, , $hire] = cancellableHire();

        $this->postJson("/api/driver/hires/{$hire->id}/cancel")
            ->assertOk()
            ->assertJsonPath('status', 'cancelled')
            ->assertJsonPath('status_label', 'Cancelled')
            ->assertJsonPath('is_tracking', false);

        $hire->refresh();
        expect($hire->status)->toBe('cancelled')
            ->and($hire->is_cancelled)->toBeTrue()
            ->and($hire->cancelled_at)->not->toBeNull()
            ->and($hire->tracking_started_at)->toBeNull()
            ->and($hire->tracking_stopped_at)->toBeNull(); // there was no tracking to stop
    });

    test('a running hire is cancelled AND its tracking stops', function () {
        [, , $hire] = runningHire();
        expect($hire->is_tracking)->toBeTrue();

        $this->postJson("/api/driver/hires/{$hire->id}/cancel")
            ->assertOk()
            ->assertJsonPath('is_tracking', false);

        $hire->refresh();
        expect($hire->is_tracking)->toBeFalse()
            ->and($hire->tracking_stopped_at)->not->toBeNull()
            ->and($hire->tracking_started_at)->not->toBeNull(); // the history is kept
    });

    test('a hire paused earlier keeps the time its tracking really stopped', function () {
        $stoppedAt = now()->subMinutes(10)->startOfSecond();
        [, , $hire] = cancellableHire([
            'status' => 'started', 'tracking_started_at' => now()->subHour(), 'tracking_stopped_at' => $stoppedAt,
        ]);

        $this->postJson("/api/driver/hires/{$hire->id}/cancel")->assertOk();

        expect($hire->refresh()->tracking_stopped_at->equalTo($stoppedAt))->toBeTrue();
    });

    test('the driver can say why, and it is trimmed and stored', function () {
        [, , $hire] = cancellableHire();

        $this->postJson("/api/driver/hires/{$hire->id}/cancel", ['reason' => '  Customer did not show up  '])->assertOk();

        expect($hire->refresh()->cancel_reason)->toBe('Customer did not show up');
    });

    test('the reason is optional, and a blank one is stored as nothing', function () {
        [, , $hire] = cancellableHire();

        $this->postJson("/api/driver/hires/{$hire->id}/cancel", ['reason' => '   '])->assertOk();

        expect($hire->refresh()->cancel_reason)->toBeNull();
    });

    test('an over-long reason is refused', function () {
        [, , $hire] = cancellableHire();

        $this->postJson("/api/driver/hires/{$hire->id}/cancel", ['reason' => str_repeat('x', 501)])
            ->assertStatus(422)->assertJsonValidationErrors('reason');

        expect($hire->refresh()->status)->toBe('pending');
    });

    test('a completed hire cannot be cancelled', function () {
        [, , $hire] = cancellableHire(['status' => 'completed']);

        $this->postJson("/api/driver/hires/{$hire->id}/cancel")->assertStatus(422);

        expect($hire->refresh()->status)->toBe('completed');
    });

    test('a hire cannot be cancelled twice', function () {
        [, , $hire] = cancellableHire();

        $this->postJson("/api/driver/hires/{$hire->id}/cancel")->assertOk();
        $this->postJson("/api/driver/hires/{$hire->id}/cancel")
            ->assertStatus(422)
            ->assertJsonPath('message', 'This hire was cancelled.');
    });

    test('only the hire\'s own driver can cancel it', function () {
        [, , $hire] = cancellableHire();

        $other = User::factory()->create();
        Driver::create(['user_id' => $other->id, 'name' => 'Other', 'license' => 'X', 'contact_number' => '1', 'email' => 'other@example.test', 'password' => 'secret-pass']);
        Sanctum::actingAs($other);

        $this->postJson("/api/driver/hires/{$hire->id}/cancel")->assertForbidden();
        expect($hire->refresh()->status)->toBe('pending');
    });

    test('a signed-out request is rejected', function () {
        [, , $hire] = cancellableHire(signedIn: false);

        $this->postJson("/api/driver/hires/{$hire->id}/cancel")->assertUnauthorized();
    });
});

describe('a cancelled hire does not continue', function () {
    beforeEach(function () {
        [, , $this->hire] = runningHire();
        $this->postJson("/api/driver/hires/{$this->hire->id}/cancel")->assertOk();
    });

    test('it cannot be started again', function () {
        $this->postJson("/api/driver/hires/{$this->hire->id}/tracking/start")
            ->assertStatus(422)->assertJsonPath('message', 'This hire was cancelled.');

        expect($this->hire->refresh()->is_tracking)->toBeFalse();
    });

    test('it cannot be stopped or completed', function () {
        $this->postJson("/api/driver/hires/{$this->hire->id}/tracking/stop")->assertStatus(422);
        $this->postJson("/api/driver/hires/{$this->hire->id}/tracking/complete")->assertStatus(422);

        expect($this->hire->refresh()->status)->toBe('cancelled');
    });

    test('no more positions are accepted — a phone still pinging is told so', function () {
        $this->postJson("/api/driver/hires/{$this->hire->id}/tracking/points", ['latitude' => 6.9, 'longitude' => 79.8])
            ->assertStatus(422)->assertJsonPath('message', 'This hire was cancelled.');

        expect(HireTrackingPoint::count())->toBe(0);
    });

    test('no route is planned for it', function () {
        $this->getJson("/api/driver/hires/{$this->hire->id}/route?origin_lat=6.9&origin_lng=79.8")->assertStatus(422);
    });

    test('but it can still be read, path and all', function () {
        $this->getJson("/api/driver/hires/{$this->hire->id}/tracking")
            ->assertOk()->assertJsonPath('status', 'cancelled');
    });
});

describe('the driver\'s hire list', function () {
    test('includes cancelled hires, with when and why', function () {
        [, , $hire] = cancellableHire();
        $this->postJson("/api/driver/hires/{$hire->id}/cancel", ['reason' => 'Vehicle breakdown'])->assertOk();

        $this->getJson('/api/driver/hires')
            ->assertOk()
            ->assertJsonPath('data.0.status', 'cancelled')
            ->assertJsonPath('data.0.status_label', 'Cancelled')
            ->assertJsonPath('data.0.cancel_reason', 'Vehicle breakdown')
            ->assertJsonPath('meta.total', 1);
    });

    test('reports a total that leaves cancelled hires out', function () {
        [, $driver, $cancelled] = cancellableHire();
        Hire::create(['tour_type' => 'drop_pickup', 'hire_full_value' => 500, 'our_hire_value' => 400, 'payment_type' => 'cash', 'driver_id' => $driver->id]);
        $this->postJson("/api/driver/hires/{$cancelled->id}/cancel")->assertOk();

        $this->getJson('/api/driver/hires')
            ->assertOk()
            ->assertJsonPath('meta.total', 2)      // both are listed…
            ->assertJsonPath('counted_total', 1);  // …but only one counts
    });
});

describe('money: a cancelled hire earns nothing', function () {
    test('it counts toward no total, commission or hire count in the driver\'s salary', function () {
        [, $driver] = cancellableHire(['hire_full_value' => 1000, 'our_hire_value' => 800]);
        Hire::create(['tour_type' => 'drop_pickup', 'hire_full_value' => 500, 'our_hire_value' => 400, 'payment_type' => 'credit', 'driver_id' => $driver->id]);
        $cancelled = Hire::create(['tour_type' => 'drop_pickup', 'hire_full_value' => 9000, 'our_hire_value' => 7000, 'payment_type' => 'cash', 'driver_id' => $driver->id, 'status' => 'cancelled']);

        $salary = DriverSalaryCalculator::calculate($driver, (int) now()->format('Y'), (int) now()->format('n'));

        // 1000 + 500 (the 9000 cancelled hire is ignored)
        expect($salary['hire_full_value_total'])->toBe(1500.0)
            ->and($salary['our_hire_value_total'])->toBe(1200.0)
            ->and($salary['hire_count'])->toBe(2)
            ->and($salary['salary'])->toBe(240.0); // 20% of 1200
    });

    test('but fuel already spent on it is still deducted', function () {
        [, $driver, $live] = cancellableHire(['hire_full_value' => 1000, 'our_hire_value' => 1000]);
        $cancelled = Hire::create(['tour_type' => 'drop_pickup', 'hire_full_value' => 900, 'our_hire_value' => 900, 'payment_type' => 'cash', 'driver_id' => $driver->id, 'status' => 'cancelled']);
        HireExpense::create(['hire_id' => $cancelled->id, 'driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 200]);

        $salary = DriverSalaryCalculator::calculate($driver, (int) now()->format('Y'), (int) now()->format('n'));

        expect($salary['our_hire_value_total'])->toBe(1000.0)   // the cancelled 900 is not income…
            ->and($salary['expenses_total'])->toBe(200.0);       // …but the 200 of fuel was really spent
    });

    test('the counted() scope leaves cancelled hires out of a query', function () {
        cancellableHire();
        Hire::create(['tour_type' => 'drop_pickup', 'hire_full_value' => 1, 'our_hire_value' => 1, 'payment_type' => 'cash', 'status' => 'cancelled']);

        expect(Hire::count())->toBe(2)->and(Hire::counted()->count())->toBe(1);
    });

    test('the system-wide summary (dashboard) leaves them out too', function () {
        cancellableHire(['hire_full_value' => 1000, 'our_hire_value' => 800]);
        Hire::create(['tour_type' => 'drop_pickup', 'hire_full_value' => 9000, 'our_hire_value' => 7000, 'payment_type' => 'cash', 'status' => 'cancelled']);

        $all = DriverSalaryCalculator::calculateForAllDrivers((int) now()->format('Y'), (int) now()->format('n'));

        expect($all['hire_full_value_total'])->toBe(1000.0)->and($all['hire_count'])->toBe(1);
    });
});
