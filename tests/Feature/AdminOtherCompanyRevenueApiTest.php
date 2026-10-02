<?php

use App\Models\Hire;
use App\Models\MyExpense;
use App\Models\OtherCompanyRevenue;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->travelTo(Carbon::parse('2026-09-16 12:00:00'));
});

function revenueApiOwner(array $permissions = ['my-expenses.view', 'my-expenses.create', 'my-expenses.update', 'my-expenses.delete']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    Sanctum::actingAs($user);

    return $user;
}

function apiRevenue(array $attributes = []): OtherCompanyRevenue
{
    return OtherCompanyRevenue::create($attributes + [
        'hire' => 'ZZZ Colombo to Kandy', 'booking_number' => 'ZZZ-BK-001', 'vehicle' => 'ZZZ Toyota Aqua',
        // Non-whole amounts throughout this file — a whole number round-trips
        // through JSON as an int, which trips up a strict assertJsonPath() match
        // against a PHP float literal.
        'full_amount' => 10000.50, 'credited_amount' => 7000.25, 'balance' => 3000.75, 'vehicle_amount' => 6000.10,
        'revenue_date' => '2026-09-10',
    ]);
}

function apiRevenueHire(float $our = 8000, string $start = '2026-09-05 09:00:00'): Hire
{
    return Hire::create([
        'tour_type' => 'drop_pickup', 'hire_full_value' => $our + 2000, 'our_hire_value' => $our,
        'payment_type' => 'cash', 'start_time' => $start,
    ]);
}

function apiRevenueBody(array $changes = []): array
{
    return $changes + [
        'hire' => 'ZZZ Galle Fort Tour', 'booking_number' => 'ZZZ-BK-999', 'vehicle' => 'ZZZ Hiace — ABC-1234',
        'full_amount' => '15000.50', 'credited_amount' => '9000.25', 'balance' => '6000.75', 'vehicle_amount' => '5000.10',
        'revenue_date' => '2026-09-12',
    ];
}

describe('access', function () {
    it('needs a signed-in user', function () {
        $this->getJson('/api/admin/other-company-revenues')->assertUnauthorized();
        $this->postJson('/api/admin/other-company-revenues', [])->assertUnauthorized();
    });

    it('needs my-expenses.view to see the revenue', function () {
        revenueApiOwner(['hires.view']);

        $this->getJson('/api/admin/other-company-revenues')->assertForbidden();
    });

    it('lets view alone read but not write', function () {
        $revenue = apiRevenue();
        revenueApiOwner(['my-expenses.view']);

        $this->getJson('/api/admin/other-company-revenues')->assertOk();
        $this->postJson('/api/admin/other-company-revenues', apiRevenueBody())->assertForbidden();
        $this->putJson("/api/admin/other-company-revenues/{$revenue->id}", apiRevenueBody())->assertForbidden();
        $this->deleteJson("/api/admin/other-company-revenues/{$revenue->id}")->assertForbidden();

        expect(OtherCompanyRevenue::count())->toBe(1)->and($revenue->fresh()->hire)->toBe('ZZZ Colombo to Kandy');
    });

    it('lets each write through only with its own permission', function () {
        $revenue = apiRevenue();
        revenueApiOwner(['my-expenses.view', 'my-expenses.update']);

        $this->putJson("/api/admin/other-company-revenues/{$revenue->id}", apiRevenueBody(['hire' => 'ZZZ Renamed']))->assertOk();
        $this->postJson('/api/admin/other-company-revenues', apiRevenueBody())->assertForbidden();
        $this->deleteJson("/api/admin/other-company-revenues/{$revenue->id}")->assertForbidden();
    });
});

