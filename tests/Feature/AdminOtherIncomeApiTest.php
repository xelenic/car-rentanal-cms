<?php

use App\Models\Hire;
use App\Models\MyExpense;
use App\Models\OtherIncome;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function incomeApiOwner(array $permissions = ['my-expenses.view', 'my-expenses.create', 'my-expenses.update', 'my-expenses.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function apiIncome(array $attributes = []): OtherIncome
{
    return OtherIncome::create($attributes + ['title' => 'ZZZ Shop rent', 'amount' => 1000, 'income_date' => '2026-09-10']);
}

function apiIncomeHire(float $our = 8000, string $start = '2026-09-05 09:00:00'): Hire
{
    return Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => $our + 2000, 'our_hire_value' => $our,
        'payment_type' => 'cash', 'start_time' => $start,
    ]);
}

function apiIncomeBody(array $changes = []): array
{
    return $changes + ['title' => 'ZZZ Interest', 'amount' => '750.25', 'income_date' => '2026-09-12', 'notes' => 'ZZZ note'];
}

describe('access', function () {
    it('needs a signed-in user', function () {
        $this->getJson('/api/admin/other-incomes')->assertUnauthorized();
        $this->postJson('/api/admin/other-incomes', [])->assertUnauthorized();
    });

    it('needs my-expenses.view to see the income', function () {
        incomeApiOwner(['hires.view']);

        $this->getJson('/api/admin/other-incomes')->assertForbidden();
    });

    it('lets view alone read but not write', function () {
        $income = apiIncome();
        incomeApiOwner(['my-expenses.view']);

        $this->getJson('/api/admin/other-incomes')->assertOk();
        $this->postJson('/api/admin/other-incomes', apiIncomeBody())->assertForbidden();
        $this->putJson("/api/admin/other-incomes/{$income->id}", apiIncomeBody())->assertForbidden();
        $this->deleteJson("/api/admin/other-incomes/{$income->id}")->assertForbidden();

        expect(OtherIncome::count())->toBe(1)->and($income->fresh()->title)->toBe('ZZZ Shop rent');
    });

    it('lets each write through only with its own permission', function () {
        $income = apiIncome();
        incomeApiOwner(['my-expenses.view', 'my-expenses.update']);

        $this->putJson("/api/admin/other-incomes/{$income->id}", apiIncomeBody(['title' => 'ZZZ Renamed']))->assertOk();
        $this->postJson('/api/admin/other-incomes', apiIncomeBody())->assertForbidden();
        $this->deleteJson("/api/admin/other-incomes/{$income->id}")->assertForbidden();
    });
});

