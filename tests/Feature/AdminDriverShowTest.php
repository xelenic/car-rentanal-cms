<?php

use App\Models\Customer;
use App\Models\Driver;
use App\Models\DriverArrearsLoan;
use App\Models\DriverDepositTransfer;
use App\Models\DriverPayroll;
use App\Models\Hire;
use App\Models\HireExpense;
use App\Models\User;
use App\Models\Vehicle;
use App\Models\VehicleMaintenanceRecord;
use App\Support\SelectedPeriod;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Spatie\Permission\Models\Permission;

uses(RefreshDatabase::class);

function driverShowAdmin(array $permissions = ['drivers.view']): User
{
    foreach ($permissions as $permission) {
        Permission::findOrCreate($permission, 'web');
    }

    $user = User::factory()->create();
    $user->givePermissionTo($permissions);
    test()->actingAs($user);

    return $user;
}

function driverShowDriver(string $name = 'ZZZ Nimal'): Driver
{
    return Driver::create([
        'name' => $name,
        'license' => 'ZZZ-'.$name,
        'contact_number' => '0770000000',
        'email' => strtolower(str_replace(' ', '.', $name)).'@example.com',
        'password' => bcrypt('testpass123'),
    ]);
}

function driverShowVehicle(string $model = 'ZZZ Prius'): Vehicle
{
    return Vehicle::create(['model' => $model, 'condition' => 'Good', 'seats' => 4, 'pax' => 4]);
}

function driverShowCustomer(string $name = 'ZZZ Customer'): Customer
{
    return Customer::create(['name' => $name, 'phone' => '0770000000']);
}

function driverShowHire(array $attributes = []): Hire
{
    return Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 5000, 'our_hire_value' => 3500,
        'payment_type' => 'cash', 'start_time' => now()->subDay(),
    ]);
}

it('is forbidden without the drivers.view permission', function () {
    $driver = driverShowDriver();
    driverShowAdmin([]);

    $this->get('/admin/drivers/'.$driver->id)->assertForbidden();
});

it('shows the driver\'s name, license and contact details', function () {
    driverShowAdmin();
    $driver = driverShowDriver('ZZZ Sunil');

    $response = $this->get('/admin/drivers/'.$driver->id);

    $response->assertOk();
    $response->assertSee('ZZZ Sunil');
    $response->assertSee('ZZZ-ZZZ Sunil');
    $response->assertSee('0770000000');
    $response->assertSee('zzz.sunil@example.com');
});