describe('a month of revenue', function () {
    it('opens on the current month, newest first, leaving other months out', function () {
        revenueApiOwner();
        apiRevenue(['hire' => 'ZZZ early', 'revenue_date' => '2026-09-01']);
        apiRevenue(['hire' => 'ZZZ late', 'revenue_date' => '2026-09-30']);
        apiRevenue(['hire' => 'ZZZ august', 'revenue_date' => '2026-08-31']);

        $response = $this->getJson('/api/admin/other-company-revenues')->assertOk();

        expect(collect($response->json('data'))->pluck('hire')->all())->toBe(['ZZZ late', 'ZZZ early']);
        $response->assertJsonPath('summary.label', 'September 2026');
    });

    it('describes each entry', function () {
        revenueApiOwner();
        apiRevenue();

        $this->getJson('/api/admin/other-company-revenues')->assertOk()->assertJsonPath('data.0', [
            'id' => OtherCompanyRevenue::first()->id,
            'hire' => 'ZZZ Colombo to Kandy', 'booking_number' => 'ZZZ-BK-001', 'vehicle' => 'ZZZ Toyota Aqua',
            'full_amount' => 10000.5, 'credited_amount' => 7000.25, 'balance' => 3000.75, 'vehicle_amount' => 6000.1,
            'revenue_date' => '2026-09-10', 'slip_url' => null,
        ]);
    });

    it('searches the hire, booking number and vehicle', function () {
        revenueApiOwner();
        apiRevenue(['hire' => 'ZZZ Nuwara Eliya Trip', 'booking_number' => 'ZZZ-AAA']);
        apiRevenue(['hire' => 'ZZZ Jaffna Run', 'booking_number' => 'ZZZ-BBB', 'vehicle' => 'ZZZ Nuwara Van']);
        apiRevenue(['hire' => 'ZZZ Galle Loop', 'booking_number' => 'ZZZ-CCC']);

        $response = $this->getJson('/api/admin/other-company-revenues?search=Nuwara')->assertOk();

        expect(collect($response->json('data'))->pluck('hire')->sort()->values()->all())
            ->toBe(['ZZZ Jaffna Run', 'ZZZ Nuwara Eliya Trip']);
    });

    it('filters the total by the credited amount, not the full amount', function () {
        revenueApiOwner();
        apiRevenue(['full_amount' => 10000, 'credited_amount' => 4000]);
        apiRevenue(['full_amount' => 5000, 'credited_amount' => 2000]);

        $this->getJson('/api/admin/other-company-revenues')->assertJsonPath('filtered_total', 6000);
    });

    it('carries the same summary as the expenses list, so the cards stay right whichever tab is open', function () {
        revenueApiOwner();
        apiRevenueHire(8000);
        apiRevenue(['credited_amount' => 1500]);
        MyExpense::create(['title' => 'ZZZ Rent', 'category' => 'rent', 'amount' => 1000, 'expense_date' => '2026-09-10']);

        $fromRevenue = $this->getJson('/api/admin/other-company-revenues')->json('summary');
        $fromExpenses = $this->getJson('/api/admin/my-expenses')->json('summary');

        expect($fromRevenue)->toEqual($fromExpenses)
            ->and($fromRevenue['other_company_revenue_total'])->toEqual(1500)
            ->and($fromRevenue['other_company_revenue_count'])->toBe(1)
            ->and($fromRevenue['my_profit'])->toEqual(6900); // 6,400 + 1,500 - 1,000
    });

    it('says an empty month is empty', function () {
        revenueApiOwner();

        $this->getJson('/api/admin/other-company-revenues')->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonPath('summary.other_company_revenue_total', 0)
            ->assertJsonPath('summary.other_company_revenue_count', 0);
    });
});

describe('adding revenue', function () {
    it('saves it and answers with it', function () {
        revenueApiOwner();

        $this->postJson('/api/admin/other-company-revenues', apiRevenueBody(['revenue_date' => '2026-08-20']))
            ->assertCreated()
            ->assertJsonPath('data.hire', 'ZZZ Galle Fort Tour')
            ->assertJsonPath('data.credited_amount', 9000.25)
            ->assertJsonPath('data.revenue_date', '2026-08-20')
            ->assertJsonPath('data.slip_url', null);

        expect(OtherCompanyRevenue::count())->toBe(1);
    });

    it('allows a negative balance, entered by hand', function () {
        revenueApiOwner();

        $this->postJson('/api/admin/other-company-revenues', apiRevenueBody(['balance' => '-500.25']))
            ->assertCreated()->assertJsonPath('data.balance', -500.25);
    });

    it('turns down bad input with the field named, saving nothing', function (array $changes, string $field) {
        revenueApiOwner();

        $this->postJson('/api/admin/other-company-revenues', apiRevenueBody($changes))->assertUnprocessable()->assertJsonValidationErrors($field);

        expect(OtherCompanyRevenue::count())->toBe(0);
    })->with([
        'no hire' => [['hire' => ''], 'hire'],
        'no booking number' => [['booking_number' => ''], 'booking_number'],
        'no vehicle' => [['vehicle' => ''], 'vehicle'],
        'negative full amount' => [['full_amount' => '-1'], 'full_amount'],
        'negative credited amount' => [['credited_amount' => '-1'], 'credited_amount'],
        'negative vehicle amount' => [['vehicle_amount' => '-1'], 'vehicle_amount'],
        'no date' => [['revenue_date' => ''], 'revenue_date'],
    ]);

    it('is in My Profit straight away', function () {
        revenueApiOwner();
        apiRevenueHire(8000);

        $this->postJson('/api/admin/other-company-revenues', apiRevenueBody(['credited_amount' => '1000', 'revenue_date' => '2026-09-12']))->assertCreated();

        $this->getJson('/api/admin/my-expenses')->assertJsonPath('summary.my_profit', 7400);
    });
});