describe('a month of other income', function () {
    it('opens on the current month, newest first, leaving other months out', function () {
        incomeApiOwner();
        apiIncome(['title' => 'ZZZ early', 'income_date' => '2026-09-01']);
        apiIncome(['title' => 'ZZZ late', 'income_date' => '2026-09-30']);
        apiIncome(['title' => 'ZZZ august', 'income_date' => '2026-08-31']);

        $response = $this->getJson('/api/admin/other-incomes')->assertOk();

        expect(collect($response->json('data'))->pluck('title')->all())->toBe(['ZZZ late', 'ZZZ early']);
        $response->assertJsonPath('summary.label', 'September 2026');
    });

    it('describes each entry', function () {
        incomeApiOwner();
        apiIncome(['title' => 'ZZZ Interest', 'amount' => 750.25, 'income_date' => '2026-09-12', 'notes' => 'ZZZ note']);

        $this->getJson('/api/admin/other-incomes')->assertOk()->assertJsonPath('data.0', [
            'id' => OtherIncome::first()->id, 'title' => 'ZZZ Interest', 'amount' => 750.25,
            'income_date' => '2026-09-12', 'notes' => 'ZZZ note',
        ]);
    });

    it('shows another month when asked', function () {
        incomeApiOwner();
        apiIncome(['title' => 'ZZZ august', 'income_date' => '2026-08-15']);

        $response = $this->getJson('/api/admin/other-incomes?year=2026&month=8')->assertOk();

        expect(collect($response->json('data'))->pluck('title')->all())->toBe(['ZZZ august']);
        $response->assertJsonPath('summary.label', 'August 2026');
    });

    it('carries the same summary as the expenses list, so the cards stay right whichever tab is open', function () {
        incomeApiOwner();
        apiIncomeHire(8000);
        apiIncome(['amount' => 1500]);
        MyExpense::create(['title' => 'ZZZ Rent', 'category' => 'rent', 'amount' => 1000, 'expense_date' => '2026-09-10']);

        $fromIncome = $this->getJson('/api/admin/other-incomes')->json('summary');
        $fromExpenses = $this->getJson('/api/admin/my-expenses')->json('summary');

        expect($fromIncome)->toEqual($fromExpenses)
            ->and($fromIncome['other_income_total'])->toEqual(1500)
            ->and($fromIncome['other_income_count'])->toBe(1)
            ->and($fromIncome['my_profit'])->toEqual(6900); // 6,400 + 1,500 - 1,000
    });

    it('searches the title and the notes, and says what the matches come to', function () {
        incomeApiOwner();
        apiIncome(['title' => 'ZZZ Shop rent', 'amount' => 1000, 'notes' => null]);
        apiIncome(['title' => 'ZZZ Interest', 'amount' => 250, 'notes' => 'bank savings']);
        apiIncome(['title' => 'ZZZ Sale', 'amount' => 500, 'notes' => 'old savings bond']);

        $response = $this->getJson('/api/admin/other-incomes?search=savings')->assertOk();

        expect(collect($response->json('data'))->pluck('title')->sort()->values()->all())->toBe(['ZZZ Interest', 'ZZZ Sale']);
        $response->assertJsonPath('filtered_total', 750)->assertJsonPath('summary.other_income_total', 1750);
    });

    it('reports the whole month as the filtered total when nothing is filtered', function () {
        incomeApiOwner();
        apiIncome(['amount' => 300]);
        apiIncome(['amount' => 200]);

        $this->getJson('/api/admin/other-incomes')->assertJsonPath('filtered_total', 500);
    });

    it('offers the years that have income, an expense, a hire or are current', function () {
        incomeApiOwner();
        apiIncome(['income_date' => '2024-03-05']);
        apiIncomeHire(1000, '2025-06-01 09:00:00');

        $this->getJson('/api/admin/other-incomes')->assertOk()->assertJsonPath('years', [2026, 2025, 2024]);
    });

    it('pages a long month', function () {
        incomeApiOwner();
        foreach (range(1, 25) as $n) {
            apiIncome(['title' => "ZZZ income {$n}"]);
        }

        $first = $this->getJson('/api/admin/other-incomes')->assertOk();
        $last = $this->getJson('/api/admin/other-incomes?page=2&per_page=20')->assertOk();

        expect($first->json('data'))->toHaveCount(20)->and($first->json('meta.last_page'))->toBe(2)->and($last->json('data'))->toHaveCount(5);
    });

    it('says an empty month is empty', function () {
        incomeApiOwner();

        $this->getJson('/api/admin/other-incomes')->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonPath('summary.other_income_total', 0)
            ->assertJsonPath('summary.other_income_count', 0);
    });

    it('turns down nonsense parameters', function (string $query) {
        incomeApiOwner();

        $this->getJson("/api/admin/other-incomes?{$query}")->assertUnprocessable();
    })->with(['month=13', 'month=0', 'year=abc', 'year=1900', 'per_page=500', 'per_page=0']);
});

