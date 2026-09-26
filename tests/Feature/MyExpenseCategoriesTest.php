<?php

use App\Models\MyExpense;
use App\Models\MyExpenseCategory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function categoryOwner(array $permissions = ['my-expenses.view', 'my-expenses.create', 'my-expenses.update', 'my-expenses.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function filedUnder(string $key, array $attributes = []): MyExpense
{
    return MyExpense::create($attributes + ['title' => 'ZZZ expense', 'category' => $key, 'amount' => 100, 'expense_date' => '2026-09-10']);
}

function expenseWith(array $changes = []): array
{
    return $changes + ['title' => 'ZZZ Bank fee', 'category' => 'others', 'amount' => '50', 'expense_date' => '2026-09-12'];
}

function categoryNames(): array
{
    return MyExpenseCategory::query()->orderBy('name')->pluck('name')->all();
}

describe('the starting categories', function () {
    it('are the nine the page always had', function () {
        expect(MyExpenseCategory::query()->pluck('name', 'key')->all())->toBe([
            'rent' => 'Rent', 'utilities' => 'Utilities', 'office' => 'Office & Supplies', 'marketing' => 'Marketing',
            'insurance' => 'Insurance', 'taxes' => 'Taxes & Licences', 'fuel' => 'Fuel', 'personal' => 'Personal', 'others' => 'Others',
        ]);
    });

    it('still name the expenses that were filed under them before categories were editable', function () {
        expect(filedUnder('rent')->category_label)->toBe('Rent')
            ->and(filedUnder('taxes')->category_label)->toBe('Taxes & Licences');
    });

    it('fill the dropdown, the filter and the manager on the page', function () {
        categoryOwner();

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('categories')->keys()->sort()->values()->all())->toBe(['fuel', 'insurance', 'marketing', 'office', 'others', 'personal', 'rent', 'taxes', 'utilities'])
            ->and($response->viewData('categoryList'))->toHaveCount(9);
        $response->assertSee('id="manage-categories"', false)->assertSee('value="__new__"', false);
    });

    it('start a new expense under Others', function () {
        categoryOwner();

        expect($this->get('/admin/my-expenses')->viewData('defaultCategory'))->toBe('others');
    });

    it('start a new expense under the first category if Others has been deleted', function () {
        categoryOwner();
        MyExpenseCategory::where('key', 'others')->delete();

        expect($this->get('/admin/my-expenses')->viewData('defaultCategory'))->toBe('fuel'); // A to Z: Fuel first
    });
});

describe('adding a category', function () {
    it('creates it and says so', function () {
        categoryOwner();

        $this->from('/admin/my-expenses')->post('/admin/my-expense-categories', ['name' => 'Bank charges', 'form_id' => 'categories'])
            ->assertRedirect('/admin/my-expenses')
            ->assertSessionHas('status', 'Category "Bank charges" was added.');

        $category = MyExpenseCategory::where('name', 'Bank charges')->first();
        expect($category)->not->toBeNull()->and($category->key)->toBe('bank-charges');
    });

    it('shows up in the dropdown, the filter and the manager straight away', function () {
        categoryOwner();
        $this->post('/admin/my-expense-categories', ['name' => 'Bank charges']);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('categories')->get('bank-charges'))->toBe('Bank charges');
        $response->assertSee('Bank charges');
    });

    it('tidies stray spacing in the name', function () {
        categoryOwner();

        $this->post('/admin/my-expense-categories', ['name' => "  Bank    charges \n"]);

        expect(categoryNames())->toContain('Bank charges');
    });

    it('turns down a name that is empty, blank or too long', function (string $name) {
        categoryOwner();

        $this->post('/admin/my-expense-categories', ['name' => $name])->assertSessionHasErrors('name');

        expect(MyExpenseCategory::count())->toBe(9);
    })->with(['empty' => [''], 'blank' => ['    '], 'too long' => [str_repeat('a', 61)]]);

    it('takes a name of exactly the longest length', function () {
        categoryOwner();

        $this->post('/admin/my-expense-categories', ['name' => str_repeat('a', 60)])->assertSessionHasNoErrors();

        expect(MyExpenseCategory::count())->toBe(10);
    });

    it('turns down a name that already exists, whatever its case or spacing', function (string $name) {
        categoryOwner();

        $this->post('/admin/my-expense-categories', ['name' => $name])
            ->assertSessionHasErrors(['name' => 'A category with this name already exists.']);

        expect(MyExpenseCategory::count())->toBe(9);
    })->with(['same' => ['Rent'], 'lower case' => ['rent'], 'shouting' => ['RENT'], 'spaced' => ['  office   &  supplies ']]);

    it('gives each category its own key even when names slug alike', function () {
        categoryOwner();

        $this->post('/admin/my-expense-categories', ['name' => 'R D']);
        $this->post('/admin/my-expense-categories', ['name' => 'r-d']);
        $this->post('/admin/my-expense-categories', ['name' => 'R D!']);

        expect(MyExpenseCategory::whereIn('name', ['R D', 'r-d', 'R D!'])->orderBy('id')->pluck('key')->all())->toBe(['r-d', 'r-d-2', 'r-d-3']);
    });

    it('copes with a name that has no letters a slug can keep', function () {
        categoryOwner();

        $this->post('/admin/my-expense-categories', ['name' => 'பெட்ரோல்']);
        $this->post('/admin/my-expense-categories', ['name' => '燃料']);

        $keys = MyExpenseCategory::whereIn('name', ['பெட்ரோல்', '燃料'])->orderBy('id')->pluck('key')->all();
        expect($keys)->toBe(['category', 'category-2']);
    });

    it('redisplays the manager with the reason when it is turned down', function () {
        categoryOwner();

        $this->from('/admin/my-expenses')->post('/admin/my-expense-categories', ['name' => 'Rent', 'form_id' => 'categories'])
            ->assertRedirect('/admin/my-expenses')
            ->assertSessionHasInput('form_id', 'categories');
        $page = $this->followingRedirects()->from('/admin/my-expenses')->post('/admin/my-expense-categories', ['name' => 'Rent', 'form_id' => 'categories']);

        $page->assertSee('id="category-error"', false)->assertSee('A category with this name already exists.');
    });
});

