<?php

use App\Models\Hire;
use App\Models\MyExpense;
use App\Models\OtherCompanyRevenue;
use App\Models\User;
use App\Services\MyExpenseReport;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    // Wednesday midday, mid-September — "this month" below is September 2026.
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function revenueOwner(array $permissions = ['my-expenses.view', 'my-expenses.create', 'my-expenses.update', 'my-expenses.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function otherCompanyRevenue(array $attributes = []): OtherCompanyRevenue
{
    return OtherCompanyRevenue::create($attributes + [
        'hire' => 'ZZZ Colombo to Kandy', 'booking_number' => 'ZZZ-BK-001', 'vehicle' => 'ZZZ Toyota Aqua',
        'full_amount' => 10000, 'credited_amount' => 7000, 'balance' => 3000, 'vehicle_amount' => 6000,
        'revenue_date' => '2026-09-10',
    ]);
}

function revenueHire(float $our = 8000, string $start = '2026-09-05 09:00:00'): Hire
{
    return Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => $our + 2000, 'our_hire_value' => $our,
        'payment_type' => 'cash', 'start_time' => $start,
    ]);
}

function revenueBody(array $changes = []): array
{
    return $changes + [
        'hire' => 'ZZZ Galle Fort Tour', 'booking_number' => 'ZZZ-BK-999', 'vehicle' => 'ZZZ Hiace — ABC-1234',
        'full_amount' => '15000', 'credited_amount' => '9000', 'balance' => '6000', 'vehicle_amount' => '5000',
        'revenue_date' => '2026-09-12',
    ];
}

describe('access', function () {
    it('is forbidden to add, edit or delete without the matching permission', function () {
        $revenue = otherCompanyRevenue();
        revenueOwner(['my-expenses.view']);

        $this->post('/admin/other-company-revenues', revenueBody())->assertForbidden();
        $this->put("/admin/other-company-revenues/{$revenue->id}", revenueBody())->assertForbidden();
        $this->delete("/admin/other-company-revenues/{$revenue->id}")->assertForbidden();

        expect(OtherCompanyRevenue::count())->toBe(1)->and($revenue->fresh()->hire)->toBe('ZZZ Colombo to Kandy');
    });

    it('lets one action through without the others', function () {
        $revenue = otherCompanyRevenue();
        revenueOwner(['my-expenses.view', 'my-expenses.update']);

        $this->put("/admin/other-company-revenues/{$revenue->id}", revenueBody(['hire' => 'ZZZ Renamed']))->assertRedirect();
        $this->post('/admin/other-company-revenues', revenueBody())->assertForbidden();
        $this->delete("/admin/other-company-revenues/{$revenue->id}")->assertForbidden();

        expect($revenue->fresh()->hire)->toBe('ZZZ Renamed');
    });

    it('sends a guest to the login page', function () {
        $this->post('/admin/other-company-revenues', revenueBody())->assertRedirect('/login');
    });

    it('does not show the buttons to someone who can only look', function () {
        otherCompanyRevenue();
        revenueOwner(['my-expenses.view']);

        $this->get('/admin/my-expenses?tab=revenue')->assertOk()
            ->assertDontSee('id="add-revenue"', false)
            ->assertDontSee('modal-revenue-edit-')
            ->assertDontSee('Delete this revenue entry?');
    });
});

describe('the tabs', function () {
    it('show the revenue list on the Revenues from Other Companies tab', function () {
        revenueOwner();
        otherCompanyRevenue(['hire' => 'ZZZ Colombo to Kandy']);

        $response = $this->get('/admin/my-expenses?tab=revenue')->assertOk();

        expect($response->viewData('tab'))->toBe('revenue')->and($response->viewData('expenses'))->toBeNull()->and($response->viewData('incomes'))->toBeNull();
        $response->assertSee('id="my-revenue-table"', false)->assertDontSee('id="my-expenses-table"', false)->assertSee('ZZZ Colombo to Kandy');
    });

    it('treats an unknown tab as Expenses, leaving revenue out', function () {
        revenueOwner();

        expect($this->get('/admin/my-expenses?tab=whatever')->viewData('tab'))->toBe('expenses');
    });

    it('carries the record count and keeps the month when switching', function () {
        revenueOwner();
        otherCompanyRevenue();
        otherCompanyRevenue(['booking_number' => 'ZZZ-BK-002']);

        $html = $this->get('/admin/my-expenses?year=2026&month=8')->assertOk()->getContent();

        expect($html)->toContain('id="tab-revenue"')
            ->and($html)->toContain(e(route('admin.my-expenses.index', ['tab' => 'revenue', 'year' => 2026, 'month' => 8])));

        $this->get('/admin/my-expenses')->assertSeeInOrder(['id="tab-revenue"', '2</span>']);
    });
});

