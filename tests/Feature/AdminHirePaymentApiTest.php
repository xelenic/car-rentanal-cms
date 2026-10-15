<?php

use App\Models\Hire;
use App\Models\HirePayment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function apiHirePaymentAdmin(array $permissions = ['hires.view', 'hires.update']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function apiHirePaymentHire(array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 10000, 'our_hire_value' => 7000,
        'payment_type' => 'credit', 'start_time' => '2026-09-10 10:00:00',
    ]);
}

describe('claiming a payment', function () {
    it('needs hires.update', function () {
        $hire = apiHirePaymentHire();
        apiHirePaymentAdmin(['hires.view']);

        $this->postJson("/api/admin/hires/{$hire->id}/payments", ['amount' => 5000])->assertForbidden();
        expect(HirePayment::count())->toBe(0);
    });

    it('records a partial payment, with notes, and returns the updated hire', function () {
        $hire = apiHirePaymentHire();
        apiHirePaymentAdmin();

        $response = $this->postJson("/api/admin/hires/{$hire->id}/payments", [
            'amount' => 4000, 'notes' => 'Bank transfer',
        ])->assertOk();

        $response->assertJsonPath('data.paid_amount', 4000)
            ->assertJsonPath('data.balance_remaining', 6000)
            ->assertJsonPath('data.payment_status', 'partial')
            ->assertJsonPath('data.payments.0.amount', 4000)
            ->assertJsonPath('data.payments.0.notes', 'Bank transfer');

        $payment = HirePayment::where('hire_id', $hire->id)->first();
        expect($payment)->not->toBeNull()
            ->and((float) $payment->amount)->toBe(4000.0)
            ->and($payment->paid_at->toDateString())->toBe(now()->toDateString());
    });

    it('records a full payment (the whole balance), marking the hire fully paid', function () {
        $hire = apiHirePaymentHire();
        apiHirePaymentAdmin();

        $response = $this->postJson("/api/admin/hires/{$hire->id}/payments", ['amount' => 10000])->assertOk();

        $response->assertJsonPath('data.paid_amount', 10000)
            ->assertJsonPath('data.balance_remaining', 0)
            ->assertJsonPath('data.payment_status', 'paid');
    });

    it('rejects an amount greater than the remaining balance', function () {
        $hire = apiHirePaymentHire();
        apiHirePaymentAdmin();

        $this->postJson("/api/admin/hires/{$hire->id}/payments", ['amount' => 10001])
            ->assertUnprocessable()->assertJsonValidationErrors('amount');
        expect(HirePayment::count())->toBe(0);
    });

    it('rejects an amount of zero or less', function () {
        $hire = apiHirePaymentHire();
        apiHirePaymentAdmin();

        $this->postJson("/api/admin/hires/{$hire->id}/payments", ['amount' => 0])
            ->assertUnprocessable()->assertJsonValidationErrors('amount');
    });

    it('is 404 for a hire that does not exist', function () {
        apiHirePaymentAdmin();

        $this->postJson('/api/admin/hires/999/payments', ['amount' => 100])->assertNotFound();
    });
});

describe('deleting a payment', function () {
    it('needs hires.update', function () {
        $hire = apiHirePaymentHire();
        $payment = $hire->payments()->create(['amount' => 4000, 'paid_at' => now()->toDateString()]);
        apiHirePaymentAdmin(['hires.view']);

        $this->deleteJson("/api/admin/hires/{$hire->id}/payments/{$payment->id}")->assertForbidden();
        expect(HirePayment::find($payment->id))->not->toBeNull();
    });

    it('removes the payment and restores the balance', function () {
        $hire = apiHirePaymentHire();
        $payment = $hire->payments()->create(['amount' => 4000, 'paid_at' => now()->toDateString()]);
        apiHirePaymentAdmin();

        $response = $this->deleteJson("/api/admin/hires/{$hire->id}/payments/{$payment->id}")->assertOk();

        $response->assertJsonPath('data.paid_amount', 0)
            ->assertJsonPath('data.balance_remaining', 10000)
            ->assertJsonPath('data.payment_status', 'unpaid');
        expect(HirePayment::find($payment->id))->toBeNull();
    });

    it('is 404 when the payment belongs to a different hire', function () {
        $hire = apiHirePaymentHire();
        $otherHire = apiHirePaymentHire();
        $payment = $otherHire->payments()->create(['amount' => 1000, 'paid_at' => now()->toDateString()]);
        apiHirePaymentAdmin();

        $this->deleteJson("/api/admin/hires/{$hire->id}/payments/{$payment->id}")->assertNotFound();
        expect(HirePayment::find($payment->id))->not->toBeNull();
    });

    it('is 404 for a hire or payment that does not exist', function () {
        apiHirePaymentAdmin();

        $this->deleteJson('/api/admin/hires/999/payments/999')->assertNotFound();
    });
});