describe('the category manager', function () {
    it('stays open after each change, saying what happened', function () {
        categoryOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $added = $this->from('/admin/my-expenses')->post('/admin/my-expense-categories', ['name' => 'Bank charges']);
        $renamed = $this->from('/admin/my-expenses')->put("/admin/my-expense-categories/{$category->id}", ['name' => 'Petrol']);
        $deleted = $this->from('/admin/my-expenses')->delete('/admin/my-expense-categories/'.MyExpenseCategory::where('key', 'personal')->value('id'));

        foreach ([$added, $renamed, $deleted] as $response) {
            $response->assertSessionHas('reopen_modal', 'categories');
        }
        $page = $this->followingRedirects()->from('/admin/my-expenses')->post('/admin/my-expense-categories', ['name' => 'Insurance extras']);
        $page->assertSee('var reopenId = "categories"', false)
            ->assertSee('id="category-status"', false)
            ->assertSee('Category &quot;Insurance extras&quot; was added.', false);
    });

    it('explains, inside itself, why a category could not be deleted', function () {
        categoryOwner();
        filedUnder('rent');
        $category = MyExpenseCategory::where('key', 'rent')->first();

        $page = $this->followingRedirects()->from('/admin/my-expenses')->delete("/admin/my-expense-categories/{$category->id}");

        $page->assertSee('var reopenId = "categories"', false)->assertSee('is used by 1 expense', false);
    });

    it('does not reopen by itself on an ordinary visit', function () {
        categoryOwner();

        $this->get('/admin/my-expenses')->assertOk()->assertSee('var reopenId = null', false);
    });
});

