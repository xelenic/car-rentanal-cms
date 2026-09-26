<?php

use App\Models\Hire;
use App\Models\MyExpense;
use App\Models\OtherIncome;
use App\Models\User;
use App\Services\MyExpenseReport;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    // Wednesday midday, mid-September — "this month" below is September 2026.
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function incomeOwner(array $permissions = ['my-expenses.view', 'my-expenses.create', 'my-expenses.update', 'my-expenses.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function otherIncome(array $attributes = []): OtherIncome
{
    return OtherIncome::create($attributes + [
        'title' => 'ZZZ Shop rent', 'amount' => 1000, 'income_date' => '2026-09-10',
    ]);
}

function incomeHire(float $our = 8000, string $start = '2026-09-05 09:00:00'): Hire
{
    return Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => $our + 2000, 'our_hire_value' => $our,
        'payment_type' => 'cash', 'start_time' => $start,
    ]);
}

function incomeBody(array $changes = []): array
{
    return $changes + ['title' => 'ZZZ Interest', 'amount' => '750.25', 'income_date' => '2026-09-12', 'notes' => 'ZZZ note'];
}

describe('access', function () {
    it('is forbidden to add, edit or delete without the matching permission', function () {
        $income = otherIncome();
        incomeOwner(['my-expenses.view']);

        $this->post('/admin/other-incomes', incomeBody())->assertForbidden();
        $this->put("/admin/other-incomes/{$income->id}", incomeBody())->assertForbidden();
        $this->delete("/admin/other-incomes/{$income->id}")->assertForbidden();

        expect(OtherIncome::count())->toBe(1)->and($income->fresh()->title)->toBe('ZZZ Shop rent');
    });

    it('lets one action through without the others', function () {
        $income = otherIncome();
        incomeOwner(['my-expenses.view', 'my-expenses.update']);

        $this->put("/admin/other-incomes/{$income->id}", incomeBody(['title' => 'ZZZ Renamed']))->assertRedirect();
        $this->post('/admin/other-incomes', incomeBody())->assertForbidden();
        $this->delete("/admin/other-incomes/{$income->id}")->assertForbidden();

        expect($income->fresh()->title)->toBe('ZZZ Renamed');
    });

    it('sends a guest to the login page', function () {
        $this->post('/admin/other-incomes', incomeBody())->assertRedirect('/login');
    });

    it('does not show the buttons to someone who can only look', function () {
        otherIncome();
        incomeOwner(['my-expenses.view']);

        $this->get('/admin/my-expenses?tab=income')->assertOk()
            ->assertDontSee('id="add-income"', false)
            ->assertDontSee('modal-income-edit-')
            ->assertDontSee('Delete this income?');
    });
});

describe('the tabs', function () {
    it('open on Expenses, leaving the income list out', function () {
        incomeOwner();
        otherIncome(['title' => 'ZZZ Shop rent']);
        myExpense(['title' => 'ZZZ Rent']);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('tab'))->toBe('expenses')->and($response->viewData('incomes'))->toBeNull();
        $response->assertSee('id="my-expenses-table"', false)->assertDontSee('id="my-income-table"', false)->assertSee('ZZZ Rent')->assertDontSee('ZZZ Shop rent');
    });

    it('show the income list on the Other Income tab', function () {
        incomeOwner();
        otherIncome(['title' => 'ZZZ Shop rent']);
        myExpense(['title' => 'ZZZ Rent']);

        $response = $this->get('/admin/my-expenses?tab=income')->assertOk();

        expect($response->viewData('tab'))->toBe('income')->and($response->viewData('expenses'))->toBeNull();
        $response->assertSee('id="my-income-table"', false)->assertDontSee('id="my-expenses-table"', false)->assertSee('ZZZ Shop rent')->assertDontSee('ZZZ Rent');
    });

    it('treat an unknown tab as Expenses', function () {
        incomeOwner();

        expect($this->get('/admin/my-expenses?tab=whatever')->viewData('tab'))->toBe('expenses');
    });

    it('carry the record counts and keep the month when switching', function () {
        incomeOwner();
        otherIncome();
        otherIncome(['title' => 'ZZZ Interest']);
        myExpense();

        $html = $this->get('/admin/my-expenses?year=2026&month=8')->assertOk()->getContent();

        expect($html)->toContain('id="tab-expenses"')->and($html)->toContain('id="tab-income"')
            ->and($html)->toContain(e(route('admin.my-expenses.index', ['tab' => 'income', 'year' => 2026, 'month' => 8])));

        $this->get('/admin/my-expenses')->assertSeeInOrder(['id="tab-expenses"', '1</span>', 'id="tab-income"', '2</span>'], false);
    });
});

