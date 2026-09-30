<?php

use App\Models\Customer;
use App\Models\Hire;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

const ALL_CUSTOMER_PERMISSIONS = ['customers.view', 'customers.create', 'customers.update', 'customers.delete', 'hires.view'];

function signedInForCustomers(array $permissions = ALL_CUSTOMER_PERMISSIONS): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function testCustomer(string $name = 'ZZZ Test Customer', array $attributes = []): Customer
{
    return Customer::create($attributes + ['name' => $name, 'phone' => '0770000001']);
}

describe('access', function () {
    it('needs a signed-in user', function () {
        $this->getJson('/api/admin/customers')->assertUnauthorized();
        $this->postJson('/api/admin/customers', [])->assertUnauthorized();
    });

    it('needs customers.view to list or show', function () {
        $customer = testCustomer();
        signedInForCustomers(['hires.view']);

        $this->getJson('/api/admin/customers')->assertForbidden();
        $this->getJson("/api/admin/customers/{$customer->id}")->assertForbidden();
    });

    it('needs customers.create to add one', function () {
        signedInForCustomers(['customers.view', 'hires.view']);

        $this->postJson('/api/admin/customers', ['name' => 'ZZZ New', 'phone' => '0771111111'])->assertForbidden();
        expect(Customer::count())->toBe(0);
    });

    it('needs customers.update to edit one', function () {
        $customer = testCustomer();
        signedInForCustomers(['customers.view', 'hires.view']);

        $this->putJson("/api/admin/customers/{$customer->id}", ['name' => 'ZZZ Changed', 'phone' => $customer->phone])
            ->assertForbidden();
        expect($customer->fresh()->name)->toBe('ZZZ Test Customer');
    });

    it('needs customers.delete to remove one', function () {
        $customer = testCustomer();
        signedInForCustomers(['customers.view', 'hires.view']);

        $this->deleteJson("/api/admin/customers/{$customer->id}")->assertForbidden();
        expect(Customer::find($customer->id))->not->toBeNull();
    });

    it('tells the app what the user may do', function () {
        signedInForCustomers(['hires.view', 'customers.view', 'customers.create']);

        $this->getJson('/api/admin/me')
            ->assertOk()
            ->assertJsonPath('can_view_customers', true)
            ->assertJsonPath('can_create_customers', true)
            ->assertJsonPath('can_update_customers', false)
            ->assertJsonPath('can_delete_customers', false);
    });
});

describe('the customer list', function () {
    it('lists customers A to Z with their details', function () {
        signedInForCustomers();
        testCustomer('ZZZ Test Zebra', ['email' => 'zzz.zebra@example.test', 'nic_passport' => '123456789V']);
        testCustomer('ZZZ Test Apple');

        $response = $this->getJson('/api/admin/customers')->assertOk();

        expect(collect($response->json('data'))->pluck('name')->all())->toBe(['ZZZ Test Apple', 'ZZZ Test Zebra']);
        $response->assertJsonPath('data.1.email', 'zzz.zebra@example.test')
            ->assertJsonPath('data.1.nic_passport', '123456789V');
    });

    it('searches by name, phone or email', function () {
        signedInForCustomers();
        testCustomer('ZZZ Test Kasun', ['phone' => '0771234567']);
        testCustomer('ZZZ Test Nimal', ['phone' => '0779876543', 'email' => 'zzz.nimal@example.test']);

        $byName = $this->getJson('/api/admin/customers?search=Kasun')->json('data');
        $byEmail = $this->getJson('/api/admin/customers?search=nimal@example')->json('data');

        expect(collect($byName)->pluck('name')->all())->toBe(['ZZZ Test Kasun'])
            ->and(collect($byEmail)->pluck('name')->all())->toBe(['ZZZ Test Nimal']);
    });

    it('pages the list', function () {
        signedInForCustomers();
        foreach (range(1, 23) as $number) {
            testCustomer(sprintf('ZZZ Test Customer %02d', $number));
        }

        $first = $this->getJson('/api/admin/customers')->assertOk();
        $second = $this->getJson('/api/admin/customers?page=2')->assertOk();

        expect($first->json('data'))->toHaveCount(20)
            ->and($first->json('meta.last_page'))->toBe(2)
            ->and($second->json('data'))->toHaveCount(3);
    });
});