describe('adding one from the expense form', function () {
    it('creates the category and files the expense under it', function () {
        categoryOwner();

        $this->post('/admin/my-expenses', expenseWith(['category' => '__new__', 'new_category' => 'Bank charges']))
            ->assertSessionHasNoErrors();

        $expense = MyExpense::first();
        expect($expense->category)->toBe('bank-charges')
            ->and($expense->category_label)->toBe('Bank charges')
            ->and(MyExpenseCategory::where('key', 'bank-charges')->count())->toBe(1);
    });

    it('reuses a category that already has that name instead of making a twin', function () {
        categoryOwner();

        $this->post('/admin/my-expenses', expenseWith(['category' => '__new__', 'new_category' => '  fuel ']));

        expect(MyExpense::first()->category)->toBe('fuel')->and(MyExpenseCategory::count())->toBe(9);
    });

    it('asks for the name when the box was left empty', function (?string $name) {
        categoryOwner();

        $this->post('/admin/my-expenses', expenseWith(['category' => '__new__', 'new_category' => $name]))
            ->assertSessionHasErrors(['new_category' => 'Type a name for the new category.']);

        expect(MyExpense::count())->toBe(0)->and(MyExpenseCategory::count())->toBe(9);
    })->with(['missing' => [null], 'empty' => [''], 'blank' => ['   ']]);

    it('turns down a name that is too long, saving neither the expense nor the category', function () {
        categoryOwner();

        $this->post('/admin/my-expenses', expenseWith(['category' => '__new__', 'new_category' => str_repeat('a', 61)]))
            ->assertSessionHasErrors('new_category');

        expect(MyExpense::count())->toBe(0)->and(MyExpenseCategory::count())->toBe(9);
    });

    it('creates no category when the rest of the expense is invalid', function () {
        categoryOwner();

        $this->post('/admin/my-expenses', expenseWith(['category' => '__new__', 'new_category' => 'Bank charges', 'amount' => '0']))
            ->assertSessionHasErrors('amount');

        expect(MyExpenseCategory::where('name', 'Bank charges')->exists())->toBeFalse();
    });

    it('works when editing an expense too', function () {
        $expense = filedUnder('rent');
        categoryOwner();

        $this->put("/admin/my-expenses/{$expense->id}", expenseWith(['category' => '__new__', 'new_category' => 'Bank charges']))
            ->assertSessionHasNoErrors();

        expect($expense->fresh()->category)->toBe('bank-charges');
    });

    it('is only offered to someone who may create things', function () {
        categoryOwner(['my-expenses.view', 'my-expenses.update']);

        $this->get('/admin/my-expenses')->assertOk()->assertDontSee('value="__new__"', false);
    });

    it('turns down a category that does not exist', function () {
        categoryOwner();

        $this->post('/admin/my-expenses', expenseWith(['category' => 'yachts']))->assertSessionHasErrors('category');

        expect(MyExpense::count())->toBe(0);
    });

    it('accepts an expense in a category made earlier', function () {
        categoryOwner();
        $this->post('/admin/my-expense-categories', ['name' => 'Bank charges']);

        $this->post('/admin/my-expenses', expenseWith(['category' => 'bank-charges']))->assertSessionHasNoErrors();

        expect(MyExpense::first()->category_label)->toBe('Bank charges');
    });
});

describe('a custom category in use', function () {
    it('can be filtered on', function () {
        categoryOwner();
        $this->post('/admin/my-expense-categories', ['name' => 'Bank charges']);
        filedUnder('bank-charges', ['title' => 'ZZZ fee']);
        filedUnder('rent', ['title' => 'ZZZ rent']);

        $response = $this->get('/admin/my-expenses?category=bank-charges')->assertOk();

        expect($response->viewData('expenses')->pluck('title')->all())->toBe(['ZZZ fee']);
    });

    it('is named in the month\'s breakdown', function () {
        categoryOwner();
        $this->post('/admin/my-expense-categories', ['name' => 'Bank charges']);
        filedUnder('bank-charges', ['amount' => 75]);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('byCategory')->all())->toBe(['bank-charges' => 75.0]);
        $response->assertSeeInOrder(['my-expenses-by-category', 'Bank charges', 'Rs. 75.00']);
    });

    it('counts its expenses in the manager', function () {
        categoryOwner();
        filedUnder('rent');
        filedUnder('rent', ['expense_date' => '2026-01-05']);

        $counts = $this->get('/admin/my-expenses')->viewData('categoryList')->pluck('expenses_count', 'key');

        expect($counts['rent'])->toBe(2)->and($counts['fuel'])->toBe(0);
    });
});

