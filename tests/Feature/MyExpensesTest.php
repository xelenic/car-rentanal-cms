<?php

use App\Models\Driver;
use App\Models\Hire;
use App\Models\MyExpense;
use App\Models\User;
use App\Models\Vehicle;
use App\Models\VehicleLeasing;
use App\Models\VehicleLeasingSettlement;
use App\Models\VehicleMaintenanceRecord;
use App\Services\ProfitCalculator;
use Database\Seeders\RolePermissionSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

uses(RefreshDatabase::class);

const MY_EXPENSE_PERMISSIONS = ['my-expenses.view', 'my-expenses.create', 'my-expenses.update', 'my-expenses.delete'];

beforeEach(function () {
    // Wednesday midday, mid-September — "this month" below is September 2026.
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function ownerSignedIn(array $permissions = MY_EXPENSE_PERMISSIONS): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function myExpense(array $attributes = []): MyExpense
{
    return MyExpense::create($attributes + [
        'title' => 'ZZZ Test Rent', 'category' => 'rent', 'amount' => 1000, 'expense_date' => '2026-09-10',
    ]);
}

/** A hire in the month whose Our Hire Value is $our: driver salary is 20% of it, so profit is 80% of it. */
function profitableHire(float $our = 8000, string $start = '2026-09-05 09:00:00'): Hire
{
    return Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => $our + 2000, 'our_hire_value' => $our,
        'payment_type' => 'cash', 'start_time' => $start,
    ]);
}

function expenseFormBody(array $changes = []): array
{
    return $changes + ['title' => 'ZZZ Office rent', 'category' => 'rent', 'amount' => '1500.50', 'expense_date' => '2026-09-12', 'notes' => 'ZZZ note'];
}

describe('access', function () {
    it('sends a guest to the login page', function () {
        $this->get('/admin/my-expenses')->assertRedirect('/login');
    });

    it('is forbidden without my-expenses.view', function () {
        ownerSignedIn(['hires.view']);

        $this->get('/admin/my-expenses')->assertForbidden();
    });

    it('lets each action through only with its own permission', function () {
        $expense = myExpense();
        ownerSignedIn(['my-expenses.view']);

        $this->get('/admin/my-expenses')->assertOk();
        $this->post('/admin/my-expenses', expenseFormBody())->assertForbidden();
        $this->put("/admin/my-expenses/{$expense->id}", expenseFormBody())->assertForbidden();
        $this->delete("/admin/my-expenses/{$expense->id}")->assertForbidden();

        expect(MyExpense::count())->toBe(1)->and($expense->fresh()->title)->toBe('ZZZ Test Rent');
    });

    it('is given to Super Admin only, not to Admin or Driver, by the seeder', function () {
        $this->seed(RolePermissionSeeder::class);

        foreach (MY_EXPENSE_PERMISSIONS as $permission) {
            expect(Role::findByName('Super Admin')->hasPermissionTo($permission))->toBeTrue($permission)
                ->and(Role::findByName('Admin')->hasPermissionTo($permission))->toBeFalse($permission)
                ->and(Role::findByName('Driver')->hasPermissionTo($permission))->toBeFalse($permission);
        }
    });
});

describe('the sidebar', function () {
    it('links to My Expenses for someone who may view them', function () {
        ownerSignedIn();

        $this->get('/admin')->assertOk()
            ->assertSee('My Expenses')
            ->assertSee(route('admin.my-expenses.index'), false);
    });

    it('does not show it to someone who may not', function () {
        ownerSignedIn(['hires.view']);

        $this->get('/admin/expenses')->assertOk()->assertDontSee('My Expenses');
    });

    it('marks it active on its own page', function () {
        ownerSignedIn();

        $html = $this->get('/admin/my-expenses')->assertOk()->getContent();

        expect($html)->toMatch('/class="nav-link active" href="[^"]*\/admin\/my-expenses"/');
    });
});