describe('the income list', function () {
    it('shows this month\'s income newest first, leaving other months out', function () {
        incomeOwner();
        otherIncome(['title' => 'ZZZ early', 'income_date' => '2026-09-01']);
        otherIncome(['title' => 'ZZZ late', 'income_date' => '2026-09-30']);
        otherIncome(['title' => 'ZZZ august', 'income_date' => '2026-08-31']);
        otherIncome(['title' => 'ZZZ october', 'income_date' => '2026-10-01']);

        $response = $this->get('/admin/my-expenses?tab=income')->assertOk();

        expect($response->viewData('incomes')->pluck('title')->all())->toBe(['ZZZ late', 'ZZZ early']);
    });

    it('shows another month when asked', function () {
        incomeOwner();
        otherIncome(['title' => 'ZZZ august', 'income_date' => '2026-08-15']);

        $response = $this->get('/admin/my-expenses?tab=income&year=2026&month=8')->assertOk();

        expect($response->viewData('incomes')->pluck('title')->all())->toBe(['ZZZ august']);
    });

    it('searches the title and the notes, and says what the matches come to', function () {
        incomeOwner();
        otherIncome(['title' => 'ZZZ Shop rent', 'amount' => 1000, 'notes' => null]);
        otherIncome(['title' => 'ZZZ Interest', 'amount' => 250, 'notes' => 'bank savings']);
        otherIncome(['title' => 'ZZZ Sale', 'amount' => 500, 'notes' => 'old savings bond']);

        $response = $this->get('/admin/my-expenses?tab=income&search=savings')->assertOk();

        expect($response->viewData('incomes')->pluck('title')->sort()->values()->all())->toBe(['ZZZ Interest', 'ZZZ Sale'])
            ->and($response->viewData('filteredIncomeTotal'))->toBe(750.0);
        $response->assertSee('id="filtered-income-total"', false);
    });

    it('never lets a search change the month\'s figures', function () {
        incomeOwner();
        incomeHire(8000);
        otherIncome(['title' => 'ZZZ Shop rent', 'amount' => 1000]);
        otherIncome(['title' => 'ZZZ Interest', 'amount' => 250]);

        $response = $this->get('/admin/my-expenses?tab=income&search=Interest')->assertOk();

        expect($response->viewData('otherIncomeTotal'))->toBe(1250.0)
            ->and($response->viewData('myProfit'))->toBe(7650.0); // 6,400 + 1,250
    });

    it('ignores a category on the income tab', function () {
        incomeOwner();
        otherIncome();

        expect($this->get('/admin/my-expenses?tab=income&category=rent')->viewData('incomes')->count())->toBe(1);
    });

    it('says so when the month has no income', function () {
        incomeOwner();

        $this->get('/admin/my-expenses?tab=income')->assertOk()->assertSee('No other income recorded for September 2026.');
    });

    it('pages a long month', function () {
        incomeOwner();
        foreach (range(1, 20) as $n) {
            otherIncome(['title' => "ZZZ income {$n}"]);
        }

        $first = $this->get('/admin/my-expenses?tab=income')->viewData('incomes');
        $second = $this->get('/admin/my-expenses?tab=income&page=2')->viewData('incomes');

        expect($first->count())->toBe(15)->and($first->total())->toBe(20)->and($second->count())->toBe(5);
    });
});

