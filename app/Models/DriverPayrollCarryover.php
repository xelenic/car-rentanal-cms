<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A deficit left over when a driver's payroll is marked paid with a
 * negative final amount (e.g. a large manual correction) — the shortfall
 * can't be "paid" in cash, so it's carried forward as an extra deduction
 * against the driver's salary for a future month.
 */
#[Fillable(['driver_id', 'source_payroll_id', 'year', 'month', 'amount'])]
class DriverPayrollCarryover extends Model
{
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
        ];
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }

    public function sourcePayroll(): BelongsTo
    {
        return $this->belongsTo(DriverPayroll::class, 'source_payroll_id');
    }
}