describe('the summary cards', function () {
    it('total this driver\'s hires for the selected month only, excluding cancelled ones', function () {
        driverShowAdmin();
        $driver = driverShowDriver();
        $someoneElse = driverShowDriver('ZZZ Kamal');

        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 5000, 'our_hire_value' => 3500]);
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-12 10:00:00', 'hire_full_value' => 3000, 'our_hire_value' => 2000]);
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-14 10:00:00', 'hire_full_value' => 9999, 'our_hire_value' => 9999, 'status' => 'cancelled']);
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-08-10 10:00:00', 'hire_full_value' => 6666, 'our_hire_value' => 6666]);
        driverShowHire(['driver_id' => $someoneElse->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 7777, 'our_hire_value' => 7777]);

        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

        $response->assertOk();
        $response->assertViewHas('periodSummary', fn (array $summary) => $summary['hire_count'] === 2
            && $summary['hire_full_value_total'] === 8000.0
            && $summary['our_hire_value_total'] === 5500.0
            && $summary['commission_total'] === 2500.0);
        $response->assertSeeInOrder([
            'Summary &middot; September 2026',
            'Total Full Hire Value', 'Rs. 8,000.00', '2 hires',
            'Our Hire Value', 'Rs. 5,500.00',
            'Total Commission', 'Rs. 2,500.00',
        ], false);
    });

    it('show the month\'s driver salary, deposit amount and what\'s still to be deposited', function () {
        driverShowAdmin();
        $driver = driverShowDriver();

        // Cash hire 5000 (our value 3500) less 1000 fuel: deposit 4000; salary 20% of (3500 - 1000) = 500.
        $hire = driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00']);
        HireExpense::create(['driver_id' => $driver->id, 'hire_id' => $hire->id, 'category' => 'fuel', 'amount' => 1000]);
        DriverDepositTransfer::create(['driver_id' => $driver->id, 'year' => 2026, 'month' => 9, 'amount' => 1500, 'slip_path' => 'deposit-slips/zzz.jpg']);
        DriverDepositTransfer::create(['driver_id' => $driver->id, 'year' => 2026, 'month' => 8, 'amount' => 9999, 'slip_path' => 'deposit-slips/zzz.jpg']);

        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

        $response->assertViewHas('periodSummary', fn (array $summary) => $summary['salary_payable'] === 500.0
            && $summary['deposit_amount'] === 4000.0
            && $summary['deposit_transferred_total'] === 1500.0
            && $summary['to_be_deposited'] === 2500.0);
        $response->assertSeeInOrder([
            'Driver Salary', 'Rs. 500.00', 'Not finalized yet',
            'Driver Deposit Amount', 'Rs. 4,000.00',
            'To Be Deposited', 'Rs. 2,500.00', 'Rs. 1,500.00 already transferred',
        ]);
    });

    it('show nothing left to deposit, not a negative figure, once more than the deposit was transferred', function () {
        driverShowAdmin();
        $driver = driverShowDriver();
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 2000, 'our_hire_value' => 1500]);
        DriverDepositTransfer::create(['driver_id' => $driver->id, 'year' => 2026, 'month' => 9, 'amount' => 2500, 'slip_path' => 'deposit-slips/zzz.jpg']);

        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

        $response->assertViewHas('periodSummary', fn (array $summary) => $summary['to_be_deposited'] === 0.0);
        $response->assertSeeInOrder(['To Be Deposited', 'Rs. 0.00', 'Rs. 2,500.00 already transferred']);
    });

    it('follow the month the navbar shows when the page is opened without one', function () {
        driverShowAdmin();
        $driver = driverShowDriver();
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        // Only August has hires — but nothing's been picked, so the navbar shows this real month.
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-08-10 10:00:00', 'hire_full_value' => 6666]);

        $response = $this->get('/admin/drivers/'.$driver->id);

        $response->assertViewHas('selectedMonth', 9);
        $response->assertViewHas('periodSummary', fn (array $summary) => $summary['hire_full_value_total'] === 0.0);
        $response->assertSee('Summary &middot; September 2026', false);
    });

    it('follow a month the navbar picked, even one this driver has no hires in, and still offer it in the month dropdown', function () {
        driverShowAdmin();
        $driver = driverShowDriver();
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-08-10 10:00:00', 'hire_full_value' => 6666]);
        SelectedPeriod::remember(2026, 10);

        $response = $this->get('/admin/drivers/'.$driver->id);

        $response->assertSee('Summary &middot; October 2026', false);
        $response->assertSee('<option value="10" selected>October</option>', false);
        $response->assertSee('<option value="8" >August</option>', false);
        $response->assertDontSee('Rs. 6,666.00');
    });
});

it('lists only the selected driver\'s hires for the selected month', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $customer = driverShowCustomer('ZZZ Amal');
    $vehicle = driverShowVehicle();

    driverShowHire([
        'driver_id' => $driver->id, 'customer_id' => $customer->id, 'vehicle_id' => $vehicle->id,
        'start_time' => '2026-09-15 10:00:00', 'hire_full_value' => 4001,
    ]);
    driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-08-15 10:00:00', 'hire_full_value' => 4002]);
    driverShowHire([
        'driver_id' => driverShowDriver('ZZZ Kamal')->id, 'start_time' => '2026-09-15 10:00:00', 'hire_full_value' => 4003,
    ]);

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

    $response->assertOk();
    $response->assertSee('Rs. 4,001.00');
    $response->assertDontSee('Rs. 4,002.00');
    $response->assertDontSee('Rs. 4,003.00');
    $response->assertSee('ZZZ Amal');
    $response->assertSee('ZZZ Prius');
});