describe('the page', function () {
    it('opens on the current month', function () {
        ownerSignedIn();

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('selectedYear'))->toBe(2026)
            ->and($response->viewData('selectedMonth'))->toBe(9)
            ->and($response->viewData('periodLabel'))->toBe('September 2026');
    });

    it('lists this month\'s expenses, newest first, and leaves other months out', function () {
        ownerSignedIn();
        myExpense(['title' => 'ZZZ early', 'expense_date' => '2026-09-01']);
        myExpense(['title' => 'ZZZ late', 'expense_date' => '2026-09-30']);
        myExpense(['title' => 'ZZZ august', 'expense_date' => '2026-08-31']);
        myExpense(['title' => 'ZZZ october', 'expense_date' => '2026-10-01']);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('expenses')->pluck('title')->all())->toBe(['ZZZ late', 'ZZZ early']);
        $response->assertSee('ZZZ late')->assertDontSee('ZZZ august')->assertDontSee('ZZZ october');
    });

    it('shows another month when asked', function () {
        ownerSignedIn();
        myExpense(['title' => 'ZZZ august', 'expense_date' => '2026-08-15']);

        $response = $this->get('/admin/my-expenses?year=2026&month=8')->assertOk();

        expect($response->viewData('periodLabel'))->toBe('August 2026')
            ->and($response->viewData('expenses')->pluck('title')->all())->toBe(['ZZZ august']);
    });

    it('falls back to this month for a month that does not exist', function () {
        ownerSignedIn();

        expect($this->get('/admin/my-expenses?year=2026&month=13')->viewData('selectedMonth'))->toBe(9)
            ->and($this->get('/admin/my-expenses?year=2026&month=0')->viewData('selectedMonth'))->toBe(9);
    });

    it('totals the month\'s expenses and counts them', function () {
        ownerSignedIn();
        myExpense(['amount' => 1200.50, 'expense_date' => '2026-09-02']);
        myExpense(['amount' => 300, 'expense_date' => '2026-09-20']);
        myExpense(['amount' => 9999, 'expense_date' => '2026-08-20']);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('total'))->toBe(1500.5)->and($response->viewData('recordCount'))->toBe(2);
        $response->assertSeeInOrder(['Total My Expenses', 'Rs. 1,500.50', '2 records']);
    });

    it('breaks the month down by category, biggest first', function () {
        ownerSignedIn();
        myExpense(['category' => 'rent', 'amount' => 5000]);
        myExpense(['category' => 'marketing', 'amount' => 700]);
        myExpense(['category' => 'marketing', 'amount' => 800]);
        myExpense(['category' => 'rent', 'amount' => 999, 'expense_date' => '2026-08-01']);

        $byCategory = $this->get('/admin/my-expenses')->viewData('byCategory');

        expect($byCategory->all())->toBe(['rent' => 5000.0, 'marketing' => 1500.0]);
    });

    it('says so when the month has no expenses', function () {
        ownerSignedIn();

        $this->get('/admin/my-expenses')->assertOk()->assertSee('No expenses recorded for September 2026.');
    });

    it('offers the years that have an expense, a hire, or are the current one', function () {
        ownerSignedIn();
        myExpense(['expense_date' => '2024-03-05']);
        profitableHire(1000, '2025-06-01 09:00:00');

        $years = $this->get('/admin/my-expenses')->viewData('availableYears');

        expect($years)->toBe([2026, 2025, 2024]);
    });

    it('pages a long month', function () {
        ownerSignedIn();
        foreach (range(1, 20) as $n) {
            myExpense(['title' => "ZZZ expense {$n}", 'expense_date' => '2026-09-'.str_pad((string) (($n % 28) + 1), 2, '0', STR_PAD_LEFT)]);
        }

        $first = $this->get('/admin/my-expenses')->viewData('expenses');
        $second = $this->get('/admin/my-expenses?page=2')->viewData('expenses');

        expect($first->count())->toBe(15)->and($first->total())->toBe(20)->and($second->count())->toBe(5);
    });

    it('includes the first and last day of the month and nothing from beside it', function () {
        ownerSignedIn();
        myExpense(['title' => 'ZZZ first', 'expense_date' => '2026-09-01']);
        myExpense(['title' => 'ZZZ last', 'expense_date' => '2026-09-30']);
        myExpense(['title' => 'ZZZ before', 'expense_date' => '2026-08-31']);
        myExpense(['title' => 'ZZZ after', 'expense_date' => '2026-10-01']);

        expect(MyExpense::inMonth(2026, 9)->pluck('title')->sort()->values()->all())->toBe(['ZZZ first', 'ZZZ last']);
    });
});

