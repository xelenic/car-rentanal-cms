<?php

use App\Models\Driver;
use App\Models\DriverPayroll;
use App\Models\Hire;
use App\Models\HireExpense;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

uses(RefreshDatabase::class);

const ALL_DRIVER_PERMISSIONS = ['drivers.view', 'drivers.create', 'drivers.update', 'drivers.delete', 'hires.view'];

function signedInForDrivers(array $permissions = ALL_DRIVER_PERMISSIONS): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }
    Role::findOrCreate('Driver', 'web');

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function testDriver(string $name = 'ZZZ Test Driver', array $attributes = []): Driver
{
    return Driver::create($attributes + [
        'name' => $name,
        'license' => 'ZZZ-LIC-001',
        'contact_number' => '0770000001',
        'email' => strtolower(str_replace(' ', '.', $name)).'@example.test',
        'password' => 'irrelevant-hashed-value',
    ]);
}

describe('access', function () {
    it('needs a signed-in user', function () {
        $this->getJson('/api/admin/drivers')->assertUnauthorized();
        $this->postJson('/api/admin/drivers', [])->assertUnauthorized();
    });

    it('needs drivers.view to list or show', function () {
        $driver = testDriver();
        signedInForDrivers(['hires.view']);

        $this->getJson('/api/admin/drivers')->assertForbidden();
        $this->getJson("/api/admin/drivers/{$driver->id}")->assertForbidden();
    });

    it('needs drivers.create to add one', function () {
        signedInForDrivers(['drivers.view', 'hires.view']);

        $this->postJson('/api/admin/drivers', [
            'name' => 'ZZZ New Driver', 'license' => 'ZZZ-1', 'contact_number' => '0771111111',
            'email' => 'zzz.new@example.test', 'password' => 'password123',
        ])->assertForbidden();
        expect(Driver::count())->toBe(0);
    });

    it('needs drivers.update to edit one', function () {
        $driver = testDriver();
        signedInForDrivers(['drivers.view', 'hires.view']);

        $this->putJson("/api/admin/drivers/{$driver->id}", [
            'name' => 'ZZZ Changed', 'license' => $driver->license, 'contact_number' => $driver->contact_number, 'email' => $driver->email,
        ])->assertForbidden();
        expect($driver->fresh()->name)->toBe('ZZZ Test Driver');
    });

    it('needs drivers.delete to remove one', function () {
        $driver = testDriver();
        signedInForDrivers(['drivers.view', 'hires.view']);

        $this->deleteJson("/api/admin/drivers/{$driver->id}")->assertForbidden();
        expect(Driver::find($driver->id))->not->toBeNull();
    });

    it('tells the app what the user may do', function () {
        signedInForDrivers(['hires.view', 'drivers.view', 'drivers.create']);

        $this->getJson('/api/admin/me')
            ->assertOk()
            ->assertJsonPath('can_view_drivers', true)
            ->assertJsonPath('can_create_drivers', true)
            ->assertJsonPath('can_update_drivers', false)
            ->assertJsonPath('can_delete_drivers', false);
    });
});

describe('the roster', function () {
    it('lists drivers A to Z without their password', function () {
        signedInForDrivers();
        testDriver('ZZZ Test Zebra');
        testDriver('ZZZ Test Apple');

        $response = $this->getJson('/api/admin/drivers')->assertOk();

        expect(collect($response->json('data'))->pluck('name')->all())->toBe(['ZZZ Test Apple', 'ZZZ Test Zebra']);
        $response->assertJsonMissingPath('data.0.password');
    });

    it('searches by name, email or contact number', function () {
        signedInForDrivers();
        testDriver('ZZZ Test Kasun', ['contact_number' => '0771234567']);
        testDriver('ZZZ Test Nimal', ['contact_number' => '0779876543']);

        $byName = $this->getJson('/api/admin/drivers?search=Kasun')->json('data');
        $byPhone = $this->getJson('/api/admin/drivers?search=9876543')->json('data');

        expect(collect($byName)->pluck('name')->all())->toBe(['ZZZ Test Kasun'])
            ->and(collect($byPhone)->pluck('name')->all())->toBe(['ZZZ Test Nimal']);
    });

    it('pages the list', function () {
        signedInForDrivers();
        foreach (range(1, 23) as $number) {
            testDriver(sprintf('ZZZ Test Driver %02d', $number), ['email' => "zzz.driver{$number}@example.test"]);
        }

        $first = $this->getJson('/api/admin/drivers')->assertOk();
        $second = $this->getJson('/api/admin/drivers?page=2')->assertOk();

        expect($first->json('data'))->toHaveCount(20)
            ->and($first->json('meta.last_page'))->toBe(2)
            ->and($second->json('data'))->toHaveCount(3);
    });
});

