<?php

use App\Models\Hire;
use App\Models\MyExpense;
use App\Models\MyExpenseCategory;
use App\Models\OtherIncome;
use App\Models\User;
use App\Services\MyExpenseReport;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function apiOwner(array $permissions = ['my-expenses.view', 'my-expenses.create', 'my-expenses.update', 'my-expenses.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function apiExpense(array $attributes = []): MyExpense
{
    return MyExpense::create($attributes + [
        'title' => 'ZZZ Rent', 'category' => 'rent', 'amount' => 1000, 'expense_date' => '2026-09-10',
    ]);
}

function apiProfitableHire(float $our = 8000, string $start = '2026-09-05 09:00:00'): Hire
{
    return Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => $our + 2000, 'our_hire_value' => $our,
        'payment_type' => 'cash', 'start_time' => $start,
    ]);
}

function apiExpenseBody(array $changes = []): array
{
    return $changes + ['title' => 'ZZZ Office rent', 'category' => 'rent', 'amount' => '1500.50', 'expense_date' => '2026-09-12', 'notes' => 'ZZZ note'];
}

describe('access', function () {
    it('needs a signed-in user', function () {
        $this->getJson('/api/admin/my-expenses')->assertUnauthorized();
        $this->postJson('/api/admin/my-expenses', [])->assertUnauthorized();
        $this->getJson('/api/admin/my-expense-categories')->assertUnauthorized();
    });

    it('needs my-expenses.view to see the expenses or the categories', function () {
        apiOwner(['hires.view']);

        $this->getJson('/api/admin/my-expenses')->assertForbidden();
        $this->getJson('/api/admin/my-expense-categories')->assertForbidden();
    });

    it('lets view alone read but not write', function () {
        $expense = apiExpense();
        apiOwner(['my-expenses.view']);

        $this->getJson('/api/admin/my-expenses')->assertOk();
        $this->getJson('/api/admin/my-expense-categories')->assertOk();
        $this->postJson('/api/admin/my-expenses', apiExpenseBody())->assertForbidden();
        $this->putJson("/api/admin/my-expenses/{$expense->id}", apiExpenseBody())->assertForbidden();
        $this->deleteJson("/api/admin/my-expenses/{$expense->id}")->assertForbidden();
        $this->postJson('/api/admin/my-expense-categories', ['name' => 'X'])->assertForbidden();

        expect(MyExpense::count())->toBe(1)->and($expense->fresh()->title)->toBe('ZZZ Rent');
    });

    it('tells the app what the user may do with expenses', function () {
        apiOwner(['hires.view', 'my-expenses.view', 'my-expenses.update']);

        $this->getJson('/api/admin/me')->assertOk()
            ->assertJsonPath('can_view_my_expenses', true)
            ->assertJsonPath('can_create_my_expenses', false)
            ->assertJsonPath('can_update_my_expenses', true)
            ->assertJsonPath('can_delete_my_expenses', false);
    });
});