describe('the revenue list', function () {
    it('shows this month\'s revenue newest first, leaving other months out', function () {
        revenueOwner();
        otherCompanyRevenue(['hire' => 'ZZZ early', 'revenue_date' => '2026-09-01']);
        otherCompanyRevenue(['hire' => 'ZZZ late', 'revenue_date' => '2026-09-30']);
        otherCompanyRevenue(['hire' => 'ZZZ august', 'revenue_date' => '2026-08-31']);

        $response = $this->get('/admin/my-expenses?tab=revenue')->assertOk();

        expect($response->viewData('revenues')->pluck('hire')->all())->toBe(['ZZZ late', 'ZZZ early']);
    });

    it('searches the hire, booking number and vehicle, and says what the credited total comes to', function () {
        revenueOwner();
        otherCompanyRevenue(['hire' => 'ZZZ Colombo to Kandy', 'booking_number' => 'ZZZ-BK-001', 'vehicle' => 'ZZZ Aqua', 'credited_amount' => 1000]);
        otherCompanyRevenue(['hire' => 'ZZZ Galle Tour', 'booking_number' => 'ZZZ-BK-002', 'vehicle' => 'ZZZ Hiace', 'credited_amount' => 2000]);
        otherCompanyRevenue(['hire' => 'ZZZ Ella Trip', 'booking_number' => 'BOOK-003', 'vehicle' => 'ZZZ Prius', 'credited_amount' => 500]);

        $byBookingNumber = $this->get('/admin/my-expenses?tab=revenue&search=BK-00')->assertOk();

        expect($byBookingNumber->viewData('revenues')->pluck('hire')->sort()->values()->all())->toBe(['ZZZ Colombo to Kandy', 'ZZZ Galle Tour'])
            ->and($byBookingNumber->viewData('filteredRevenueTotal'))->toBe(3000.0);
        $byBookingNumber->assertSee('id="filtered-revenue-total"', false);
    });

    it('says so when the month has none', function () {
        revenueOwner();

        $this->get('/admin/my-expenses?tab=revenue')->assertOk()->assertSee('No revenue from other companies recorded for September 2026.');
    });

    it('pages a long month', function () {
        revenueOwner();
        foreach (range(1, 20) as $n) {
            otherCompanyRevenue(['booking_number' => "ZZZ-BK-{$n}"]);
        }

        $first = $this->get('/admin/my-expenses?tab=revenue')->viewData('revenues');
        $second = $this->get('/admin/my-expenses?tab=revenue&page=2')->viewData('revenues');

        expect($first->count())->toBe(15)->and($first->total())->toBe(20)->and($second->count())->toBe(5);
    });
});

