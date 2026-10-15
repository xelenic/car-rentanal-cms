<?php

use App\Models\Driver;
use App\Models\HireExpense;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function apiHireExpenseAdmin(array $permissions = ['hires.view', 'hires.update', 'hires.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function apiHireExpenseDriver(string $name = 'ZZZ Nimal'): Driver
{
    return Driver::create([
        'name' => $name,
        'license' => 'ZZZ-'.$name,
        'contact_number' => '0770000000',
        'email' => strtolower(str_replace(' ', '.', $name)).'@example.com',
        'password' => bcrypt('testpass123'),
    ]);
}

describe('editing', function () {
    it('needs hires.update', function () {
        $driver = apiHireExpenseDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        apiHireExpenseAdmin(['hires.view']);

        $this->putJson("/api/admin/expenses/{$expense->id}", ['category' => 'repair', 'amount' => 999])
            ->assertForbidden();
        expect($expense->fresh()->category)->toBe('fuel');
    });

    it('updates the category and amount, returning the updated expense', function () {
        $driver = apiHireExpenseDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        apiHireExpenseAdmin();

        $response = $this->putJson("/api/admin/expenses/{$expense->id}", ['category' => 'repair', 'amount' => 1250.50])
            ->assertOk();

        $response->assertJsonPath('data.category', 'repair')
            ->assertJsonPath('data.category_label', 'Vehicle Repair')
            ->assertJsonPath('data.amount', 1250.5);

        $fresh = $expense->fresh();
        expect($fresh->category)->toBe('repair')
            ->and((float) $fresh->amount)->toBe(1250.50);
    });

    it('rejects an unknown category', function () {
        $driver = apiHireExpenseDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        apiHireExpenseAdmin();

        $this->putJson("/api/admin/expenses/{$expense->id}", ['category' => 'not-a-real-category', 'amount' => 500])
            ->assertUnprocessable()->assertJsonValidationErrors('category');
    });

    it('rejects an amount of zero or less', function () {
        $driver = apiHireExpenseDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        apiHireExpenseAdmin();

        $this->putJson("/api/admin/expenses/{$expense->id}", ['category' => 'fuel', 'amount' => 0])
            ->assertUnprocessable()->assertJsonValidationErrors('amount');
    });

    it('is 404 for an expense that does not exist', function () {
        apiHireExpenseAdmin();

        $this->putJson('/api/admin/expenses/999', ['category' => 'fuel', 'amount' => 500])->assertNotFound();
    });
});

describe('deleting', function () {
    it('needs hires.delete', function () {
        $driver = apiHireExpenseDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        apiHireExpenseAdmin(['hires.view']);

        $this->deleteJson("/api/admin/expenses/{$expense->id}")->assertForbidden();
        expect(HireExpense::find($expense->id))->not->toBeNull();
    });

    it('removes the expense', function () {
        $driver = apiHireExpenseDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        apiHireExpenseAdmin();

        $this->deleteJson("/api/admin/expenses/{$expense->id}")->assertOk();

        expect(HireExpense::find($expense->id))->toBeNull();
    });

    it('deletes the receipt file along with it', function () {
        Storage::fake('public');
        $driver = apiHireExpenseDriver();
        $path = UploadedFile::fake()->image('receipt.jpg')->store('hire-expenses/'.$driver->id, 'public');
        $expense = HireExpense::create([
            'driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500, 'receipt_path' => $path,
        ]);
        apiHireExpenseAdmin();

        $this->deleteJson("/api/admin/expenses/{$expense->id}")->assertOk();

        Storage::disk('public')->assertMissing($path);
    });

    it('is 404 for an expense that does not exist', function () {
        apiHireExpenseAdmin();

        $this->deleteJson('/api/admin/expenses/999')->assertNotFound();
    });
});