describe('a month of expenses', function () {
    it('opens on the current month, newest first, leaving other months out', function () {
        apiOwner();
        apiExpense(['title' => 'ZZZ early', 'expense_date' => '2026-09-01']);
        apiExpense(['title' => 'ZZZ late', 'expense_date' => '2026-09-30']);
        apiExpense(['title' => 'ZZZ august', 'expense_date' => '2026-08-31']);

        $response = $this->getJson('/api/admin/my-expenses')->assertOk();

        expect(collect($response->json('data'))->pluck('title')->all())->toBe(['ZZZ late', 'ZZZ early']);
        $response->assertJsonPath('summary.year', 2026)->assertJsonPath('summary.month', 9)->assertJsonPath('summary.label', 'September 2026');
    });

    it('describes each expense', function () {
        apiOwner();
        apiExpense(['title' => 'ZZZ Office rent', 'category' => 'utilities', 'amount' => 1500.5, 'expense_date' => '2026-09-12', 'notes' => 'ZZZ note']);

        $this->getJson('/api/admin/my-expenses')->assertOk()->assertJsonPath('data.0', [
            'id' => MyExpense::first()->id, 'title' => 'ZZZ Office rent', 'category' => 'utilities',
            'category_name' => 'Utilities', 'amount' => 1500.5, 'expense_date' => '2026-09-12', 'notes' => 'ZZZ note',
        ]);
    });

    it('shows another month when asked', function () {
        apiOwner();
        apiExpense(['title' => 'ZZZ august', 'expense_date' => '2026-08-15']);

        $response = $this->getJson('/api/admin/my-expenses?year=2026&month=8')->assertOk();

        expect(collect($response->json('data'))->pluck('title')->all())->toBe(['ZZZ august']);
        $response->assertJsonPath('summary.label', 'August 2026');
    });

    it('totals the month and counts it', function () {
        apiOwner();
        apiExpense(['amount' => 1200.50, 'expense_date' => '2026-09-02']);
        apiExpense(['amount' => 300, 'expense_date' => '2026-09-20']);
        apiExpense(['amount' => 9999, 'expense_date' => '2026-08-20']);

        $this->getJson('/api/admin/my-expenses')->assertOk()
            ->assertJsonPath('summary.total', 1500.5)
            ->assertJsonPath('summary.record_count', 2);
    });

    it('works out My Profit as the month\'s profit less the expenses', function () {
        apiOwner();
        apiProfitableHire(8000); // salary 1,600 → profit 6,400
        apiExpense(['amount' => 1000]);
        apiExpense(['amount' => 250.50, 'category' => 'marketing']);

        $this->getJson('/api/admin/my-expenses')->assertOk()
            ->assertJsonPath('summary.profit_before_expenses', 6400)
            ->assertJsonPath('summary.total', 1250.5)
            ->assertJsonPath('summary.my_profit', 5149.5);
    });

    it('adds other income to My Profit, and reports it', function () {
        apiOwner();
        apiProfitableHire(8000); // profit 6,400
        apiExpense(['amount' => 1000]);
        OtherIncome::create(['title' => 'ZZZ Shop rent', 'amount' => 1500, 'income_date' => '2026-09-08']);
        OtherIncome::create(['title' => 'ZZZ Interest', 'amount' => 250.5, 'income_date' => '2026-09-20']);
        OtherIncome::create(['title' => 'ZZZ last month', 'amount' => 9999, 'income_date' => '2026-08-20']);

        $this->getJson('/api/admin/my-expenses')->assertOk()
            ->assertJsonPath('summary.profit_before_expenses', 6400)
            ->assertJsonPath('summary.other_income_total', 1750.5)
            ->assertJsonPath('summary.other_income_count', 2)
            ->assertJsonPath('summary.total', 1000)
            ->assertJsonPath('summary.my_profit', 7150.5); // 6,400 + 1,750.50 - 1,000
    });

    it('reports no other income as zero', function () {
        apiOwner();
        apiProfitableHire(8000);

        $this->getJson('/api/admin/my-expenses')->assertOk()
            ->assertJsonPath('summary.other_income_total', 0)
            ->assertJsonPath('summary.other_income_count', 0)
            ->assertJsonPath('summary.my_profit', 6400);
    });

    it('matches the dashboard\'s Total Profit and the web page', function () {
        apiOwner();
        apiProfitableHire(8000);
        apiExpense(['amount' => 400]);

        $api = $this->getJson('/api/admin/my-expenses')->json('summary');
        $web = MyExpenseReport::forMonth(2026, 9);

        expect($api['profit_before_expenses'])->toEqual($web['profit_before_expenses'])->and($api['my_profit'])->toEqual($web['my_profit']);
    });

    it('can be a loss', function () {
        apiOwner();
        apiProfitableHire(1000); // profit 800
        apiExpense(['amount' => 2000]);

        $this->getJson('/api/admin/my-expenses')->assertJsonPath('summary.my_profit', -1200);
    });

    it('carries the working behind the profit', function () {
        apiOwner();
        apiProfitableHire(8000);

        $breakdown = $this->getJson('/api/admin/my-expenses')->json('summary.breakdown');

        expect($breakdown)->toMatchArray([
            'our_hire_value_total' => 8000, 'expenses_total' => 0, 'net_before_salary' => 8000,
            'salary_percentage' => 20, 'salary_total' => 1600, 'leasing_installment_total' => 0,
            'repair_cost_total' => 0, 'profit_total' => 6400,
        ]);
    });

    it('breaks the month down by category, biggest first, with names', function () {
        apiOwner();
        apiExpense(['category' => 'rent', 'amount' => 5000]);
        apiExpense(['category' => 'marketing', 'amount' => 700]);
        apiExpense(['category' => 'marketing', 'amount' => 800]);

        $this->getJson('/api/admin/my-expenses')->assertOk()->assertJsonPath('summary.by_category', [
            ['key' => 'rent', 'name' => 'Rent', 'total' => 5000],
            ['key' => 'marketing', 'name' => 'Marketing', 'total' => 1500],
        ]);
    });

    it('offers the years that have an expense, a hire, or are current', function () {
        apiOwner();
        apiExpense(['expense_date' => '2024-03-05']);
        apiProfitableHire(1000, '2025-06-01 09:00:00');

        $this->getJson('/api/admin/my-expenses')->assertOk()->assertJsonPath('years', [2026, 2025, 2024]);
    });

    it('pages a long month', function () {
        apiOwner();
        foreach (range(1, 25) as $n) {
            apiExpense(['title' => "ZZZ expense {$n}"]);
        }

        $first = $this->getJson('/api/admin/my-expenses')->assertOk();
        $last = $this->getJson('/api/admin/my-expenses?page=2&per_page=20')->assertOk();

        expect($first->json('data'))->toHaveCount(20)
            ->and($first->json('meta.last_page'))->toBe(2)
            ->and($first->json('meta.total'))->toBe(25)
            ->and($last->json('data'))->toHaveCount(5);
    });

    it('says an empty month is empty, with zero totals', function () {
        apiOwner();

        $this->getJson('/api/admin/my-expenses')->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonPath('summary.total', 0)
            ->assertJsonPath('summary.record_count', 0)
            ->assertJsonPath('summary.by_category', []);
    });

    it('turns down nonsense parameters', function (string $query) {
        apiOwner();

        $this->getJson("/api/admin/my-expenses?{$query}")->assertUnprocessable();
    })->with(['month=13', 'month=0', 'year=abc', 'year=1900', 'per_page=500', 'per_page=0']);
});