describe('my profit', function () {
    it('adds the credited amount to the profit from hires, ignoring the full amount', function () {
        revenueOwner();
        revenueHire(8000); // profit 6,400
        otherCompanyRevenue(['full_amount' => 10000, 'credited_amount' => 6000]);

        $response = $this->get('/admin/my-expenses')->assertOk();

        expect($response->viewData('otherCompanyRevenueTotal'))->toBe(6000.0)
            ->and($response->viewData('myProfit'))->toBe(12400.0); // 6,400 + 6,000
        $response->assertSee('id="card-other-company-revenue"', false)->assertSeeInOrder(['Other Company Revenue', 'Rs. 6,000.00', '1 entry']);
    });

    it('adds on top of other income, not instead of it', function () {
        revenueOwner();
        revenueHire(8000);
        otherCompanyRevenue(['credited_amount' => 2000]);

        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(8400.0); // 6,400 + 2,000

        \App\Models\OtherIncome::create(['title' => 'ZZZ Shop rent', 'amount' => 1000, 'income_date' => '2026-09-10']);

        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(9400.0); // 6,400 + 1,000 + 2,000
    });

    it('counts only the viewed month\'s revenue against that month', function () {
        revenueOwner();
        revenueHire(8000);
        revenueHire(4000, '2026-08-10 09:00:00'); // August profit 3,200
        otherCompanyRevenue(['credited_amount' => 1000, 'revenue_date' => '2026-09-05']);
        otherCompanyRevenue(['credited_amount' => 700, 'revenue_date' => '2026-08-05']);

        expect($this->get('/admin/my-expenses?year=2026&month=9')->viewData('myProfit'))->toBe(7400.0)
            ->and($this->get('/admin/my-expenses?year=2026&month=8')->viewData('myProfit'))->toBe(3900.0);
    });

    it('is not added to the dashboard\'s Total Profit, which stays the profit from hires', function () {
        revenueOwner(['my-expenses.view']);
        revenueHire(8000);
        otherCompanyRevenue(['credited_amount' => 5000]);

        expect($this->get('/admin')->viewData('summary')['profit_total'])->toBe(6400.0);
    });

    it('is explained line by line in the breakdown', function () {
        revenueOwner();
        revenueHire(8000);
        otherCompanyRevenue(['credited_amount' => 2000, 'revenue_date' => '2026-09-08']);

        $this->get('/admin/my-expenses')->assertOk()
            ->assertSee('Add: Other Company Revenue (1 entry)')
            ->assertSee('+Rs. 2,000.00')
            ->assertSeeInOrder(['Profit From Hires (Rs. 6,400.00)', '+ Other Income (Rs. 0.00)', '+ Other Company Revenue (Rs. 2,000.00)', '= Rs. 8,400.00.']);
    });

    it('is worked out by the shared month report', function () {
        revenueHire(8000);
        otherCompanyRevenue(['credited_amount' => 2000]);

        $report = MyExpenseReport::forMonth(2026, 9);

        expect($report['other_company_revenue_total'])->toBe(2000.0)->and($report['other_company_revenue_count'])->toBe(1)
            ->and($report['my_profit'])->toBe(8400.0);
    });

    it('offers the years that only have other company revenue', function () {
        revenueOwner();
        otherCompanyRevenue(['revenue_date' => '2023-04-01']);

        expect($this->get('/admin/my-expenses')->viewData('availableYears'))->toContain(2023);
    });
});

describe('adding revenue', function () {
    it('saves every field and lands on that month\'s revenue tab', function () {
        revenueOwner();

        $this->post('/admin/other-company-revenues', revenueBody(['revenue_date' => '2026-08-20']))
            ->assertRedirect(route('admin.my-expenses.index', ['tab' => 'revenue', 'year' => 2026, 'month' => 8]))
            ->assertSessionHas('status', 'Revenue "ZZZ Galle Fort Tour" was added.');

        $revenue = OtherCompanyRevenue::first();
        expect($revenue->hire)->toBe('ZZZ Galle Fort Tour')
            ->and($revenue->booking_number)->toBe('ZZZ-BK-999')
            ->and($revenue->vehicle)->toBe('ZZZ Hiace — ABC-1234')
            ->and((float) $revenue->full_amount)->toBe(15000.0)
            ->and((float) $revenue->credited_amount)->toBe(9000.0)
            ->and((float) $revenue->balance)->toBe(6000.0)
            ->and((float) $revenue->vehicle_amount)->toBe(5000.0)
            ->and($revenue->revenue_date->format('Y-m-d'))->toBe('2026-08-20');
    });

    it('accepts a balance independent of full and credited amounts', function () {
        revenueOwner();

        $this->post('/admin/other-company-revenues', revenueBody(['full_amount' => '1000', 'credited_amount' => '1000', 'balance' => '500']))
            ->assertRedirect();

        expect((float) OtherCompanyRevenue::first()->balance)->toBe(500.0);
    });

    it('allows a negative balance, for an overpayment', function () {
        revenueOwner();

        $this->post('/admin/other-company-revenues', revenueBody(['balance' => '-250.50']))->assertRedirect();

        expect((float) OtherCompanyRevenue::first()->balance)->toBe(-250.5);
    });

    it('turns down bad input, saying why and saving nothing', function (array $changes, string $field) {
        revenueOwner();

        $this->post('/admin/other-company-revenues', revenueBody($changes))->assertSessionHasErrors($field);

        expect(OtherCompanyRevenue::count())->toBe(0);
    })->with([
        'no hire' => [['hire' => ''], 'hire'],
        'no booking number' => [['booking_number' => ''], 'booking_number'],
        'no vehicle' => [['vehicle' => ''], 'vehicle'],
        'no full amount' => [['full_amount' => ''], 'full_amount'],
        'negative full amount' => [['full_amount' => '-5'], 'full_amount'],
        'no credited amount' => [['credited_amount' => ''], 'credited_amount'],
        'negative credited amount' => [['credited_amount' => '-5'], 'credited_amount'],
        'no balance' => [['balance' => ''], 'balance'],
        'no vehicle amount' => [['vehicle_amount' => ''], 'vehicle_amount'],
        'negative vehicle amount' => [['vehicle_amount' => '-5'], 'vehicle_amount'],
        'no date' => [['revenue_date' => ''], 'revenue_date'],
        'date not a date' => [['revenue_date' => 'someday'], 'revenue_date'],
    ]);

    it('is reflected in My Profit straight away', function () {
        revenueOwner();
        revenueHire(8000);

        $this->post('/admin/other-company-revenues', revenueBody(['credited_amount' => '1000', 'revenue_date' => '2026-09-12']));

        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(7400.0);
    });
});

