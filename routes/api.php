<?php

use App\Http\Controllers\Api\Admin\AuthController as AdminAuthController;
use App\Http\Controllers\Api\Admin\HireController as AdminHireController;
use App\Http\Controllers\Api\Admin\PlaceController as AdminPlaceController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\DriverArrearsLoanController;
use App\Http\Controllers\Api\DriverDepositTransferController;
use App\Http\Controllers\Api\DriverHireController;
use App\Http\Controllers\Api\DriverSalaryController;
use App\Http\Controllers\Api\HireExpenseController;
use App\Http\Controllers\Api\HireTrackingController;
use App\Http\Controllers\Api\SalaryAdvanceController;
use App\Http\Controllers\Api\VehicleController;
use App\Http\Controllers\Api\VehicleMaintenanceController;
use Illuminate\Support\Facades\Route;

Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/admin/auth/login', [AdminAuthController::class, 'login']);

Route::get('/hire-expenses/{hireExpense}/receipt', [HireExpenseController::class, 'receipt'])
    ->name('hire-expenses.receipt');

Route::get('/deposit-transfers/{depositTransfer}/slip', [DriverDepositTransferController::class, 'slip'])
    ->name('driver-deposit-transfers.slip');

Route::get('/vehicle-maintenance/{vehicleMaintenanceRecord}/bill', [VehicleMaintenanceController::class, 'bill'])
    ->name('vehicle-maintenance.bill');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/driver/me', [AuthController::class, 'me']);
    Route::get('/driver/hires', [DriverHireController::class, 'index']);
    Route::get('/driver/hires/periods', [DriverHireController::class, 'periods']);
    Route::get('/driver/hires/{hire}', [DriverHireController::class, 'show']);
    Route::get('/driver/expenses', [HireExpenseController::class, 'driverIndex']);
    Route::post('/driver/expenses', [HireExpenseController::class, 'storeForDriver']);
    Route::get('/driver/salary', [DriverSalaryController::class, 'index']);
    Route::get('/driver/salary-advances', [SalaryAdvanceController::class, 'index']);
    Route::post('/driver/salary-advances', [SalaryAdvanceController::class, 'store']);
    Route::get('/driver/arrears-loans', [DriverArrearsLoanController::class, 'index']);
    Route::get('/driver/deposit-transfers', [DriverDepositTransferController::class, 'index']);
    Route::post('/driver/deposit-transfers', [DriverDepositTransferController::class, 'store']);
    Route::get('/driver/vehicles', [VehicleController::class, 'index']);
    Route::get('/driver/vehicle-maintenance', [VehicleMaintenanceController::class, 'index']);
    Route::post('/driver/vehicle-maintenance', [VehicleMaintenanceController::class, 'store']);

    Route::post('/driver/hires/{hire}/tracking/start', [HireTrackingController::class, 'start']);
    Route::post('/driver/hires/{hire}/tracking/stop', [HireTrackingController::class, 'stop']);
    Route::post('/driver/hires/{hire}/tracking/complete', [HireTrackingController::class, 'complete']);
    Route::post('/driver/hires/{hire}/tracking/points', [HireTrackingController::class, 'storePoint']);

    Route::get('/driver/hires/{hire}/expenses', [HireExpenseController::class, 'index']);
    Route::post('/driver/hires/{hire}/expenses', [HireExpenseController::class, 'store']);

    Route::post('/admin/auth/logout', [AdminAuthController::class, 'logout']);
    Route::get('/admin/me', [AdminAuthController::class, 'me']);
    Route::get('/admin/hires', [AdminHireController::class, 'index']);
    Route::get('/admin/hires/reference-data', [AdminHireController::class, 'referenceData']);
    Route::get('/admin/hires/{hire}', [AdminHireController::class, 'show']);
    Route::post('/admin/hires', [AdminHireController::class, 'store']);

    Route::get('/admin/places/autocomplete', [AdminPlaceController::class, 'autocomplete']);
    Route::get('/admin/places/details', [AdminPlaceController::class, 'details']);
});
