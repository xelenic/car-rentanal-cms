<?php

use App\Models\Customer;
use App\Models\Driver;
use App\Models\DriverArrearsLoan;
use App\Models\DriverPayroll;
use App\Models\Hire;
use App\Models\HireExpense;
use App\Models\User;
use App\Models\Vehicle;
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

it('totals this driver\'s hires across all time for the summary cards, excluding cancelled ones', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $someoneElse = driverShowDriver('ZZZ Kamal');

    driverShowHire(['driver_id' => $driver->id, 'hire_full_value' => 5000, 'our_hire_value' => 3500]);
    driverShowHire(['driver_id' => $driver->id, 'hire_full_value' => 3000, 'our_hire_value' => 2000]);
    driverShowHire(['driver_id' => $driver->id, 'hire_full_value' => 9999, 'our_hire_value' => 9999, 'status' => 'cancelled']);
    driverShowHire(['driver_id' => $someoneElse->id, 'hire_full_value' => 7777, 'our_hire_value' => 7777]);

    $response = $this->get('/admin/drivers/'.$driver->id);

    $response->assertOk();
    $response->assertViewHas('summary', function (array $summary) {
        return $summary['hire_count'] === 2
            && $summary['hire_full_value_total'] === 8000.0
            && $summary['commission_total'] === 2500.0;
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

    test()->travelTo(\Illuminate\Support\Carbon::parse('2026-09-16 12:00:00'));
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 1500]);
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'parking', 'amount' => 250]);
    HireExpense::create(['driver_id' => $someoneElse->id, 'category' => 'fuel', 'amount' => 9999]);

    test()->travelTo(\Illuminate\Support\Carbon::parse('2026-08-16 12:00:00'));
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

it('totals this driver\'s expenses across all time for the summary card', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $someoneElse = driverShowDriver('ZZZ Kamal');

    HireExpense::create(['driver_id' => $driver->id, 'category' => 'fuel', 'amount' => 1000]);
    HireExpense::create(['driver_id' => $driver->id, 'category' => 'repair', 'amount' => 2000]);
    HireExpense::create(['driver_id' => $someoneElse->id, 'category' => 'fuel', 'amount' => 9999]);

    $response = $this->get('/admin/drivers/'.$driver->id);

    $response->assertOk();
    $response->assertViewHas('summary', fn (array $summary) => $summary['expenses_total'] === 3000.0);
});

it('links to the receipt when an expense has one, and shows a hire\'s tour type when tied to one', function () {
    driverShowAdmin();
    $driver = driverShowDriver();
    $hire = driverShowHire(['driver_id' => $driver->id, 'start_time' => '2026-09-10 10:00:00']);

    test()->travelTo(\Illuminate\Support\Carbon::parse('2026-09-16 12:00:00'));
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

    test()->travelTo(\Illuminate\Support\Carbon::parse('2026-09-16 12:00:00'));
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

    test()->travelTo(\Illuminate\Support\Carbon::parse('2026-09-16 12:00:00'));
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