describe('editing and deleting revenue', function () {
    it('changes it and returns to its month', function () {
        $revenue = otherCompanyRevenue();
        revenueOwner();

        $this->put("/admin/other-company-revenues/{$revenue->id}", revenueBody(['hire' => 'ZZZ Changed', 'credited_amount' => '77.25', 'revenue_date' => '2026-07-04']))
            ->assertRedirect(route('admin.my-expenses.index', ['tab' => 'revenue', 'year' => 2026, 'month' => 7]))
            ->assertSessionHas('status', 'Revenue "ZZZ Changed" was updated.');

        $fresh = $revenue->fresh();
        expect($fresh->hire)->toBe('ZZZ Changed')->and((float) $fresh->credited_amount)->toBe(77.25)
            ->and($fresh->revenue_date->format('Y-m-d'))->toBe('2026-07-04')->and(OtherCompanyRevenue::count())->toBe(1);
    });

    it('will not save a bad edit', function () {
        $revenue = otherCompanyRevenue();
        revenueOwner();

        $this->put("/admin/other-company-revenues/{$revenue->id}", revenueBody(['full_amount' => '-1']))->assertSessionHasErrors('full_amount');

        expect((float) $revenue->fresh()->full_amount)->toBe(10000.0);
    });

    it('deletes it, and only it', function () {
        $revenue = otherCompanyRevenue();
        $keep = otherCompanyRevenue(['hire' => 'ZZZ keep']);
        revenueOwner();

        $this->delete("/admin/other-company-revenues/{$revenue->id}")
            ->assertRedirect(route('admin.my-expenses.index', ['tab' => 'revenue', 'year' => 2026, 'month' => 9]))
            ->assertSessionHas('status', 'Revenue "ZZZ Colombo to Kandy" was deleted.');

        expect(OtherCompanyRevenue::find($revenue->id))->toBeNull()->and(OtherCompanyRevenue::find($keep->id))->not->toBeNull();
    });

    it('is 404 for revenue that is not there', function () {
        revenueOwner();

        $this->put('/admin/other-company-revenues/999', revenueBody())->assertNotFound();
        $this->delete('/admin/other-company-revenues/999')->assertNotFound();
    });

    it('takes deleted revenue out of My Profit', function () {
        $revenue = otherCompanyRevenue(['credited_amount' => 1000]);
        revenueHire(8000);
        revenueOwner();
        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(7400.0);

        $this->delete("/admin/other-company-revenues/{$revenue->id}");

        expect($this->get('/admin/my-expenses')->viewData('myProfit'))->toBe(6400.0);
    });

    it('gives each row an edit form filled in with its details', function () {
        $revenue = otherCompanyRevenue(['hire' => 'ZZZ Colombo to Kandy', 'booking_number' => 'ZZZ-BK-777', 'full_amount' => 1234.5, 'revenue_date' => '2026-09-03']);
        revenueOwner();

        $this->get('/admin/my-expenses?tab=revenue')->assertOk()
            ->assertSee("modal-revenue-edit-{$revenue->id}", false)
            ->assertSee('value="ZZZ Colombo to Kandy"', false)
            ->assertSee('value="ZZZ-BK-777"', false)
            ->assertSee('value="1234.50"', false)
            ->assertSee('value="2026-09-03"', false);
    });
});