describe('renaming a category', function () {
    it('changes the name and nothing else', function () {
        categoryOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->from('/admin/my-expenses')->put("/admin/my-expense-categories/{$category->id}", ['name' => 'Petrol'])
            ->assertRedirect('/admin/my-expenses')
            ->assertSessionHas('status', 'Category renamed to "Petrol".');

        expect($category->fresh()->name)->toBe('Petrol')->and($category->fresh()->key)->toBe('fuel');
    });

    it('is followed by every expense filed under it', function () {
        categoryOwner();
        $expense = filedUnder('fuel');
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->put("/admin/my-expense-categories/{$category->id}", ['name' => 'Petrol']);

        expect($expense->fresh()->category_label)->toBe('Petrol')->and($expense->fresh()->category)->toBe('fuel');
        $this->get('/admin/my-expenses')->assertSee('Petrol');
    });

    it('lets a category keep its own name, or change only its case', function () {
        categoryOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->put("/admin/my-expense-categories/{$category->id}", ['name' => 'Fuel'])->assertSessionHasNoErrors();
        $this->put("/admin/my-expense-categories/{$category->id}", ['name' => 'FUEL'])->assertSessionHasNoErrors();

        expect($category->fresh()->name)->toBe('FUEL');
    });

    it('will not take another category\'s name', function () {
        categoryOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->put("/admin/my-expense-categories/{$category->id}", ['name' => 'rent'])
            ->assertSessionHasErrors(['name' => 'A category with this name already exists.']);

        expect($category->fresh()->name)->toBe('Fuel');
    });

    it('will not take an empty name', function () {
        categoryOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->put("/admin/my-expense-categories/{$category->id}", ['name' => '  '])->assertSessionHasErrors('name');

        expect($category->fresh()->name)->toBe('Fuel');
    });

    it('is 404 for a category that is not there', function () {
        categoryOwner();

        $this->put('/admin/my-expense-categories/999', ['name' => 'X'])->assertNotFound();
    });
});

describe('deleting a category', function () {
    it('removes one nothing is filed under', function () {
        categoryOwner();
        $category = MyExpenseCategory::where('key', 'fuel')->first();

        $this->from('/admin/my-expenses')->delete("/admin/my-expense-categories/{$category->id}")
            ->assertRedirect('/admin/my-expenses')
            ->assertSessionHas('status', 'Category "Fuel" was deleted.');

        expect(MyExpenseCategory::where('key', 'fuel')->exists())->toBeFalse();
    });

    it('refuses while any expense is filed under it, saying how many', function () {
        categoryOwner();
        filedUnder('rent');
        filedUnder('rent', ['expense_date' => '2026-01-05']);
        $category = MyExpenseCategory::where('key', 'rent')->first();

        $this->from('/admin/my-expenses')->delete("/admin/my-expense-categories/{$category->id}")
            ->assertRedirect('/admin/my-expenses')
            ->assertSessionHas('error', '"Rent" is used by 2 expenses — move or delete them first.');

        expect(MyExpenseCategory::where('key', 'rent')->exists())->toBeTrue()->and(MyExpense::count())->toBe(2);
    });

    it('says "expense", not "expenses", for one', function () {
        categoryOwner();
        filedUnder('rent');
        $category = MyExpenseCategory::where('key', 'rent')->first();

        $this->delete("/admin/my-expense-categories/{$category->id}")
            ->assertSessionHas('error', '"Rent" is used by 1 expense — move or delete them first.');
    });

    it('can go once its expenses have been moved away', function () {
        categoryOwner();
        $expense = filedUnder('rent');
        $category = MyExpenseCategory::where('key', 'rent')->first();
        $expense->update(['category' => 'others']);

        $this->delete("/admin/my-expense-categories/{$category->id}")->assertSessionHas('status');

        expect(MyExpenseCategory::where('key', 'rent')->exists())->toBeFalse();
    });

    it('leaves an expense with a readable label if its category is removed behind the app\'s back', function () {
        categoryOwner();
        $expense = filedUnder('rent');
        DB::table('my_expense_categories')->where('key', 'rent')->delete();

        expect($expense->fresh()->category_label)->toBe('Rent');
        $this->get('/admin/my-expenses')->assertOk()->assertSee('ZZZ expense');
    });

    it('is 404 for a category that is not there', function () {
        categoryOwner();

        $this->delete('/admin/my-expense-categories/999')->assertNotFound();
    });
});