describe('the Earnings tab\'s hire rows', function () {
    it('links each hire to its own page on the Hires list, scoped to just it', function () {
        driverShowAdmin(['drivers.view', 'hires.view']);
        $driver = driverShowDriver();
        $hire = driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-15 10:00:00']);

        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

        $response->assertSee(route('admin.hires.index', ['driver_id' => $driver->id, 'hire_id' => $hire->id]));
    });

    it('offers no hire link or actions to someone without any hires permission', function () {
        driverShowAdmin(['drivers.view']);
        $driver = driverShowDriver();
        $hire = driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-15 10:00:00']);

        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

        $response->assertDontSee(route('admin.hires.index', ['driver_id' => $driver->id, 'hire_id' => $hire->id]));
    });

    it('offers Delete to someone with hires.delete, hidden otherwise', function () {
        driverShowAdmin(['drivers.view', 'hires.delete']);
        $driver = driverShowDriver();
        $hire = driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-15 10:00:00']);

        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

        $response->assertSee(route('admin.hires.destroy', $hire), false);
    });

    it('deletes a hire and redirects back to the same driver tab and period', function () {
        driverShowAdmin(['drivers.view', 'hires.delete']);
        $driver = driverShowDriver();
        $hire = driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-15 10:00:00']);
        $backUrl = '/admin/drivers/'.$driver->id.'?year=2026&month=9';

        $response = $this->from($backUrl)->delete(route('admin.hires.destroy', $hire));

        $response->assertRedirect($backUrl);
        expect(Hire::find($hire->id))->toBeNull();
    });
});

describe('exporting the Hires tab as CSV', function () {
    it('needs drivers.view', function () {
        $driver = driverShowDriver();
        driverShowAdmin([]);

        $this->get("/admin/drivers/{$driver->id}/hires/export?year=2026&month=9")->assertForbidden();
    });

    it('downloads a CSV with one row per hire and a Total row', function () {
        driverShowAdmin();
        $driver = driverShowDriver();
        $customer = driverShowCustomer('ZZZ Amal');
        $vehicle = driverShowVehicle();
        // The vehicle maintenance record below is dated by created_at, not a
        // year/month column — travel there so it lands in September.
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));

        $cashHire = driverShowHire([
            'driver_id' => $driver->id, 'customer_id' => $customer->id, 'vehicle_id' => $vehicle->id,
            'start_time' => '2026-09-15 10:00:00', 'hire_full_value' => 10000, 'our_hire_value' => 8000, 'payment_type' => 'cash',
        ]);
        HireExpense::create(['driver_id' => $driver->id, 'hire_id' => $cashHire->id, 'category' => 'fuel', 'amount' => 500]);
        HireExpense::create(['driver_id' => $driver->id, 'hire_id' => $cashHire->id, 'category' => 'parking', 'amount' => 100]);
        $creditHire = driverShowHire([
            'driver_id' => $driver->id, 'customer_id' => $customer->id, 'vehicle_id' => $vehicle->id,
            'start_time' => '2026-09-20 10:00:00', 'hire_full_value' => 4000, 'our_hire_value' => 4000, 'payment_type' => 'credit',
        ]);
        DriverDepositTransfer::create(['driver_id' => $driver->id, 'year' => 2026, 'month' => 9, 'amount' => 3000, 'slip_path' => 'zzz.jpg']);
        VehicleMaintenanceRecord::create([
            'vehicle_id' => $vehicle->id, 'driver_id' => $driver->id, 'type' => 'repair', 'cost' => 250, 'bill_path' => 'zzz.jpg',
        ]);

        $response = $this->get("/admin/drivers/{$driver->id}/hires/export?year=2026&month=9");

        $response->assertOk();
        $response->assertHeader('Content-Type', 'text/csv; charset=UTF-8');
        $rows = array_map('str_getcsv', explode("\n", trim($response->streamedContent())));

        expect($rows[0])->toBe([
            'Date', 'Hire', 'Full Value of Hire', 'Hire Value', 'Deposit Commission',
            'Fuel', 'High Way Charges', 'Driver Food', 'Other Chargess', 'Cost Of Hire',
            'Driver Charges', 'Full Cost Of Hire', 'Full Saving Of Hire',
            'Driver Payment', 'Deposit', 'Credit Hire', 'Car Repair',
        ]);

        // Cash hire: full 10,000, our 8,000, commission 2,000; cost 500+100=600;
        // driver charges (8,000-600)*20%=1,480; full cost 2,080; saving 5,920.
        // The "Hire" column is blank here — the fixture sets no from/to location.
        expect($rows[1])->toBe([
            '15/09/26', '', '10000.00', '8000.00', '2000.00',
            '500.00', '', '', '100.00', '600.00', '1480.00', '2080.00', '5920.00', '', '', '', '',
        ]);

        // Credit hire: full 4,000 appears again under Credit Hire.
        expect($rows[2])->toBe([
            '20/09/26', '', '4000.00', '4000.00', '0.00',
            '', '', '', '', '0.00', '800.00', '800.00', '3200.00', '', '', '4000.00', '',
        ]);

        $total = $rows[3];
        expect($total[0])->toBe('Total')
            ->and($total[2])->toBe('14000.00') // full value
            ->and($total[3])->toBe('12000.00') // our value
            ->and($total[14])->toBe('3000.00') // Deposit — transferred this month
            ->and($total[15])->toBe('4000.00') // Credit Hire total
            ->and($total[16])->toBe('250.00'); // Car Repair — vehicle maintenance total
    });

    it('leaves another month\'s hires out', function () {
        driverShowAdmin();
        $driver = driverShowDriver();
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-08-15 10:00:00', 'hire_full_value' => 9999]);

        $response = $this->get("/admin/drivers/{$driver->id}/hires/export?year=2026&month=9");

        $rows = array_map('str_getcsv', explode("\n", trim($response->streamedContent())));
        expect($rows)->toHaveCount(2); // header + Total only
        expect($rows[1][0])->toBe('Total');
    });
});

