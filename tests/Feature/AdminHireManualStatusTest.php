<?php

use App\Models\Customer;
use App\Models\Hire;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function statusEditor(array $permissions = ['hires.view', 'hires.create', 'hires.update']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function statusCustomer(string $name = 'ZZZ Status Customer'): Customer
{
    return Customer::create(['name' => $name, 'phone' => '0770000000']);
}

function statusVehicle(string $model = 'ZZZ Status Van'): Vehicle
{
    return Vehicle::create(['model' => $model, 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

function statusHire(array $overrides = []): Hire
{
    return Hire::create($overrides + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 1000, 'our_hire_value' => 800,
        'payment_type' => 'cash', 'customer_id' => statusCustomer()->id, 'vehicle_id' => statusVehicle()->id,
    ]);
}

/** Everything the app's create/edit form sends when a tour type needs a route. */
function statusHireBody(array $changes = []): array
{
    return $changes + [
        'tour_type' => 'drop_pickup', 'customer_id' => statusCustomer('ZZZ Body Customer')->id,
        'hire_full_value' => 1000, 'our_hire_value' => 800, 'payment_type' => 'cash',
        'from_location_name' => 'ZZZ From', 'to_location_name' => 'ZZZ To',
    ];
}

it('creates a hire already marked completed, for one that already happened and was never entered', function () {
    statusEditor();

    $response = $this->postJson('/api/admin/hires', statusHireBody(['status' => 'completed']));

    $response->assertCreated()
        ->assertJsonPath('data.status', 'completed')
        ->assertJsonPath('data.status_label', 'Completed');
    expect(Hire::first()->status)->toBe('completed');
});

it('creates a hire already marked cancelled, with a reason, timestamped now', function () {
    statusEditor();

    $response = $this->postJson('/api/admin/hires', statusHireBody([
        'status' => 'cancelled', 'cancel_reason' => 'ZZZ never actually happened',
    ]));

    $response->assertCreated()
        ->assertJsonPath('data.status', 'cancelled')
        ->assertJsonPath('data.cancel_reason', 'ZZZ never actually happened');
    $hire = Hire::first();
    expect($hire->cancelled_at)->not->toBeNull()
        ->and($hire->cancelled_at->diffInSeconds(now()))->toBeLessThan(5);
});

it('defaults a new hire to pending when no status is given', function () {
    statusEditor();

    $response = $this->postJson('/api/admin/hires', statusHireBody());

    $response->assertCreated()->assertJsonPath('data.status', 'pending');
});

it('rejects a status that is not one of the known values', function () {
    statusEditor();

    $this->postJson('/api/admin/hires', statusHireBody(['status' => 'in_progress_sort_of']))
        ->assertUnprocessable()->assertJsonValidationErrors('status');
});

it('changes an existing hire\'s status by hand, e.g. marking it completed', function () {
    $hire = statusHire(['status' => 'pending']);
    statusEditor();

    $response = $this->putJson("/api/admin/hires/{$hire->id}", statusHireBody([
        'customer_id' => $hire->customer_id, 'vehicle_id' => $hire->vehicle_id, 'status' => 'completed',
    ]));

    $response->assertOk()->assertJsonPath('data.status', 'completed');
    expect($hire->fresh()->status)->toBe('completed');
});

it('cancelling a hire by hand records the reason and a fresh cancelled_at', function () {
    $hire = statusHire(['status' => 'pending']);
    statusEditor();

    $this->putJson("/api/admin/hires/{$hire->id}", statusHireBody([
        'customer_id' => $hire->customer_id, 'vehicle_id' => $hire->vehicle_id,
        'status' => 'cancelled', 'cancel_reason' => 'ZZZ customer backed out',
    ]))->assertOk();

    $fresh = $hire->fresh();
    expect($fresh->status)->toBe('cancelled')
        ->and($fresh->cancel_reason)->toBe('ZZZ customer backed out')
        ->and($fresh->cancelled_at)->not->toBeNull();
});

it('keeps the original cancelled_at when an already-cancelled hire is edited but stays cancelled', function () {
    $originalCancelledAt = now()->subDays(10);
    $hire = statusHire(['status' => 'cancelled', 'cancelled_at' => $originalCancelledAt, 'cancel_reason' => 'ZZZ original reason']);
    statusEditor();

    $this->putJson("/api/admin/hires/{$hire->id}", statusHireBody([
        'customer_id' => $hire->customer_id, 'vehicle_id' => $hire->vehicle_id,
        'status' => 'cancelled', 'cancel_reason' => 'ZZZ original reason', 'description' => 'ZZZ unrelated edit',
    ]))->assertOk();

    expect($hire->fresh()->cancelled_at->toDateTimeString())->toBe($originalCancelledAt->toDateTimeString());
});

it('clears cancellation fields when a cancelled hire is manually moved to another status', function () {
    $hire = statusHire(['status' => 'cancelled', 'cancelled_at' => now(), 'cancel_reason' => 'ZZZ reason']);
    statusEditor();

    $this->putJson("/api/admin/hires/{$hire->id}", statusHireBody([
        'customer_id' => $hire->customer_id, 'vehicle_id' => $hire->vehicle_id, 'status' => 'pending',
    ]))->assertOk();

    $fresh = $hire->fresh();
    expect($fresh->status)->toBe('pending')
        ->and($fresh->cancelled_at)->toBeNull()
        ->and($fresh->cancel_reason)->toBeNull();
});

it('leaves status untouched when the edit payload omits it entirely', function () {
    $hire = statusHire(['status' => 'started']);
    statusEditor();

    $this->putJson("/api/admin/hires/{$hire->id}", statusHireBody([
        'customer_id' => $hire->customer_id, 'vehicle_id' => $hire->vehicle_id, 'description' => 'ZZZ no status key here',
    ]))->assertOk();

    expect($hire->fresh()->status)->toBe('started');
});

it('needs hires.update to change status, same as any other edit', function () {
    $hire = statusHire(['status' => 'pending']);
    statusEditor(['hires.view']);

    $this->putJson("/api/admin/hires/{$hire->id}", statusHireBody([
        'customer_id' => $hire->customer_id, 'vehicle_id' => $hire->vehicle_id, 'status' => 'completed',
    ]))->assertForbidden();
    expect($hire->fresh()->status)->toBe('pending');
});