describe('my profit', function () {
    it('adds other income to the profit from hires and takes the expenses off', function () {
        incomeOwner();
        incomeHire(8000); // profit 6,400
        otherIncome(['amount' => 1500]);
        otherIncome(['amount' => 250.50, 'title' => 'ZZZ Interest']);
        myExpense(['amount' => 1000]);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('profitBeforeExpenses'))->toBe(6400.0)
            ->and($response->viewData('otherIncomeTotal'))->toBe(1750.5)
            ->and($response->viewData('total'))->toBe(1000.0)
            ->and($response->viewData('myProfit'))->toBe(7150.5); // 6,400 + 1,750.50 - 1,000
        $response->assertSee('id="card-other-income"', false)->assertSeeInOrder(['Other Income', 'Rs. 1,750.50', '2 entries']);
    });

    it('is unchanged when there is no other income', function () {
        incomeOwner();
        incomeHire(8000);
        myExpense(['amount' => 1000]);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('otherIncomeTotal'))->toBe(0.0)->and($response->viewData('myProfit'))->toBe(5400.0);
        $response->assertSee('0 entries');
    });

    it('turns a loss into a profit when the income covers it', function () {
        incomeOwner();
        incomeHire(1000); // profit 800
        myExpense(['amount' => 2000]);
        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(-1200.0);

        otherIncome(['amount' => 1500]);

        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(300.0);
    });

    it('counts only the viewed month\'s income against that month', function () {
        incomeOwner();
        incomeHire(8000);
        incomeHire(4000, '2026-08-10 09:00:00'); // August profit 3,200
        otherIncome(['amount' => 1000, 'income_date' => '2026-09-05']);
        otherIncome(['amount' => 700, 'income_date' => '2026-08-05']);

        expect($this->get('/admin/my-expenses?year=2026&month=9')->viewData('myProfit'))->toBe(7400.0)
            ->and($this->get('/admin/my-expenses?year=2026&month=8')->viewData('myProfit'))->toBe(3900.0);
    });

    it('is not added to the dashboard\'s Total Profit, which stays the profit from hires', function () {
        incomeOwner(['my-expenses.view']);
        incomeHire(8000);
        otherIncome(['amount' => 5000]);

        expect($this->get('/admin')->viewData('summary')['profit_total'])->toBe(6400.0);
    });

    it('is explained line by line, with the income in it', function () {
        incomeOwner();
        incomeHire(8000);
        otherIncome(['amount' => 1500, 'income_date' => '2026-09-08']);
        myExpense(['amount' => 1000]);

        $this->get('/admin/my-expenses')->assertOk()
            ->assertSee('Add: Other Income (1 entry)')
            ->assertSee('+Rs. 1,500.00')
            ->assertSeeInOrder(['Profit From Hires (Rs. 6,400.00)', '+ Other Income (Rs. 1,500.00)', '− My Expenses (Rs. 1,000.00)', '= Rs. 6,900.00.']);
    });

    it('is worked out by the shared month report', function () {
        incomeHire(8000);
        otherIncome(['amount' => 1500]);
        myExpense(['amount' => 1000]);

        $report = MyExpenseReport::forMonth(2026, 9);

        expect($report['other_income_total'])->toBe(1500.0)->and($report['other_income_count'])->toBe(1)
            ->and($report['profit_before_expenses'])->toBe(6400.0)->and($report['my_profit'])->toBe(6900.0);
    });

    it('offers the years that only have other income', function () {
        incomeOwner();
        otherIncome(['income_date' => '2023-04-01']);

        expect($this->get('/admin/my-expenses')->viewData('availableYears'))->toContain(2023);
    });
});