describe('filtering the list', function () {
    it('narrows the list to one category', function () {
        ownerSignedIn();
        myExpense(['title' => 'ZZZ rent', 'category' => 'rent']);
        myExpense(['title' => 'ZZZ ads', 'category' => 'marketing']);

        $response = $this->get('/admin/my-expenses?category=marketing')->assertOk();

        expect($response->viewData('expenses')->pluck('title')->all())->toBe(['ZZZ ads']);
    });

    it('ignores a category that does not exist', function () {
        ownerSignedIn();
        myExpense(['title' => 'ZZZ rent']);

        expect($this->get('/admin/my-expenses?category=nonsense')->viewData('expenses')->count())->toBe(1);
    });

    it('searches the title and the notes', function () {
        ownerSignedIn();
        myExpense(['title' => 'ZZZ Electricity bill', 'notes' => null]);
        myExpense(['title' => 'ZZZ Ads', 'notes' => 'for the ZZZ billboard']);
        myExpense(['title' => 'ZZZ Rent', 'notes' => 'monthly']);

        $byTitle = $this->get('/admin/my-expenses?search=Electricity')->viewData('expenses')->pluck('title')->all();
        $byNotes = $this->get('/admin/my-expenses?search=billboard')->viewData('expenses')->pluck('title')->all();

        expect($byTitle)->toBe(['ZZZ Electricity bill'])->and($byNotes)->toBe(['ZZZ Ads']);
    });

    it('never changes the month\'s totals or profit — only the list', function () {
        ownerSignedIn();
        profitableHire(8000);
        myExpense(['category' => 'rent', 'amount' => 1000]);
        myExpense(['category' => 'marketing', 'amount' => 500]);

        $response = $this->get('/admin/my-expenses?category=marketing')->assertOk();

        expect($response->viewData('expenses')->count())->toBe(1)
            ->and($response->viewData('total'))->toBe(1500.0)
            ->and($response->viewData('myProfit'))->toBe(4900.0) // 6,400 - 1,500
            ->and($response->viewData('filteredTotal'))->toBe(500.0);
        $response->assertSee('id="filtered-total"', false);
    });
});

