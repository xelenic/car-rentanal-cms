<?php

use App\Models\Driver;
use App\Models\Hire;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

function listingDriver(): Driver
{
    $user = User::factory()->create();
    $driver = Driver::create([
        'user_id' => $user->id, 'name' => 'Driver', 'license' => 'B1', 'contact_number' => '077',
        'email' => uniqid('driver').'@example.test', 'password' => 'secret-pass',
    ]);
    Sanctum::actingAs($user);

    return $driver;
}

function listedHire(Driver $driver, array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 100, 'our_hire_value' => 80,
        'payment_type' => 'cash', 'driver_id' => $driver->id,
    ]);
}

/** A hire scheduled in the given month, so it belongs to that month whenever it was created. */
function hireInMonth(Driver $driver, int $year, int $month, array $attributes = []): Hire
{
    return listedHire($driver, $attributes + ['start_time' => sprintf('%04d-%02d-15 10:00:00', $year, $month)]);
}

describe('filtering by status group', function () {
    beforeEach(function () {
        $this->driver = listingDriver();
        listedHire($this->driver, ['status' => 'pending']);
        listedHire($this->driver, ['status' => 'started']);
        listedHire($this->driver, ['status' => 'completed']);
        listedHire($this->driver, ['status' => 'completed']);
        listedHire($this->driver, ['status' => 'completed']);
        listedHire($this->driver, ['status' => 'cancelled']);
    });

    test('with no filter every hire is listed', function () {
        $this->getJson('/api/driver/hires')->assertOk()->assertJsonPath('meta.total', 6);
    });

    test('"open" is the hires still to do: pending and started', function () {
        $response = $this->getJson('/api/driver/hires?status=open')->assertOk()->assertJsonPath('meta.total', 2);

        expect(collect($response->json('data'))->pluck('status')->sort()->values()->all())->toBe(['pending', 'started']);
    });

    test('"completed" and "cancelled" are exactly those', function () {
        $this->getJson('/api/driver/hires?status=completed')->assertOk()
            ->assertJsonPath('meta.total', 3)
            ->assertJsonPath('data.0.status', 'completed');

        $this->getJson('/api/driver/hires?status=cancelled')->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.status', 'cancelled');
    });

    test('the filtered total is exact — it is what a tab\'s count shows', function () {
        expect($this->getJson('/api/driver/hires?status=completed&per_page=1')->json('meta.total'))->toBe(3);
    });

    test('an unknown status is refused rather than ignored', function () {
        $this->getJson('/api/driver/hires?status=everything')->assertStatus(422)->assertJsonValidationErrors('status');
    });

    test('the counted total follows the same filter, and never includes cancelled hires', function () {
        $this->getJson('/api/driver/hires?status=completed')->assertJsonPath('counted_total', 3);
        $this->getJson('/api/driver/hires?status=cancelled')->assertJsonPath('counted_total', 0);
        $this->getJson('/api/driver/hires')->assertJsonPath('counted_total', 5);
    });
});

describe('paging', function () {
    beforeEach(function () {
        $this->driver = listingDriver();
        foreach (range(1, 7) as $i) {
            listedHire($this->driver, ['status' => 'completed', 'description' => "hire {$i}"]);
        }
    });

    test('per_page limits a page, and the meta says how many pages there are', function () {
        $this->getJson('/api/driver/hires?status=completed&per_page=5')->assertOk()
            ->assertJsonCount(5, 'data')
            ->assertJsonPath('meta.total', 7)
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.last_page', 2);
    });

    test('the next page continues where the first stopped — nothing repeated, nothing missed', function () {
        $first = collect($this->getJson('/api/driver/hires?status=completed&per_page=5')->json('data'))->pluck('id');
        $second = collect($this->getJson('/api/driver/hires?status=completed&per_page=5&page=2')->json('data'))->pluck('id');

        expect($second)->toHaveCount(2)
            ->and($first->intersect($second))->toBeEmpty()
            ->and($first->merge($second)->unique())->toHaveCount(7);
    });

    test('the default page is the largest allowed (50), as before', function () {
        $this->getJson('/api/driver/hires')->assertOk()->assertJsonPath('meta.per_page', 50);
    });

    test('per_page must be between 1 and 50', function () {
        $this->getJson('/api/driver/hires?per_page=0')->assertStatus(422);
        $this->getJson('/api/driver/hires?per_page=51')->assertStatus(422);
        $this->getJson('/api/driver/hires?per_page=abc')->assertStatus(422);
    });
});