describe('adding a driver', function () {
    it('creates the driver and a linked user with the Driver role', function () {
        signedInForDrivers();

        $response = $this->postJson('/api/admin/drivers', [
            'name' => 'ZZZ New Driver', 'license' => 'ZZZ-LIC-9', 'contact_number' => '0771111111',
            'additional_phone_number' => '0772222222', 'email' => 'zzz.newdriver@example.test', 'password' => 'password123',
        ])->assertCreated();

        $response->assertJsonPath('data.name', 'ZZZ New Driver')
            ->assertJsonPath('data.license', 'ZZZ-LIC-9')
            ->assertJsonPath('data.additional_phone_number', '0772222222')
            ->assertJsonMissingPath('data.password');

        $driver = Driver::where('email', 'zzz.newdriver@example.test')->first();
        expect($driver)->not->toBeNull()
            ->and($driver->user)->not->toBeNull()
            ->and($driver->user->hasRole('Driver'))->toBeTrue()
            ->and(\Illuminate\Support\Facades\Hash::check('password123', $driver->user->password))->toBeTrue();
    });

    it('rejects a duplicate email', function () {
        signedInForDrivers();
        testDriver('ZZZ Existing', ['email' => 'zzz.taken@example.test']);

        $this->postJson('/api/admin/drivers', [
            'name' => 'ZZZ New', 'license' => 'ZZZ-1', 'contact_number' => '0771111111',
            'email' => 'zzz.taken@example.test', 'password' => 'password123',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    });

    it('rejects bad input with the reason', function (array $payload, string $field) {
        signedInForDrivers();

        $this->postJson('/api/admin/drivers', $payload + [
            'name' => 'ZZZ New', 'license' => 'ZZZ-1', 'contact_number' => '0771111111',
            'email' => 'zzz.valid@example.test', 'password' => 'password123',
        ])->assertUnprocessable()->assertJsonValidationErrors($field);
        expect(Driver::count())->toBe(0);
    })->with([
        'no name' => [['name' => ''], 'name'],
        'no license' => [['license' => ''], 'license'],
        'no contact number' => [['contact_number' => ''], 'contact_number'],
        'bad email' => [['email' => 'not-an-email'], 'email'],
        'short password' => [['password' => 'short'], 'password'],
    ]);
});

describe('editing a driver', function () {
    it('saves changes without requiring a new password', function () {
        signedInForDrivers();
        $driver = testDriver('ZZZ Old Name');
        $originalHash = $driver->password;

        $this->putJson("/api/admin/drivers/{$driver->id}", [
            'name' => 'ZZZ New Name', 'license' => $driver->license, 'contact_number' => '0779999999', 'email' => $driver->email,
        ])->assertOk()->assertJsonPath('data.name', 'ZZZ New Name');

        $fresh = $driver->fresh();
        expect($fresh->name)->toBe('ZZZ New Name')
            ->and($fresh->contact_number)->toBe('0779999999')
            ->and($fresh->password)->toBe($originalHash)
            ->and($fresh->user->name)->toBe('ZZZ New Name');
    });

    it('updates the password when one is given', function () {
        signedInForDrivers();
        $driver = testDriver();

        $this->putJson("/api/admin/drivers/{$driver->id}", [
            'name' => $driver->name, 'license' => $driver->license, 'contact_number' => $driver->contact_number,
            'email' => $driver->email, 'password' => 'newpassword123',
        ])->assertOk();

        expect(\Illuminate\Support\Facades\Hash::check('newpassword123', $driver->fresh()->user->password))->toBeTrue();
    });

    it('is 404 for a driver that does not exist', function () {
        signedInForDrivers();

        $this->putJson('/api/admin/drivers/999', [
            'name' => 'ZZZ', 'license' => 'ZZZ', 'contact_number' => '0770000000', 'email' => 'zzz@example.test',
        ])->assertNotFound();
    });
});

describe('the summary (Overview tab)', function () {
    it('needs drivers.view', function () {
        $driver = testDriver();
        signedInForDrivers(['hires.view']);

        $this->getJson("/api/admin/drivers/{$driver->id}/summary")->assertForbidden();
    });

    it('totals this driver\'s hires for the given month, not another driver\'s', function () {
        signedInForDrivers();
        $driver = testDriver('ZZZ Nimal');
        $someoneElse = testDriver('ZZZ Kamal', ['email' => 'zzz.kamal@example.test']);

        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 3500,
            'payment_type' => 'cash', 'start_time' => '2026-09-10 10:00:00', 'driver_id' => $driver->id,
        ]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 3000, 'our_hire_value' => 2000,
            'payment_type' => 'cash', 'start_time' => '2026-09-15 10:00:00', 'driver_id' => $driver->id,
        ]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 9999, 'our_hire_value' => 9999,
            'payment_type' => 'cash', 'start_time' => '2026-09-10 10:00:00', 'driver_id' => $someoneElse->id,
        ]);
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 7777, 'our_hire_value' => 7777,
            'payment_type' => 'cash', 'start_time' => '2026-08-10 10:00:00', 'driver_id' => $driver->id,
        ]);

        $response = $this->getJson("/api/admin/drivers/{$driver->id}/summary?year=2026&month=9")->assertOk();

        $response->assertJsonPath('year', 2026)
            ->assertJsonPath('month', 9)
            ->assertJsonPath('period_label', 'September 2026')
            ->assertJsonPath('summary.hire_count', 2)
            ->assertJsonPath('summary.hire_full_value_total', 8000)
            ->assertJsonPath('summary.our_hire_value_total', 5500)
            ->assertJsonPath('summary.commission_total', 2500);
    });

    it('defaults to the current month when none is given', function () {
        signedInForDrivers();
        $driver = testDriver();

        $response = $this->getJson("/api/admin/drivers/{$driver->id}/summary")->assertOk();

        $response->assertJsonPath('year', (int) now()->format('Y'))
            ->assertJsonPath('month', (int) now()->format('n'));
    });

    it('uses a finalized payroll\'s amount over the calculated one, when there is one', function () {
        signedInForDrivers();
        $driver = testDriver();
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 3500,
            'payment_type' => 'cash', 'start_time' => '2026-09-10 10:00:00', 'driver_id' => $driver->id,
        ]);
        DriverPayroll::create([
            'driver_id' => $driver->id, 'year' => 2026, 'month' => 9, 'hire_count' => 1,
            'our_hire_value_total' => 3500, 'expenses_total' => 0, 'salary' => 700,
            'advance_deduction_total' => 0, 'carryover_deduction_total' => 0, 'arrears_deduction_total' => 0,
            'deposit_balance' => 0, 'arrears_loan_offset' => 0, 'net_before_adjustment' => 700,
            'manual_adjustment' => 50, 'final_amount' => 750, 'status' => 'paid',
        ]);

        $response = $this->getJson("/api/admin/drivers/{$driver->id}/summary?year=2026&month=9")->assertOk();

        $response->assertJsonPath('summary.salary_payable', 750)
            ->assertJsonPath('payroll_status', 'paid');
    });

    it('is 404 for a driver that does not exist', function () {
        signedInForDrivers();

        $this->getJson('/api/admin/drivers/999/summary')->assertNotFound();
    });
});