describe('filtering the list', function () {
    it('narrows to one category, leaving the month\'s totals alone', function () {
        apiOwner();
        apiProfitableHire(8000);
        apiExpense(['title' => 'ZZZ rent', 'category' => 'rent', 'amount' => 1000]);
        apiExpense(['title' => 'ZZZ ads', 'category' => 'marketing', 'amount' => 500]);

        $response = $this->getJson('/api/admin/my-expenses?category=marketing')->assertOk();

        expect(collect($response->json('data'))->pluck('title')->all())->toBe(['ZZZ ads']);
        $response->assertJsonPath('filtered_total', 500)
            ->assertJsonPath('summary.total', 1500)
            ->assertJsonPath('summary.my_profit', 4900);
    });

    it('ignores a category that does not exist', function () {
        apiOwner();
        apiExpense();

        expect($this->getJson('/api/admin/my-expenses?category=nonsense')->json('data'))->toHaveCount(1);
    });

    it('searches the title and the notes', function () {
        apiOwner();
        apiExpense(['title' => 'ZZZ Electricity bill', 'notes' => null]);
        apiExpense(['title' => 'ZZZ Ads', 'notes' => 'for the ZZZ billboard']);
        apiExpense(['title' => 'ZZZ Rent', 'notes' => 'monthly']);

        $byTitle = collect($this->getJson('/api/admin/my-expenses?search=Electricity')->json('data'))->pluck('title')->all();
        $byNotes = collect($this->getJson('/api/admin/my-expenses?search=billboard')->json('data'))->pluck('title')->all();

        expect($byTitle)->toBe(['ZZZ Electricity bill'])->and($byNotes)->toBe(['ZZZ Ads']);
    });

    it('reports the whole month as the filtered total when nothing is filtered', function () {
        apiOwner();
        apiExpense(['amount' => 300]);
        apiExpense(['amount' => 200]);

        $this->getJson('/api/admin/my-expenses')->assertJsonPath('filtered_total', 500);
    });
});