describe('adding income', function () {
    it('saves it and answers with it', function () {
        incomeApiOwner();

        $this->postJson('/api/admin/other-incomes', apiIncomeBody(['income_date' => '2026-08-20']))
            ->assertCreated()
            ->assertJsonPath('data.title', 'ZZZ Interest')
            ->assertJsonPath('data.amount', 750.25)
            ->assertJsonPath('data.income_date', '2026-08-20')
            ->assertJsonPath('data.notes', 'ZZZ note');

        expect(OtherIncome::count())->toBe(1);
    });

    it('takes income without notes', function () {
        incomeApiOwner();

        $this->postJson('/api/admin/other-incomes', apiIncomeBody(['notes' => null]))->assertCreated()->assertJsonPath('data.notes', null);
    });

    it('turns down bad input with the field named, saving nothing', function (array $changes, string $field) {
        incomeApiOwner();

        $this->postJson('/api/admin/other-incomes', apiIncomeBody($changes))->assertUnprocessable()->assertJsonValidationErrors($field);

        expect(OtherIncome::count())->toBe(0);
    })->with([
        'no title' => [['title' => ''], 'title'],
        'title too long' => [['title' => str_repeat('a', 256)], 'title'],
        'no amount' => [['amount' => ''], 'amount'],
        'zero amount' => [['amount' => '0'], 'amount'],
        'negative amount' => [['amount' => '-5'], 'amount'],
        'amount not a number' => [['amount' => 'lots'], 'amount'],
        'no date' => [['income_date' => ''], 'income_date'],
        'date not a date' => [['income_date' => 'someday'], 'income_date'],
    ]);

    it('is in My Profit straight away', function () {
        incomeApiOwner();
        apiIncomeHire(8000);

        $this->postJson('/api/admin/other-incomes', apiIncomeBody(['amount' => '1000', 'income_date' => '2026-09-12']))->assertCreated();

        $this->getJson('/api/admin/my-expenses')->assertJsonPath('summary.my_profit', 7400);
    });
});

describe('editing and deleting income', function () {
    it('changes it', function () {
        $income = apiIncome();
        incomeApiOwner();

        $this->putJson("/api/admin/other-incomes/{$income->id}", apiIncomeBody(['title' => 'ZZZ Changed', 'amount' => '77.25', 'income_date' => '2026-07-04']))
            ->assertOk()
            ->assertJsonPath('data.title', 'ZZZ Changed')
            ->assertJsonPath('data.amount', 77.25)
            ->assertJsonPath('data.income_date', '2026-07-04');

        expect(OtherIncome::count())->toBe(1);
    });

    it('will not save a bad edit', function () {
        $income = apiIncome();
        incomeApiOwner();

        $this->putJson("/api/admin/other-incomes/{$income->id}", apiIncomeBody(['amount' => '-1']))->assertUnprocessable()->assertJsonValidationErrors('amount');

        expect((float) $income->fresh()->amount)->toBe(1000.0);
    });

    it('deletes it, and only it', function () {
        $income = apiIncome();
        $keep = apiIncome(['title' => 'ZZZ keep']);
        incomeApiOwner();

        $this->deleteJson("/api/admin/other-incomes/{$income->id}")->assertOk()->assertJsonPath('message', 'Income "ZZZ Shop rent" was deleted.');

        expect(OtherIncome::find($income->id))->toBeNull()->and(OtherIncome::find($keep->id))->not->toBeNull();
    });

    it('is 404 for income that is not there', function () {
        incomeApiOwner();

        $this->putJson('/api/admin/other-incomes/999', apiIncomeBody())->assertNotFound();
        $this->deleteJson('/api/admin/other-incomes/999')->assertNotFound();
    });

    it('takes deleted income out of My Profit', function () {
        $income = apiIncome(['amount' => 1000]);
        apiIncomeHire(8000);
        incomeApiOwner();
        expect($this->getJson('/api/admin/my-expenses')->json('summary.my_profit'))->toEqual(7400);

        $this->deleteJson("/api/admin/other-incomes/{$income->id}");

        expect($this->getJson('/api/admin/my-expenses')->json('summary.my_profit'))->toEqual(6400);
    });
});
