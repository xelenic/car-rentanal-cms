<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A deficit converted into a loan when a driver's Net Payment for a month
 * goes negative (their earned salary doesn't cover the deposit they still
 * owe the company). Instead of chasing the driver for cash, the shortfall
 * is scheduled as a deduction against future salary — either fully next
 * month, or split across several upcoming months.
 */
#[Fillable(['driver_id', 'source_year', 'source_month', 'amount', 'deduction_type', 'created_by'])]
class DriverArrearsLoan extends Model
{
    public const DEDUCTION_TYPES = [
        'full' => 'Full amount next month',
        'installments' => 'Split across upcoming months',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
        ];
    }

    public function getDeductionTypeLabelAttribute(): string
    {
        return self::DEDUCTION_TYPES[$this->deduction_type] ?? $this->deduction_type;
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }

    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function deductions(): HasMany
    {
        return $this->hasMany(DriverArrearsLoanDeduction::class, 'arrears_loan_id')->orderBy('year')->orderBy('month');
    }
}