describe('editing and deleting revenue', function () {
    it('changes it', function () {
        $revenue = apiRevenue();
        revenueApiOwner();

        $this->putJson("/api/admin/other-company-revenues/{$revenue->id}", apiRevenueBody(['hire' => 'ZZZ Changed', 'credited_amount' => '7700.50']))
            ->assertOk()
            ->assertJsonPath('data.hire', 'ZZZ Changed')
            ->assertJsonPath('data.credited_amount', 7700.5);

        expect(OtherCompanyRevenue::count())->toBe(1);
    });

    it('deletes it, and only it', function () {
        $revenue = apiRevenue();
        $keep = apiRevenue(['hire' => 'ZZZ keep']);
        revenueApiOwner();

        $this->deleteJson("/api/admin/other-company-revenues/{$revenue->id}")->assertOk()
            ->assertJsonPath('message', 'Revenue "ZZZ Colombo to Kandy" was deleted.');

        expect(OtherCompanyRevenue::find($revenue->id))->toBeNull()->and(OtherCompanyRevenue::find($keep->id))->not->toBeNull();
    });

    it('is 404 for revenue that is not there', function () {
        revenueApiOwner();

        $this->putJson('/api/admin/other-company-revenues/999', apiRevenueBody())->assertNotFound();
        $this->deleteJson('/api/admin/other-company-revenues/999')->assertNotFound();
    });
});

describe('the bank slip', function () {
    it('stores an uploaded slip and answers with a working url', function () {
        Storage::fake('public');
        revenueApiOwner();

        $response = $this->post('/api/admin/other-company-revenues', apiRevenueBody() + [
            'slip' => UploadedFile::fake()->image('slip.jpg'),
        ])->assertCreated();

        $revenue = OtherCompanyRevenue::first();
        Storage::disk('public')->assertExists($revenue->slip_path);
        expect($response->json('data.slip_url'))->not->toBeNull();

        $this->get($response->json('data.slip_url'))->assertOk()->assertHeader('Content-Type', 'image/jpeg');
    });

    it('replaces the old slip file when a new one is uploaded on update', function () {
        Storage::fake('public');
        revenueApiOwner();
        $created = $this->post('/api/admin/other-company-revenues', apiRevenueBody() + [
            'slip' => UploadedFile::fake()->image('first.jpg'),
        ])->assertCreated();
        $revenue = OtherCompanyRevenue::first();
        $oldPath = $revenue->slip_path;

        $this->post("/api/admin/other-company-revenues/{$revenue->id}", apiRevenueBody() + [
            '_method' => 'PUT',
            'slip' => UploadedFile::fake()->image('second.jpg'),
        ])->assertOk();

        Storage::disk('public')->assertMissing($oldPath);
        Storage::disk('public')->assertExists($revenue->fresh()->slip_path);
        expect($revenue->fresh()->slip_path)->not->toBe($oldPath);
        expect($created->json('data.slip_url'))->not->toBeNull();
    });

    it('keeps the existing slip when an edit does not send a new one', function () {
        Storage::fake('public');
        revenueApiOwner();
        $this->post('/api/admin/other-company-revenues', apiRevenueBody() + [
            'slip' => UploadedFile::fake()->image('slip.jpg'),
        ])->assertCreated();
        $revenue = OtherCompanyRevenue::first();
        $originalPath = $revenue->slip_path;

        $this->putJson("/api/admin/other-company-revenues/{$revenue->id}", apiRevenueBody(['hire' => 'ZZZ No New Slip']))->assertOk();

        expect($revenue->fresh()->slip_path)->toBe($originalPath);
        Storage::disk('public')->assertExists($originalPath);
    });

    it('removes the slip file from disk when the revenue is deleted', function () {
        Storage::fake('public');
        revenueApiOwner();
        $this->post('/api/admin/other-company-revenues', apiRevenueBody() + [
            'slip' => UploadedFile::fake()->image('slip.jpg'),
        ])->assertCreated();
        $revenue = OtherCompanyRevenue::first();
        $path = $revenue->slip_path;

        $this->deleteJson("/api/admin/other-company-revenues/{$revenue->id}")->assertOk();

        Storage::disk('public')->assertMissing($path);
    });

    it('rejects a non-image file', function () {
        Storage::fake('public');
        revenueApiOwner();

        $this->post('/api/admin/other-company-revenues', apiRevenueBody() + [
            'slip' => UploadedFile::fake()->create('notes.txt', 10),
        ])->assertUnprocessable()->assertJsonValidationErrors('slip');
    });
});