describe('adding an expense', function () {
    it('saves it and answers with it', function () {
        apiOwner();

        $response = $this->postJson('/api/admin/my-expenses', apiExpenseBody(['expense_date' => '2026-08-20']))->assertCreated();

        $response->assertJsonPath('data.title', 'ZZZ Office rent')
            ->assertJsonPath('data.category', 'rent')
            ->assertJsonPath('data.category_name', 'Rent')
            ->assertJsonPath('data.amount', 1500.5)
            ->assertJsonPath('data.expense_date', '2026-08-20')
            ->assertJsonPath('data.notes', 'ZZZ note');
        expect(MyExpense::count())->toBe(1);
    });

    it('takes an expense without notes', function () {
        apiOwner();

        $this->postJson('/api/admin/my-expenses', apiExpenseBody(['notes' => null]))->assertCreated()->assertJsonPath('data.notes', null);
    });

    it('creates a new category on the way, when asked', function () {
        apiOwner();

        $this->postJson('/api/admin/my-expenses', apiExpenseBody(['category' => '__new__', 'new_category' => 'Bank charges']))
            ->assertCreated()
            ->assertJsonPath('data.category', 'bank-charges')
            ->assertJsonPath('data.category_name', 'Bank charges');

        expect(MyExpenseCategory::where('key', 'bank-charges')->count())->toBe(1);
    });

    it('reuses a category that already has that name', function () {
        apiOwner();

        $this->postJson('/api/admin/my-expenses', apiExpenseBody(['category' => '__new__', 'new_category' => '  fuel ']))
            ->assertCreated()->assertJsonPath('data.category', 'fuel');

        expect(MyExpenseCategory::count())->toBe(9);
    });

    it('turns down bad input with the field named, saving nothing', function (array $changes, string $field) {
        apiOwner();

        $this->postJson('/api/admin/my-expenses', apiExpenseBody($changes))->assertUnprocessable()->assertJsonValidationErrors($field);

        expect(MyExpense::count())->toBe(0)->and(MyExpenseCategory::count())->toBe(9);
    })->with([
        'no title' => [['title' => ''], 'title'],
        'unknown category' => [['category' => 'yachts'], 'category'],
        'no amount' => [['amount' => ''], 'amount'],
        'zero amount' => [['amount' => '0'], 'amount'],
        'negative amount' => [['amount' => '-5'], 'amount'],
        'no date' => [['expense_date' => ''], 'expense_date'],
        'new category without a name' => [['category' => '__new__', 'new_category' => '   '], 'new_category'],
        'new category too long' => [['category' => '__new__', 'new_category' => 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'], 'new_category'],
    ]);

    it('creates no category when the rest of the expense is invalid', function () {
        apiOwner();

        $this->postJson('/api/admin/my-expenses', apiExpenseBody(['category' => '__new__', 'new_category' => 'Bank charges', 'amount' => '0']))
            ->assertUnprocessable();

        expect(MyExpenseCategory::where('name', 'Bank charges')->exists())->toBeFalse();
    });
});

describe('editing and deleting an expense', function () {
    it('changes it', function () {
        $expense = apiExpense();
        apiOwner();

        $this->putJson("/api/admin/my-expenses/{$expense->id}", apiExpenseBody(['title' => 'ZZZ Changed', 'category' => 'marketing', 'amount' => '77.25', 'expense_date' => '2026-07-04']))
            ->assertOk()
            ->assertJsonPath('data.title', 'ZZZ Changed')
            ->assertJsonPath('data.category_name', 'Marketing')
            ->assertJsonPath('data.amount', 77.25)
            ->assertJsonPath('data.expense_date', '2026-07-04');

        expect(MyExpense::count())->toBe(1)->and($expense->fresh()->title)->toBe('ZZZ Changed');
    });

    it('can move an expense into a brand new category', function () {
        $expense = apiExpense();
        apiOwner();

        $this->putJson("/api/admin/my-expenses/{$expense->id}", apiExpenseBody(['category' => '__new__', 'new_category' => 'Bank charges']))
            ->assertOk()->assertJsonPath('data.category_name', 'Bank charges');
    });

    it('will not save a bad edit', function () {
        $expense = apiExpense();
        apiOwner();

        $this->putJson("/api/admin/my-expenses/{$expense->id}", apiExpenseBody(['amount' => '-1']))->assertUnprocessable()->assertJsonValidationErrors('amount');

        expect((float) $expense->fresh()->amount)->toBe(1000.0);
    });

    it('deletes it, and only it', function () {
        $expense = apiExpense();
        $keep = apiExpense(['title' => 'ZZZ keep']);
        apiOwner();

        $this->deleteJson("/api/admin/my-expenses/{$expense->id}")->assertOk()->assertJsonPath('message', 'Expense "ZZZ Rent" was deleted.');

        expect(MyExpense::find($expense->id))->toBeNull()->and(MyExpense::find($keep->id))->not->toBeNull();
    });

    it('is 404 for an expense that is not there', function () {
        apiOwner();

        $this->putJson('/api/admin/my-expenses/999', apiExpenseBody())->assertNotFound();
        $this->deleteJson('/api/admin/my-expenses/999')->assertNotFound();
    });

    it('takes a deleted expense out of My Profit', function () {
        $expense = apiExpense(['amount' => 1000]);
        apiProfitableHire(8000);
        apiOwner();
        expect($this->getJson('/api/admin/my-expenses')->json('summary.my_profit'))->toEqual(5400);

        $this->deleteJson("/api/admin/my-expenses/{$expense->id}");

        expect($this->getJson('/api/admin/my-expenses')->json('summary.my_profit'))->toEqual(6400);
    });
});

describe('the categories', function () {
    it('lists them A to Z with how many expenses each has', function () {
        apiOwner();
        apiExpense(['category' => 'rent']);
        apiExpense(['category' => 'rent', 'expense_date' => '2026-01-05']);

        $response = $this->getJson('/api/admin/my-expense-categories')->assertOk();
        $names = collect($response->json('data'))->pluck('name')->all();
        $counts = collect($response->json('data'))->pluck('expenses_count', 'key');

        expect($names)->toBe(['Fuel', 'Insurance', 'Marketing', 'Office & Supplies', 'Others', 'Personal', 'Rent', 'Taxes & Licences', 'Utilities'])
            ->and($counts['rent'])->toBe(2)->and($counts['fuel'])->toBe(0);
    });

    it('adds one', function () {
        apiOwner();

        $this->postJson('/api/admin/my-expense-categories', ['name' => '  Bank   charges '])
            ->assertCreated()
            ->assertJsonPath('data.name', 'Bank charges')
            ->assertJsonPath('data.key', 'bank-charges')
            ->assertJsonPath('data.expenses_count', 0);
    });

    it('turns down a name that is empty, too long or already taken', function (string $name) {
        apiOwner();

        $this->postJson('/api/admin/my-expense-categories', ['name' => $name])->assertUnprocessable()->assertJsonValidationErrors('name');

        expect(MyExpenseCategory::count())->toBe(9);
    })->with(['empty' => [''], 'blank' => ['   '], 'too long' => [str_repeat('a', 61)], 'taken' => ['Rent'], 'taken in another case' => ['rENT']]);

    it('says why a name was refused', function () {
        apiOwner();

        $this->postJson('/api/admin/my-expense-categories', ['name' => 'rent'])
            ->assertJsonValidationErrors(['name' => 'A category with this name already exists.']);
    });

    it('renames one, keeping its key and its expenses', function () {
        apiOwner();
        $expense = apiExpense(['category' => 'fuel']);
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->putJson("/api/admin/my-expense-categories/{$category->id}", ['name' => 'Petrol'])
            ->assertOk()->assertJsonPath('data.name', 'Petrol')->assertJsonPath('data.key', 'fuel')->assertJsonPath('data.expenses_count', 1);

        expect($expense->fresh()->category_label)->toBe('Petrol');
    });

    it('lets a category keep its own name', function () {
        apiOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->putJson("/api/admin/my-expense-categories/{$category->id}", ['name' => 'Fuel'])->assertOk();
    });

    it('will not rename onto another category\'s name', function () {
        apiOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->putJson("/api/admin/my-expense-categories/{$category->id}", ['name' => 'rent'])->assertUnprocessable();

        expect($category->fresh()->name)->toBe('Fuel');
    });

    it('deletes one nothing is filed under', function () {
        apiOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->deleteJson("/api/admin/my-expense-categories/{$category->id}")->assertOk()->assertJsonPath('message', 'Category "Fuel" was deleted.');

        expect(MyExpenseCategory::where('key', 'fuel')->exists())->toBeFalse();
    });

    it('refuses to delete one in use, saying how many', function () {
        apiOwner();
        apiExpense(['category' => 'rent']);
        apiExpense(['category' => 'rent', 'expense_date' => '2026-01-05']);
        $category = MyExpenseCategory::where('key', 'rent')->first();

        $this->deleteJson("/api/admin/my-expense-categories/{$category->id}")
            ->assertUnprocessable()
            ->assertJsonPath('message', '"Rent" is used by 2 expenses — move or delete them first.');

        expect(MyExpenseCategory::where('key', 'rent')->exists())->toBeTrue();
    });

    it('is 404 for a category that is not there', function () {
        apiOwner();

        $this->putJson('/api/admin/my-expense-categories/999', ['name' => 'X'])->assertNotFound();
        $this->deleteJson('/api/admin/my-expense-categories/999')->assertNotFound();
    });

    it('needs the matching permission for each change', function () {
        $category = MyExpenseCategory::where('key', 'fuel')->first();
        apiOwner(['my-expenses.view', 'my-expenses.update']);

        $this->putJson("/api/admin/my-expense-categories/{$category->id}", ['name' => 'Petrol'])->assertOk();
        $this->postJson('/api/admin/my-expense-categories', ['name' => 'Bank charges'])->assertForbidden();
        $this->deleteJson("/api/admin/my-expense-categories/{$category->id}")->assertForbidden();
    });
});