describe('who may manage categories', function () {
    it('needs the matching permission for each action', function () {
        $category = MyExpenseCategory::where('key', 'fuel')->first();
        categoryOwner(['my-expenses.view']);

        $this->post('/admin/my-expense-categories', ['name' => 'Bank charges'])->assertForbidden();
        $this->put("/admin/my-expense-categories/{$category->id}", ['name' => 'Petrol'])->assertForbidden();
        $this->delete("/admin/my-expense-categories/{$category->id}")->assertForbidden();

        expect(categoryNames())->toContain('Fuel')->not->toContain('Bank charges');
    });

    it('is allowed one action without the others', function () {
        $category = MyExpenseCategory::where('key', 'fuel')->first();
        categoryOwner(['my-expenses.view', 'my-expenses.update']);

        $this->put("/admin/my-expense-categories/{$category->id}", ['name' => 'Petrol'])->assertSessionHasNoErrors();
        $this->post('/admin/my-expense-categories', ['name' => 'Bank charges'])->assertForbidden();
        $this->delete("/admin/my-expense-categories/{$category->id}")->assertForbidden();
    });

    it('sends a guest to the login page', function () {
        $this->post('/admin/my-expense-categories', ['name' => 'X'])->assertRedirect('/login');
    });

    it('hides the Categories button from someone who can only look', function () {
        categoryOwner(['my-expenses.view']);

        $this->get('/admin/my-expenses')->assertOk()->assertDontSee('id="manage-categories"', false)->assertDontSee('id="modal-categories"', false);
    });

    it('shows only the controls a user may use inside the manager', function () {
        categoryOwner(['my-expenses.view', 'my-expenses.update']);

        $html = $this->get('/admin/my-expenses')->assertOk()->getContent();

        expect($html)->toContain('id="modal-categories"')
            ->and($html)->not->toContain('id="form-add-category"')
            ->and($html)->toContain('title="Save name"')
            ->and($html)->not->toContain('title="Delete category"');
    });

    it('disables delete for a category in use', function () {
        categoryOwner();
        filedUnder('rent');

        $html = $this->get('/admin/my-expenses')->assertOk()->getContent();

        expect($html)->toContain('In use — move or delete its expenses first');
    });
});

describe('the migration', function () {
    it('gives an expense whose key is not one of the defaults a category of its own', function () {
        // Undo the migration, leave an expense behind with a key nobody defined, then run it again.
        Artisan::call('migrate:rollback', ['--path' => 'database/migrations/2026_09_26_110000_create_my_expense_categories_table.php', '--realpath' => false]);
        expect(Schema::hasTable('my_expense_categories'))->toBeFalse();
        DB::table('my_expenses')->insert(['title' => 'ZZZ old', 'category' => 'bank_fees', 'amount' => 10, 'expense_date' => '2026-09-01', 'created_at' => now(), 'updated_at' => now()]);

        Artisan::call('migrate', ['--path' => 'database/migrations/2026_09_26_110000_create_my_expense_categories_table.php']);

        expect(MyExpenseCategory::where('key', 'bank_fees')->value('name'))->toBe('Bank Fees')
            ->and(MyExpenseCategory::count())->toBe(10)
            ->and(MyExpense::first()->category_label)->toBe('Bank Fees');
    });
});