describe('adding income', function () {
    it('saves it and lands on that month\'s income tab', function () {
        incomeOwner();

        $this->post('/admin/other-incomes', incomeBody(['income_date' => '2026-08-20']))
            ->assertRedirect(route('admin.my-expenses.index', ['tab' => 'income', 'year' => 2026, 'month' => 8]))
            ->assertSessionHas('status', 'Income "ZZZ Interest" was added.');

        $income = OtherIncome::first();
        expect($income->title)->toBe('ZZZ Interest')
            ->and((float) $income->amount)->toBe(750.25)
            ->and($income->income_date->format('Y-m-d'))->toBe('2026-08-20')
            ->and($income->notes)->toBe('ZZZ note');
    });

    it('takes income without notes', function () {
        incomeOwner();

        $this->post('/admin/other-incomes', incomeBody(['notes' => null]))->assertRedirect();

        expect(OtherIncome::first()->notes)->toBeNull();
    });

    it('turns down bad input, saying why and saving nothing', function (array $changes, string $field) {
        incomeOwner();

        $this->post('/admin/other-incomes', incomeBody($changes))->assertSessionHasErrors($field);

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

    it('reopens the form with the errors when it is turned down', function () {
        incomeOwner();

        $this->from('/admin/my-expenses')->post('/admin/other-incomes', incomeBody(['title' => '', 'form_id' => 'income-create']))
            ->assertRedirect('/admin/my-expenses')
            ->assertSessionHasErrors('title')
            ->assertSessionHasInput('form_id', 'income-create');

        $page = $this->followingRedirects()->from('/admin/my-expenses')->post('/admin/other-incomes', incomeBody(['title' => '', 'form_id' => 'income-create']));
        $page->assertSee('var reopenId = "income-create"', false);
    });

    it('is reflected in My Profit straight away', function () {
        incomeOwner();
        incomeHire(8000);

        $this->post('/admin/other-incomes', incomeBody(['amount' => '1000', 'income_date' => '2026-09-12']));

        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(7400.0);
    });
});

describe('editing and deleting income', function () {
    it('changes it and returns to its month', function () {
        $income = otherIncome();
        incomeOwner();

        $this->put("/admin/other-incomes/{$income->id}", incomeBody(['title' => 'ZZZ Changed', 'amount' => '77.25', 'income_date' => '2026-07-04']))
            ->assertRedirect(route('admin.my-expenses.index', ['tab' => 'income', 'year' => 2026, 'month' => 7]))
            ->assertSessionHas('status', 'Income "ZZZ Changed" was updated.');

        $fresh = $income->fresh();
        expect($fresh->title)->toBe('ZZZ Changed')->and((float) $fresh->amount)->toBe(77.25)
            ->and($fresh->income_date->format('Y-m-d'))->toBe('2026-07-04')->and(OtherIncome::count())->toBe(1);
    });

    it('will not save a bad edit', function () {
        $income = otherIncome();
        incomeOwner();

        $this->put("/admin/other-incomes/{$income->id}", incomeBody(['amount' => '-1']))->assertSessionHasErrors('amount');

        expect((float) $income->fresh()->amount)->toBe(1000.0);
    });

    it('deletes it, and only it', function () {
        $income = otherIncome();
        $keep = otherIncome(['title' => 'ZZZ keep']);
        incomeOwner();

        $this->delete("/admin/other-incomes/{$income->id}")
            ->assertRedirect(route('admin.my-expenses.index', ['tab' => 'income', 'year' => 2026, 'month' => 9]))
            ->assertSessionHas('status', 'Income "ZZZ Shop rent" was deleted.');

        expect(OtherIncome::find($income->id))->toBeNull()->and(OtherIncome::find($keep->id))->not->toBeNull();
    });

    it('is 404 for income that is not there', function () {
        incomeOwner();

        $this->put('/admin/other-incomes/999', incomeBody())->assertNotFound();
        $this->delete('/admin/other-incomes/999')->assertNotFound();
    });

    it('takes deleted income out of My Profit', function () {
        $income = otherIncome(['amount' => 1000]);
        incomeHire(8000);
        incomeOwner();
        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(7400.0);

        $this->delete("/admin/other-incomes/{$income->id}");

        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(6400.0);
    });

    it('gives each row an edit form filled in with its details', function () {
        $income = otherIncome(['title' => 'ZZZ Shop rent', 'amount' => 1234.5, 'income_date' => '2026-09-03', 'notes' => 'ZZZ keys handed over']);
        incomeOwner();

        $this->get('/admin/my-expenses?tab=income')->assertOk()
            ->assertSee("modal-income-edit-{$income->id}", false)
            ->assertSee('value="ZZZ Shop rent"', false)
            ->assertSee('value="1234.50"', false)
            ->assertSee('value="2026-09-03"', false)
            ->assertSee('ZZZ keys handed over');
    });
});

describe('the expenses side is untouched', function () {
    it('still totals, filters and lists expenses exactly as before', function () {
        incomeOwner();
        myExpense(['title' => 'ZZZ rent', 'category' => 'rent', 'amount' => 1000]);
        myExpense(['title' => 'ZZZ ads', 'category' => 'marketing', 'amount' => 500]);
        otherIncome(['amount' => 9999]);

        $response = $this->get('/admin/my-expenses?category=marketing')->assertOk();

        expect($response->viewData('expenses')->pluck('title')->all())->toBe(['ZZZ ads'])
            ->and($response->viewData('total'))->toBe(1500.0)
            ->and($response->viewData('filteredTotal'))->toBe(500.0);
        expect(MyExpense::count())->toBe(2);
    });
});