describe('combined with a month', function () {
    test('status and year/month narrow together', function () {
        $driver = listingDriver();
        hireInMonth($driver, 2026, 9, ['status' => 'completed']);
        hireInMonth($driver, 2026, 9, ['status' => 'completed']);
        hireInMonth($driver, 2026, 9, ['status' => 'cancelled']);
        hireInMonth($driver, 2026, 8, ['status' => 'completed']);
        hireInMonth($driver, 2025, 9, ['status' => 'completed']);

        $this->getJson('/api/driver/hires?status=completed&year=2026&month=9')->assertOk()->assertJsonPath('meta.total', 2);
        $this->getJson('/api/driver/hires?status=completed&year=2026')->assertOk()->assertJsonPath('meta.total', 3);
        $this->getJson('/api/driver/hires?status=cancelled&year=2026&month=9')->assertOk()->assertJsonPath('meta.total', 1);
        $this->getJson('/api/driver/hires?status=completed&year=2024')->assertOk()->assertJsonPath('meta.total', 0);
    });
});

describe('periods', function () {
    beforeEach(function () {
        $this->driver = listingDriver();
        hireInMonth($this->driver, 2026, 9, ['status' => 'completed']);
        hireInMonth($this->driver, 2026, 7, ['status' => 'completed']);
        hireInMonth($this->driver, 2025, 12, ['status' => 'cancelled']);
        hireInMonth($this->driver, 2026, 10, ['status' => 'pending']);
    });

    test('with no filter they cover every hire, newest first', function () {
        $this->getJson('/api/driver/hires/periods')->assertOk()
            ->assertJsonPath('years', [2026, 2025])
            ->assertJsonPath('months_by_year.2026', [10, 9, 7])
            ->assertJsonPath('months_by_year.2025', [12]);
    });

    test('filtered by status they list only the months that have hires of that kind', function () {
        $this->getJson('/api/driver/hires/periods?status=completed')->assertOk()
            ->assertJsonPath('years', [2026])
            ->assertJsonPath('months_by_year.2026', [9, 7]);

        $this->getJson('/api/driver/hires/periods?status=cancelled')->assertOk()
            ->assertJsonPath('years', [2025])
            ->assertJsonPath('months_by_year.2025', [12]);

        $this->getJson('/api/driver/hires/periods?status=open')->assertOk()
            ->assertJsonPath('months_by_year.2026', [10]);
    });

    test('a driver with no hires of that kind gets an empty map, not an empty list', function () {
        $driver = listingDriver(); // a different, brand-new driver

        $body = $this->getJson('/api/driver/hires/periods?status=cancelled')->assertOk()->getContent();

        expect($body)->toContain('"months_by_year":{}');
    });

    test('an unknown status is refused', function () {
        $this->getJson('/api/driver/hires/periods?status=nonsense')->assertStatus(422);
    });
});

test('a driver only ever sees their own hires', function () {
    $mine = listingDriver();
    listedHire($mine, ['status' => 'completed']);

    $other = User::factory()->create();
    $otherDriver = Driver::create(['user_id' => $other->id, 'name' => 'Other', 'license' => 'X', 'contact_number' => '1', 'email' => 'other@example.test', 'password' => 'secret-pass']);
    listedHire($otherDriver, ['status' => 'completed']);
    listedHire($otherDriver, ['status' => 'completed']);

    $this->getJson('/api/driver/hires?status=completed')->assertOk()->assertJsonPath('meta.total', 1);
});