it('matches an unscheduled hire into the month it was recorded', function () {
    driverShowAdmin();
    $driver = driverShowDriver();

    $unscheduled = driverShowHire(['driver_id' => $driver->id, 'start_time' => null, 'hire_full_value' => 4567]);
    $unscheduled->forceFill(['created_at' => '2026-09-20 10:00:00'])->saveQuietly();

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

    $response->assertOk();
    $response->assertSee('Rs. 4,567.00');
});

it('lists only the selected driver\'s expenses for the selected month, with category and amount', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $someoneElse = driverShowDriver('ZZZ Kamal');

    test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 1500]);
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'parking', 'amount' => 250]);
    HireExpense::create(['driver_id' => $someoneElse->id, 'category' => 'fuel', 'amount' => 9999]);

    test()->travelTo(Carbon::parse('2026-08-16 12:00:00'));
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'repair', 'amount' => 7777]);

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=expenses');

    $response->assertOk();
    $response->assertSee('Fuel');
    $response->assertSee('Rs. 1,500.00');
    $response->assertSee('Parking Tickets');
    $response->assertSee('Rs. 250.00');
    $response->assertDontSee('Rs. 9,999.00');
    $response->assertDontSee('Rs. 7,777.00');
    $response->assertViewHas('periodSummary', fn (array $summary) => $summary['expenses_total'] === 1750.0);
});

it('totals this driver\'s expenses for the selected month on the summary card', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $someoneElse = driverShowDriver('ZZZ Kamal');

    test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 1000]);
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'repair', 'amount' => 2000]);
    HireExpense::create(['driver_id' => $someoneElse->id, 'category' => 'fuel', 'amount' => 9999]);

    test()->travelTo(Carbon::parse('2026-08-16 12:00:00'));
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 7777]);

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');

    $response->assertOk();
    $response->assertViewHas('periodSummary', fn (array $summary) => $summary['expenses_total'] === 3000.0);
    $response->assertSeeInOrder(['Total Expenses', 'Rs. 3,000.00', '2 expenses logged']);
});

it('links to the receipt when an expense has one, and shows a hire\'s tour type when tied to one', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $hire = driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00']);

    test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
    HireExpense::create([
        'driver_id' => $driver->id, 'hire_id' => $hire->id, 'category' => 'fuel', 'amount' => 800,
        'receipt_path' => 'hire-expenses/'.$hire->id.'/receipt.jpg',
    ]);

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=expenses');

    $response->assertOk();
    $response->assertSee('Drop and Pickup');
    $response->assertSee(route('hire-expenses.receipt', HireExpense::first()));
});

it('shows the month\'s salary calculation, with only salary-deductible expenses in the breakdown', function () {
    driverShowAdmin();
    $driver = driverShowDriver();

    test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
    driverShowHire([
        'driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00',
        'hire_full_value' => 1500, 'our_hire_value' => 1000,
    ]);
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 200]);
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'repair', 'amount' => 300]);

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=salary');

    $response->assertOk()->assertViewHas('tab', 'salary');
    $response->assertSee('Rs. 1,500.00'); // Total Hired Value
    $response->assertSee('Rs. 1,000.00'); // Our Hire Value
    $response->assertSee('Rs. 500.00');   // Commission
    $response->assertSee('Fuel');
    $response->assertSee('-Rs. 200.00');  // Deductible expense
    $response->assertSee('Rs. 800.00');   // Net Before Salary (1000 - 200)
    $response->assertSee('20% Driver Salary');
    $response->assertSee('Rs. 160.00');   // 20% of 800
    $response->assertSee('Net Salary Payable');
    // 'repair' isn't a salary-deductible category, so it's excluded from this breakdown.
    $response->assertDontSee('Vehicle Repair');
});