describe('my profit', function () {
    it('is the month\'s profit less my expenses', function () {
        ownerSignedIn();
        profitableHire(8000); // salary 1,600 → profit 6,400
        myExpense(['amount' => 1000]);
        myExpense(['amount' => 250.50, 'category' => 'marketing']);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('profitBeforeExpenses'))->toBe(6400.0)
            ->and($response->viewData('total'))->toBe(1250.5)
            ->and($response->viewData('myProfit'))->toBe(5149.5);
        $response->assertSee('id="card-my-profit"', false)
            ->assertSeeInOrder(['My Profit', 'Rs. 5,149.50']);
    });

    it('is the same as the dashboard\'s Total Profit when there are no expenses', function () {
        ownerSignedIn(['my-expenses.view']);
        profitableHire(8000);
        profitableHire(2000, '2026-09-20 09:00:00');

        $mine = $this->get('/admin/my-expenses')->viewData('profitBeforeExpenses');
        $dashboard = $this->get('/admin')->viewData('summary')['profit_total'];

        expect($mine)->toBe(8000.0)->and($dashboard)->toBe($mine);
    });

    it('also takes off leasing installments and vehicle repairs, like the dashboard', function () {
        ownerSignedIn();
        profitableHire(8000);
        $vehicle = Vehicle::create(['model' => 'ZZZ Van', 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
        $driver = Driver::create([
            'user_id' => User::factory()->create()->id, 'name' => 'ZZZ Driver', 'license' => 'B1', 'contact_number' => '077',
            'email' => 'zzz-driver@example.test', 'password' => 'secret-pass',
        ]);
        VehicleMaintenanceRecord::create(['vehicle_id' => $vehicle->id, 'driver_id' => $driver->id, 'type' => 'repair', 'cost' => 500, 'bill_path' => 'x.jpg']);
        $leasing = VehicleLeasing::create([
            'vehicle_id' => $vehicle->id, 'company' => 'ZZZ Finance', 'loan_amount' => 100000, 'monthly_installment' => 1000,
            'balance_remaining' => 99000, 'start_date' => '2026-01-01',
        ]);
        VehicleLeasingSettlement::create(['leasing_id' => $leasing->id, 'year' => 2026, 'month' => 9, 'amount' => 1000]);
        myExpense(['amount' => 400]);

        $response = $this->get('/admin/my-expenses')->assertOk();

        // 8,000 − 1,600 salary − 1,000 leasing − 500 repairs = 4,900; less 400 of my own.
        expect($response->viewData('profitBeforeExpenses'))->toBe(4900.0)
            ->and($response->viewData('myProfit'))->toBe(4500.0)
            ->and($this->get('/admin')->viewData('summary')['profit_total'])->toBe(4900.0);
    });

    it('can go negative, and shows it as a loss', function () {
        ownerSignedIn();
        profitableHire(1000); // profit 800
        myExpense(['amount' => 2000]);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('myProfit'))->toBe(-1200.0);
        $response->assertSee('-Rs. 1,200.00');
    });

    it('is just the profit when nothing was spent', function () {
        ownerSignedIn();
        profitableHire(8000);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('myProfit'))->toBe(6400.0)->and($response->viewData('total'))->toBe(0.0);
    });

    it('counts only the viewed month\'s expenses against that month\'s profit', function () {
        ownerSignedIn();
        profitableHire(8000);
        profitableHire(4000, '2026-08-10 09:00:00'); // August profit 3,200
        myExpense(['amount' => 1000, 'expense_date' => '2026-09-05']);
        myExpense(['amount' => 700, 'expense_date' => '2026-08-05']);

        $september = $this->get('/admin/my-expenses?year=2026&month=9')->viewData('myProfit');
        $august = $this->get('/admin/my-expenses?year=2026&month=8')->viewData('myProfit');

        expect($september)->toBe(5400.0)->and($august)->toBe(2500.0);
    });

    it('explains itself, line by line', function () {
        ownerSignedIn();
        profitableHire(8000);
        myExpense(['category' => 'rent', 'amount' => 1000]);

        $this->get('/admin/my-expenses')->assertOk()
            ->assertSee('My Profit — Full Calculation (September 2026)')
            ->assertSee('Less: Driver Salary (20%)')
            ->assertSee('Less: Leasing Installments')
            ->assertSee('Less: Vehicle Repair Cost')
            ->assertSee('Profit Before My Expenses')
            ->assertSee('Less: My Expenses')
            ->assertSeeInOrder(['Profit Before My Expenses (Rs. 6,400.00)', '− My Expenses (Rs. 1,000.00)', '= Rs. 5,400.00.']);
    });

    it('is worked out by the same calculator the dashboard uses', function () {
        profitableHire(8000);

        $breakdown = ProfitCalculator::breakdownFor(2026, 9);

        expect($breakdown['profit_total'])->toBe(6400.0)
            ->and($breakdown['salary_total'])->toBe(1600.0)
            ->and($breakdown['our_hire_value_total'])->toBe(8000.0)
            ->and(ProfitCalculator::profitFrom(['net_before_salary' => 8000.0, 'salary' => 1600.0], 1000.0, 500.0))->toBe(4900.0);
    });
});

