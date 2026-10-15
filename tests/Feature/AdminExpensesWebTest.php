<?php

use App\Models\Driver;
use App\Models\HireExpense;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function expensesWebAdmin(array $permissions = ['hires.view', 'hires.update', 'hires.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function expensesWebDriver(string $name = 'ZZZ Nimal'): Driver
{
    return Driver::create([
        'name' => $name,
        'license' => 'ZZZ-'.$name,
        'contact_number' => '0770000000',
        'email' => strtolower(str_replace(' ', '.', $name)).'@example.com',
        'password' => bcrypt('testpass123'),
    ]);
}

describe('viewing', function () {
    it('needs hires.view', function () {
        expensesWebAdmin([]);

        $this->get('/admin/expenses')->assertForbidden();
    });
});

describe('editing', function () {
    it('needs hires.update', function () {
        $driver = expensesWebDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        expensesWebAdmin(['hires.view']);

        $this->put("/admin/expenses/{$expense->id}", ['category' => 'repair', 'amount' => 999])->assertForbidden();
        expect($expense->fresh()->category)->toBe('fuel');
    });

    it('updates the category and amount', function () {
        $driver = expensesWebDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        expensesWebAdmin();

        $this->put("/admin/expenses/{$expense->id}", ['category' => 'repair', 'amount' => 1250.50])
            ->assertRedirect();

        $fresh = $expense->fresh();
        expect($fresh->category)->toBe('repair')
            ->and((float) $fresh->amount)->toBe(1250.50);
    });

    it('rejects an unknown category', function () {
        $driver = expensesWebDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        expensesWebAdmin();

        $this->put("/admin/expenses/{$expense->id}", ['category' => 'not-a-real-category', 'amount' => 500])
            ->assertSessionHasErrors('category');
    });

    it('rejects an amount of zero or less', function () {
        $driver = expensesWebDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        expensesWebAdmin();

        $this->put("/admin/expenses/{$expense->id}", ['category' => 'fuel', 'amount' => 0])
            ->assertSessionHasErrors('amount');
    });

    it('is 404 for an expense that does not exist', function () {
        expensesWebAdmin();

        $this->put('/admin/expenses/999', ['category' => 'fuel', 'amount' => 500])->assertNotFound();
    });
});

describe('deleting', function () {
    it('needs hires.delete', function () {
        $driver = expensesWebDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        expensesWebAdmin(['hires.view']);

        $this->delete("/admin/expenses/{$expense->id}")->assertForbidden();
        expect(HireExpense::find($expense->id))->not->toBeNull();
    });

    it('removes the expense', function () {
        $driver = expensesWebDriver();
        $expense = HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500]);
        expensesWebAdmin();

        $this->delete("/admin/expenses/{$expense->id}")->assertRedirect();

        expect(HireExpense::find($expense->id))->toBeNull();
    });

    it('deletes the receipt file along with it', function () {
        Storage::fake('public');
        $driver = expensesWebDriver();
        $path = UploadedFile::fake()->image('receipt.jpg')->store('hire-expenses/'.$driver->id, 'public');
        $expense = HireExpense::create([
            'driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 500, 'receipt_path' => $path,
        ]);
        expensesWebAdmin();

        $this->delete("/admin/expenses/{$expense->id}")->assertRedirect();

        Storage::disk('public')->assertMissing($path);
    });

    it('is 404 for an expense that does not exist', function () {
        expensesWebAdmin();

        $this->delete('/admin/expenses/999')->assertNotFound();
    });
});
