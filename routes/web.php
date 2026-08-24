<?php

use App\Http\Controllers\Admin\ArrearsLoanController;
use App\Http\Controllers\Admin\CustomerController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\DriverController;
use App\Http\Controllers\Admin\ExpenseController;
use App\Http\Controllers\Admin\HireController;
use App\Http\Controllers\Admin\LocationController;
use App\Http\Controllers\Admin\PackageController;
use App\Http\Controllers\Admin\PayrollController;
use App\Http\Controllers\Admin\PermissionController;
use App\Http\Controllers\Admin\RoleController;
use App\Http\Controllers\Admin\SalaryAdvanceController;
use App\Http\Controllers\Admin\UserController;
use App\Http\Controllers\Admin\VehicleController;
use App\Http\Controllers\Admin\VehicleLeasingController;
use App\Http\Controllers\Admin\VehicleLeasingSettlementController;
use App\Http\Controllers\Admin\VehicleMaintenanceController;
use App\Http\Controllers\Auth\AuthenticatedSessionController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect()->route('admin.dashboard');
});

Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthenticatedSessionController::class, 'create'])->name('login');
    Route::post('/login', [AuthenticatedSessionController::class, 'store']);
});

Route::post('/logout', [AuthenticatedSessionController::class, 'destroy'])
    ->middleware('auth')
    ->name('logout');

Route::prefix('admin')->name('admin.')->middleware('auth')->group(function () {
    Route::get('/', [DashboardController::class, 'index'])->name('dashboard');

    Route::resource('vehicles', VehicleController::class)->except(['show', 'create', 'edit']);
    Route::get('repairs', [VehicleMaintenanceController::class, 'index'])->name('repairs.index');
    Route::delete('repairs/{vehicleMaintenanceRecord}', [VehicleMaintenanceController::class, 'destroy'])->name('repairs.destroy');
    Route::get('leasing', [VehicleLeasingController::class, 'index'])->name('leasing.index');
    Route::post('leasing', [VehicleLeasingController::class, 'store'])->name('leasing.store');
    Route::put('leasing/{leasing}', [VehicleLeasingController::class, 'update'])->name('leasing.update');
    Route::delete('leasing/{leasing}', [VehicleLeasingController::class, 'destroy'])->name('leasing.destroy');
    Route::post('leasing/{leasing}/settlements', [VehicleLeasingSettlementController::class, 'store'])->name('leasing.settlements.store');
    Route::delete('leasing/{leasing}/settlements/{settlement}', [VehicleLeasingSettlementController::class, 'destroy'])->name('leasing.settlements.destroy');
    Route::resource('drivers', DriverController::class)->except(['show', 'create', 'edit']);
    Route::post('drivers/{driver}/payroll', [PayrollController::class, 'finalize'])->name('drivers.payroll.finalize');
    Route::post('drivers/{driver}/payroll/{payroll}/mark-paid', [PayrollController::class, 'markPaid'])->name('drivers.payroll.mark-paid');
    Route::delete('drivers/{driver}/payroll/{payroll}/revert', [PayrollController::class, 'revert'])->name('drivers.payroll.revert');
    Route::get('drivers/{driver}/payroll/{payroll}/slip', [PayrollController::class, 'slip'])->name('drivers.payroll.slip');
    Route::post('drivers/{driver}/arrears-loan', [ArrearsLoanController::class, 'store'])->name('drivers.arrears-loan.store');
    Route::resource('locations', LocationController::class)->except(['show', 'create', 'edit']);
    Route::resource('packages', PackageController::class)->except(['show', 'create', 'edit']);
    Route::resource('customers', CustomerController::class)->except(['show', 'create', 'edit']);
    Route::resource('hires', HireController::class)->except(['show', 'create', 'edit']);
    Route::get('hires/{hire}/tracking', [HireController::class, 'tracking'])->name('hires.tracking');
    Route::get('expenses', [ExpenseController::class, 'index'])->name('expenses.index');
    Route::get('salary-advances', [SalaryAdvanceController::class, 'index'])->name('salary-advances.index');
    Route::put('salary-advances/{salaryAdvance}', [SalaryAdvanceController::class, 'update'])->name('salary-advances.update');
    Route::resource('users', UserController::class)->except(['show', 'create', 'edit']);
    Route::resource('roles', RoleController::class)->except(['show', 'create', 'edit']);
    Route::resource('permissions', PermissionController::class)->except(['show', 'create', 'edit']);
});