describe('adding an expense', function () {
    it('saves it and lands on the month it belongs to', function () {
        ownerSignedIn();

        $this->post('/admin/my-expenses', expenseFormBody(['expense_date' => '2026-08-20']))
            ->assertRedirect(route('admin.my-expenses.index', ['year' => 2026, 'month' => 8]))
            ->assertSessionHas('status', 'Expense "ZZZ Office rent" was added.');

        $expense = MyExpense::first();
        expect($expense->title)->toBe('ZZZ Office rent')
            ->and($expense->category)->toBe('rent')
            ->and((float) $expense->amount)->toBe(1500.5)
            ->and($expense->expense_date->format('Y-m-d'))->toBe('2026-08-20')
            ->and($expense->notes)->toBe('ZZZ note');
    });

    it('takes an expense without notes', function () {
        ownerSignedIn();

        $this->post('/admin/my-expenses', expenseFormBody(['notes' => null]))->assertRedirect();

        expect(MyExpense::first()->notes)->toBeNull();
    });

    it('turns down bad input, says why and saves nothing', function (array $changes, string $field) {
        ownerSignedIn();

        $this->post('/admin/my-expenses', expenseFormBody($changes))->assertSessionHasErrors($field);

        expect(MyExpense::count())->toBe(0);
    })->with([
        'no title' => [['title' => ''], 'title'],
        'title too long' => [['title' => str_repeat('a', 256)], 'title'],
        'unknown category' => [['category' => 'yachts'], 'category'],
        'no amount' => [['amount' => ''], 'amount'],
        'zero amount' => [['amount' => '0'], 'amount'],
        'negative amount' => [['amount' => '-5'], 'amount'],
        'amount not a number' => [['amount' => 'lots'], 'amount'],
        'no date' => [['expense_date' => ''], 'expense_date'],
        'date not a date' => [['expense_date' => 'someday'], 'expense_date'],
    ]);

    it('reopens the form with the errors when it is turned down', function () {
        ownerSignedIn();

        $this->from('/admin/my-expenses')->post('/admin/my-expenses', expenseFormBody(['title' => '', 'form_id' => 'create']))
            ->assertRedirect('/admin/my-expenses')
            ->assertSessionHasErrors('title')
            ->assertSessionHasInput('form_id', 'create');
    });

    it('is reflected in the totals straight away', function () {
        ownerSignedIn();
        profitableHire(8000);

        $this->post('/admin/my-expenses', expenseFormBody(['amount' => '1000', 'expense_date' => '2026-09-12']));
        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('total'))->toBe(1000.0)->and($response->viewData('myProfit'))->toBe(5400.0);
    });
});

describe('editing and deleting an expense', function () {
    it('changes it and returns to its month', function () {
        $expense = myExpense();
        ownerSignedIn();

        $this->put("/admin/my-expenses/{$expense->id}", expenseFormBody(['title' => 'ZZZ Changed', 'category' => 'marketing', 'amount' => '77.25', 'expense_date' => '2026-07-04']))
            ->assertRedirect(route('admin.my-expenses.index', ['year' => 2026, 'month' => 7]))
            ->assertSessionHas('status', 'Expense "ZZZ Changed" was updated.');

        $fresh = $expense->fresh();
        expect($fresh->title)->toBe('ZZZ Changed')
            ->and($fresh->category)->toBe('marketing')
            ->and((float) $fresh->amount)->toBe(77.25)
            ->and($fresh->expense_date->format('Y-m-d'))->toBe('2026-07-04')
            ->and(MyExpense::count())->toBe(1);
    });

    it('will not save a bad edit', function () {
        $expense = myExpense();
        ownerSignedIn();

        $this->put("/admin/my-expenses/{$expense->id}", expenseFormBody(['amount' => '-1']))->assertSessionHasErrors('amount');

        expect((float) $expense->fresh()->amount)->toBe(1000.0);
    });

    it('deletes it', function () {
        $expense = myExpense();
        $keep = myExpense(['title' => 'ZZZ keep']);
        ownerSignedIn();

        $this->delete("/admin/my-expenses/{$expense->id}")
            ->assertRedirect(route('admin.my-expenses.index', ['year' => 2026, 'month' => 9]))
            ->assertSessionHas('status', 'Expense "ZZZ Test Rent" was deleted.');

        expect(MyExpense::find($expense->id))->toBeNull()->and(MyExpense::find($keep->id))->not->toBeNull();
    });

    it('is 404 for an expense that is not there', function () {
        ownerSignedIn();

        $this->put('/admin/my-expenses/999', expenseFormBody())->assertNotFound();
        $this->delete('/admin/my-expenses/999')->assertNotFound();
    });

    it('takes a deleted expense out of the profit calculation', function () {
        $expense = myExpense(['amount' => 1000]);
        profitableHire(8000);
        ownerSignedIn();
        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(5400.0);

        $this->delete("/admin/my-expenses/{$expense->id}");

        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(6400.0);
    });

    it('shows the edit and delete buttons only to someone allowed them', function () {
        myExpense();
        ownerSignedIn(['my-expenses.view']);

        $this->get('/admin/my-expenses')->assertOk()
            ->assertDontSee('Add Expense')
            ->assertDontSee('modal-edit-')
            ->assertDontSee('Delete this expense?');
    });
});

it('names a category, falling back to the raw value for one that is gone', function () {
    expect(myExpense(['category' => 'insurance'])->category_label)->toBe('Insurance')
        ->and(myExpense(['category' => 'retired_one'])->category_label)->toBe('Retired One');
});
