<?php

use App\Models\Driver;
use App\Models\User;
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