describe('the bank slip', function () {
    it('stores an uploaded slip and shows a View current slip link when editing', function () {
        Storage::fake('public');
        revenueOwner();

        $this->post('/admin/other-company-revenues', revenueBody() + [
            'slip' => UploadedFile::fake()->image('slip.jpg'),
        ])->assertRedirect();

        $revenue = OtherCompanyRevenue::first();
        Storage::disk('public')->assertExists($revenue->slip_path);

        $this->get('/admin/my-expenses?tab=revenue')->assertOk()
            ->assertSee('View current slip')
            ->assertSee($revenue->slip_url, false);

        $this->get($revenue->slip_url)->assertOk()->assertHeader('Content-Type', 'image/jpeg');
    });

    it('replaces the old slip file when a new one is uploaded on update, and deletes it with the record', function () {
        Storage::fake('public');
        revenueOwner();
        $this->post('/admin/other-company-revenues', revenueBody() + [
            'slip' => UploadedFile::fake()->image('first.jpg'),
        ]);
        $revenue = OtherCompanyRevenue::first();
        $oldPath = $revenue->slip_path;

        $this->put("/admin/other-company-revenues/{$revenue->id}", revenueBody() + [
            'slip' => UploadedFile::fake()->image('second.jpg'),
        ])->assertRedirect();

        Storage::disk('public')->assertMissing($oldPath);
        $newPath = $revenue->fresh()->slip_path;
        Storage::disk('public')->assertExists($newPath);
        expect($newPath)->not->toBe($oldPath);

        $this->delete("/admin/other-company-revenues/{$revenue->id}");
        Storage::disk('public')->assertMissing($newPath);
    });

    it('keeps the existing slip when an edit does not send a new one', function () {
        Storage::fake('public');
        revenueOwner();
        $this->post('/admin/other-company-revenues', revenueBody() + [
            'slip' => UploadedFile::fake()->image('slip.jpg'),
        ]);
        $revenue = OtherCompanyRevenue::first();
        $originalPath = $revenue->slip_path;

        $this->put("/admin/other-company-revenues/{$revenue->id}", revenueBody(['hire' => 'ZZZ No New Slip']))->assertRedirect();

        expect($revenue->fresh()->slip_path)->toBe($originalPath);
    });

    it('is optional — adding revenue without one works as before', function () {
        revenueOwner();

        $this->post('/admin/other-company-revenues', revenueBody())->assertRedirect();

        expect(OtherCompanyRevenue::first()->slip_path)->toBeNull();
    });

    it('rejects a non-image file', function () {
        Storage::fake('public');
        revenueOwner();

        $this->post('/admin/other-company-revenues', revenueBody() + [
            'slip' => UploadedFile::fake()->create('notes.txt', 10),
        ])->assertSessionHasErrors('slip');
    });
});

describe('the expenses and income sides are untouched', function () {
    it('still totals, filters and lists expenses exactly as before', function () {
        revenueOwner();
        myExpense(['title' => 'ZZZ rent', 'category' => 'rent', 'amount' => 1000]);
        myExpense(['title' => 'ZZZ ads', 'category' => 'marketing', 'amount' => 500]);
        otherCompanyRevenue(['credited_amount' => 9999]);

        $response = $this->get('/admin/my-expenses?category=marketing')->assertOk();

        expect($response->viewData('expenses')->pluck('title')->all())->toBe(['ZZZ ads'])
            ->and($response->viewData('total'))->toBe(1500.0)
            ->and($response->viewData('filteredTotal'))->toBe(500.0);
        expect(MyExpense::count())->toBe(2);
    });
});