it('says so when there are no hires to calculate salary from', function () {
    driverShowAdmin();
    $driver = driverShowDriver();

    $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=salary');

    $response->assertOk();
    $response->assertSee('No hires recorded for September 2026 yet.');
});

it('defaults to the Earnings tab, and switches to Expenses only when asked', function () {
    driverShowAdmin();
    $driver = driverShowDriver();

    test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 1234]);

    $default = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');
    $default->assertOk()->assertViewHas('tab', 'earnings');
    // The category badge only ever appears in the Expenses tab's own table,
    // unlike the amount, which the all-time stat tile also shows.
    $default->assertDontSee('Fuel');

    $expensesTab = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=expenses');
    $expensesTab->assertOk()->assertViewHas('tab', 'expenses');
    $expensesTab->assertSee('Fuel');
    $expensesTab->assertSee('Rs. 1,234.00');
});

describe('Make Payroll (Salary tab)', function () {
    it('shows the button to someone with payroll.manage, and hides it from someone without', function () {
        $driver = driverShowDriver();
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 1000, 'our_hire_value' => 500]);

        driverShowAdmin(['drivers.view']);
        $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=salary')->assertDontSee('Make Payroll');

        driverShowAdmin(['drivers.view', 'payroll.manage']);
        $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=salary')->assertSee('Make Payroll');
    });

    it('needs payroll.manage to finalize one', function () {
        $driver = driverShowDriver();
        driverShowAdmin(['drivers.view']);

        $this->post("/admin/drivers/{$driver->id}/payroll", ['year' => 2026, 'month' => 9])->assertForbidden();
        expect(DriverPayroll::count())->toBe(0);
    });

    it('finalizes a payroll and, given redirect_to=show, returns to the Salary tab', function () {
        $driver = driverShowDriver();
        driverShowAdmin(['drivers.view', 'payroll.manage']);
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 1000, 'our_hire_value' => 500]);

        $response = $this->post("/admin/drivers/{$driver->id}/payroll", [
            'year' => 2026, 'month' => 9, 'redirect_to' => 'show',
        ]);

        $response->assertRedirect(route('admin.drivers.show', ['driver' => $driver->id, 'tab' => 'salary', 'year' => 2026, 'month' => 9]));
        $payroll = DriverPayroll::where('driver_id', $driver->id)->first();
        expect($payroll)->not->toBeNull()
            ->and($payroll->status)->toBe('finalized');
    });

    it('without redirect_to, still falls back to the drivers index (unchanged default)', function () {
        $driver = driverShowDriver();
        driverShowAdmin(['drivers.view', 'payroll.manage']);
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 1000, 'our_hire_value' => 500]);

        $response = $this->post("/admin/drivers/{$driver->id}/payroll", ['year' => 2026, 'month' => 9]);

        $response->assertRedirect(route('admin.drivers.index', ['year' => 2026, 'month' => 9]));
    });

    it('marking a finalized payroll as paid redirects back to the Salary tab', function () {
        $driver = driverShowDriver();
        driverShowAdmin(['drivers.view', 'payroll.manage']);
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 1000, 'our_hire_value' => 500]);
        $this->post("/admin/drivers/{$driver->id}/payroll", ['year' => 2026, 'month' => 9]);
        $payroll = DriverPayroll::where('driver_id', $driver->id)->first();

        $response = $this->post("/admin/drivers/{$driver->id}/payroll/{$payroll->id}/mark-paid", [
            'year' => 2026, 'month' => 9, 'redirect_to' => 'show',
        ]);

        $response->assertRedirect(route('admin.drivers.show', ['driver' => $driver->id, 'tab' => 'salary', 'year' => 2026, 'month' => 9]));
        expect($payroll->fresh()->status)->toBe('paid');
    });

    it('reverting a finalized payroll redirects back to the Salary tab', function () {
        $driver = driverShowDriver();
        driverShowAdmin(['drivers.view', 'payroll.manage']);
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 1000, 'our_hire_value' => 500]);
        $this->post("/admin/drivers/{$driver->id}/payroll", ['year' => 2026, 'month' => 9]);
        $payroll = DriverPayroll::where('driver_id', $driver->id)->first();

        $response = $this->delete("/admin/drivers/{$driver->id}/payroll/{$payroll->id}/revert", [
            'year' => 2026, 'month' => 9, 'redirect_to' => 'show',
        ]);

        $response->assertRedirect(route('admin.drivers.show', ['driver' => $driver->id, 'tab' => 'salary', 'year' => 2026, 'month' => 9]));
        expect(DriverPayroll::find($payroll->id))->toBeNull();
    });
});