describe('adding a customer', function () {
    it('creates one and answers with its card', function () {
        signedInForCustomers();

        $response = $this->postJson('/api/admin/customers', [
            'name' => 'ZZZ New Customer', 'phone' => '0771111111', 'email' => 'zzz.new@example.test',
            'nic_passport' => '987654321V', 'address' => 'ZZZ 12 Main St', 'notes' => 'ZZZ prefers cash',
        ])->assertCreated();

        $response->assertJsonPath('data.name', 'ZZZ New Customer')
            ->assertJsonPath('data.phone', '0771111111')
            ->assertJsonPath('data.address', 'ZZZ 12 Main St');
        expect(Customer::where('name', 'ZZZ New Customer')->exists())->toBeTrue();
    });

    it('accepts a customer with just a name and phone', function () {
        signedInForCustomers();

        $this->postJson('/api/admin/customers', ['name' => 'ZZZ Bare', 'phone' => '0771111111'])
            ->assertCreated()
            ->assertJsonPath('data.email', null)
            ->assertJsonPath('data.notes', null);
    });

    it('rejects bad input with the reason', function (array $payload, string $field) {
        signedInForCustomers();

        $this->postJson('/api/admin/customers', $payload + ['name' => 'ZZZ New', 'phone' => '0771111111'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors($field);
        expect(Customer::count())->toBe(0);
    })->with([
        'no name' => [['name' => ''], 'name'],
        'no phone' => [['phone' => ''], 'phone'],
        'bad email' => [['email' => 'not-an-email'], 'email'],
    ]);
});

describe('editing a customer', function () {
    it('saves changes and answers with the updated card', function () {
        signedInForCustomers();
        $customer = testCustomer('ZZZ Old Name');

        $this->putJson("/api/admin/customers/{$customer->id}", [
            'name' => 'ZZZ New Name', 'phone' => '0779999999', 'notes' => 'ZZZ updated notes',
        ])->assertOk()->assertJsonPath('data.name', 'ZZZ New Name');

        $fresh = $customer->fresh();
        expect($fresh->name)->toBe('ZZZ New Name')
            ->and($fresh->phone)->toBe('0779999999')
            ->and($fresh->notes)->toBe('ZZZ updated notes');
    });

    it('is 404 for a customer that does not exist', function () {
        signedInForCustomers();

        $this->putJson('/api/admin/customers/999', ['name' => 'ZZZ', 'phone' => '0770000000'])->assertNotFound();
    });
});

describe('deleting a customer', function () {
    it('removes a customer with no hires', function () {
        signedInForCustomers();
        $customer = testCustomer();

        $this->deleteJson("/api/admin/customers/{$customer->id}")->assertOk();

        expect(Customer::find($customer->id))->toBeNull();
    });

    it('refuses to delete a customer with existing hires', function () {
        signedInForCustomers();
        $customer = testCustomer();
        Hire::create([
            'tour_type' => 'drop_pickup', 'hire_full_value' => 1000, 'our_hire_value' => 800,
            'payment_type' => 'cash', 'customer_id' => $customer->id,
        ]);

        $this->deleteJson("/api/admin/customers/{$customer->id}")
            ->assertStatus(422)
            ->assertJsonPath('message', "Customer \"{$customer->name}\" has existing hires and cannot be deleted.");
        expect(Customer::find($customer->id))->not->toBeNull();
    });

    it('is 404 for a customer that does not exist', function () {
        signedInForCustomers();

        $this->deleteJson('/api/admin/customers/999')->assertNotFound();
    });
});
