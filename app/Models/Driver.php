<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'user_id', 'name', 'license', 'driver_id_softcopy_path', 'contact_number',
    'additional_phone_number', 'tourism_board_license_path', 'email', 'password',
])]
#[Hidden(['password'])]
class Driver extends Model
{
    protected function casts(): array
    {
        return [
            'password' => 'hashed',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function hires(): HasMany
    {
        return $this->hasMany(Hire::class);
    }

    public function salaryAdvanceRequests(): HasMany
    {
        return $this->hasMany(SalaryAdvanceRequest::class)->latest();
    }

    public function salaryAdvanceDeductions(): HasMany
    {
        return $this->hasMany(SalaryAdvanceDeduction::class);
    }

    public function payrolls(): HasMany
    {
        return $this->hasMany(DriverPayroll::class);
    }

    public function depositTransfers(): HasMany
    {
        return $this->hasMany(DriverDepositTransfer::class)->latest();
    }

    public function payrollCarryovers(): HasMany
    {
        return $this->hasMany(DriverPayrollCarryover::class);
    }

    public function arrearsLoans(): HasMany
    {
        return $this->hasMany(DriverArrearsLoan::class)->latest();
    }

    public function vehicleMaintenanceRecords(): HasMany
    {
        return $this->hasMany(VehicleMaintenanceRecord::class)->latest();
    }

    /**
     * Every expense directly attributed to this driver, regardless of
     * whether it's tied to a hire (hire_id is backfilled for those too —
     * see the hire_expenses migration).
     */
    public function expenses(): HasMany
    {
        return $this->hasMany(HireExpense::class);
    }
}