describe('Deposit tab', function () {
    it('shows the deposit breakdown and balance for the period', function () {
        driverShowAdmin();
        $driver = driverShowDriver();
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        driverShowHire([
            'driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00',
            'hire_full_value' => 1000, 'our_hire_value' => 100,
        ]);

        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=deposit');

        $response->assertOk()->assertViewHas('tab', 'deposit');
        $response->assertSee('Deposit Amount');
        $response->assertSee('Balance');
        $response->assertSee('Net Payable Salary');
    });

    it('says so when there is no deposit activity for the period', function () {
        driverShowAdmin();
        $driver = driverShowDriver();

        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=deposit');

        $response->assertOk();
        $response->assertSee('No deposit activity for September 2026.');
    });

    it('shows a balance badge on the Deposit nav tab regardless of which tab is active', function () {
        driverShowAdmin();
        $driver = driverShowDriver();
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 1000, 'our_hire_value' => 100]);

        // Default tab is Earnings, but the nav itself (and so the balance
        // badge on the Deposit link) renders on every tab, not just Deposit's own.
        $response = $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9');
        $response->assertViewHas('tab', 'earnings');
        $response->assertSeeInOrder(['tab-deposit', 'Rs. 1,000.00'], false);
    });
});

describe('Change as Arrears Loan (Deposit tab)', function () {
    it('shows the button only when there is a deficit, and only to payroll.manage', function () {
        $driver = driverShowDriver();
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        // Collected Rs. 1000 cash (owed to the company) on a hire that only
        // earns the driver a small salary — a deficit, since 20% of our hire
        // value (500) is far less than the cash they're holding.
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 1000, 'our_hire_value' => 100]);

        driverShowAdmin(['drivers.view']);
        $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=deposit')->assertDontSee('Change as Arrears Loan');

        driverShowAdmin(['drivers.view', 'payroll.manage']);
        $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=deposit')->assertSee('Change as Arrears Loan');
    });

    it('hides the button when there is no deficit', function () {
        $driver = driverShowDriver();
        driverShowAdmin(['drivers.view', 'payroll.manage']);
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        // All credit (nothing owed in cash) — no deficit to convert.
        driverShowHire([
            'driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00',
            'hire_full_value' => 1000, 'our_hire_value' => 500, 'payment_type' => 'credit',
        ]);

        $this->get('/admin/drivers/'.$driver->id.'?year=2026&month=9&tab=deposit')->assertDontSee('Change as Arrears Loan');
    });

    it('needs payroll.manage to convert a deficit', function () {
        $driver = driverShowDriver();
        driverShowAdmin(['drivers.view']);

        $this->post("/admin/drivers/{$driver->id}/arrears-loan", [
            'year' => 2026, 'month' => 9, 'deduction_type' => 'full',
        ])->assertForbidden();
        expect(DriverArrearsLoan::count())->toBe(0);
    });

    it('converts the deficit into an arrears loan and redirects back to the Deposit tab', function () {
        $driver = driverShowDriver();
        driverShowAdmin(['drivers.view', 'payroll.manage']);
        test()->travelTo(Carbon::parse('2026-09-16 12:00:00'));
        driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00', 'hire_full_value' => 1000, 'our_hire_value' => 100]);

        $response = $this->post("/admin/drivers/{$driver->id}/arrears-loan", [
            'year' => 2026, 'month' => 9, 'deduction_type' => 'full', 'redirect_to' => 'show',
        ]);

        $response->assertRedirect(route('admin.drivers.show', ['driver' => $driver->id, 'tab' => 'deposit', 'year' => 2026, 'month' => 9]));
        $loan = DriverArrearsLoan::where('driver_id', $driver->id)->first();
        expect($loan)->not->toBeNull()
            ->and($loan->deduction_type)->toBe('full');
    });
});