describe('the expenses (Expenses tab)', function () {
    it('needs drivers.view', function () {
        $driver = testDriver();
        signedInForDrivers(['hires.view']);

        $this->getJson("/api/admin/drivers/{$driver->id}/expenses")->assertForbidden();
    });

    it('lists only this driver\'s expenses for the given month, not another driver\'s or another month\'s', function () {
        signedInForDrivers();
        $driver = testDriver('ZZZ Nimal');
        $someoneElse = testDriver('ZZZ Kamal', ['email' => 'zzz.kamal@example.test']);

        $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 1500]);
        HireExpense::create(['driver_id' => $driver->id, 'category' => 'parking', 'amount' => 250]);
        HireExpense::create(['driver_id' => $someoneElse->id, 'category' => 'fuel', 'amount' => 9999]);

        $this->travelTo(Carbon::parse('2026-08-16 12:00:00'));
        HireExpense::create(['driver_id' => $driver->id, 'category' => 'repair', 'amount' => 7777]);

        $response = $this->getJson("/api/admin/drivers/{$driver->id}/expenses?year=2026&month=9")->assertOk();

        expect(collect($response->json('data'))->pluck('category')->sort()->values()->all())
            ->toBe(['fuel', 'parking'])
            ->and($response->json('summary.count'))->toBe(2)
            ->and($response->json('summary.total'))->toBe(1750);
    });

    it('includes the category label, amount, receipt and which hire it was logged against', function () {
        signedInForDrivers();
        $driver = testDriver();
        $hire = Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 3500,
            'payment_type' => 'cash', 'start_time' => '2026-09-10 10:00:00', 'driver_id' => $driver->id,
        ]);
        $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        HireExpense::create(['driver_id' => $driver->id, 'hire_id' => $hire->id, 'category' => 'fuel', 'amount' => 1200]);

        $response = $this->getJson("/api/admin/drivers/{$driver->id}/expenses?year=2026&month=9")->assertOk();

        $response->assertJsonPath('data.0.category', 'fuel')
            ->assertJsonPath('data.0.category_label', 'Fuel')
            ->assertJsonPath('data.0.amount', 1200)
            ->assertJsonPath('data.0.hire_id', $hire->id)
            ->assertJsonPath('data.0.hire_tour_type_label', Hire::TOUR_TYPES['drop_pickup'])
            ->assertJsonPath('data.0.receipt_url', null);
    });

    it('defaults to the current month when none is given', function () {
        signedInForDrivers();
        $driver = testDriver();

        $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);

        $this->getJson("/api/admin/drivers/{$driver->id}/expenses")
            ->assertOk()
            ->assertJsonPath('summary.count', 1);
    });

    it('pages the list', function () {
        signedInForDrivers();
        $driver = testDriver();

        $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        foreach (range(1, 23) as $number) {
            HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => $number]);
        }

        $first = $this->getJson("/api/admin/drivers/{$driver->id}/expenses?year=2026&month=9")->assertOk();
        $second = $this->getJson("/api/admin/drivers/{$driver->id}/expenses?year=2026&month=9&page=2")->assertOk();

        expect($first->json('data'))->toHaveCount(20)
            ->and($first->json('meta.last_page'))->toBe(2)
            ->and($first->json('summary.count'))->toBe(23)
            ->and($second->json('data'))->toHaveCount(3);
    });

    it('is 404 for a driver that does not exist', function () {
        signedInForDrivers();

        $this->getJson('/api/admin/drivers/999/expenses')->assertNotFound();
    });
});

describe('deleting a driver', function () {
    it('removes the driver and their linked user', function () {
        signedInForDrivers();
        $driver = testDriver();
        $userId = $driver->user_id;

        $this->deleteJson("/api/admin/drivers/{$driver->id}")->assertOk();

        expect(Driver::find($driver->id))->toBeNull()
            ->and(User::find($userId))->toBeNull();
    });

    it('is 404 for a driver that does not exist', function () {
        signedInForDrivers();

        $this->deleteJson('/api/admin/drivers/999')->assertNotFound();
    });
});
