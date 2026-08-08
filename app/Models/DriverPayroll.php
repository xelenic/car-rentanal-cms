<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'driver_id', 'year', 'month', 'hire_count', 'our_hire_value_total',
    'expenses_total', 'salary', 'advance_deduction_total', 'carryover_deduction_total',
    'arrears_deduction_total', 'deposit_balance', 'arrears_loan_offset', 'net_before_adjustment',
    'manual_adjustment', 'adjustment_note', 'final_amount',
    'status', 'finalized_by', 'finalized_at', 'paid_by', 'paid_at',
])]
class DriverPayroll extends Model
{
    public const STATUSES = [
        'finalized' => 'Finalized',
        'paid' => 'Paid',
    ];

    protected function casts(): array
    {
        return [
            'our_hire_value_total' => 'decimal:2',
            'expenses_total' => 'decimal:2',
            'salary' => 'decimal:2',
            'advance_deduction_total' => 'decimal:2',
            'carryover_deduction_total' => 'decimal:2',
            'arrears_deduction_total' => 'decimal:2',
            'deposit_balance' => 'decimal:2',
            'arrears_loan_offset' => 'decimal:2',
            'net_before_adjustment' => 'decimal:2',
            'manual_adjustment' => 'decimal:2',
            'final_amount' => 'decimal:2',
            'finalized_at' => 'datetime',
            'paid_at' => 'datetime',
        ];
    }

    public function getStatusLabelAttribute(): string
    {
        return self::STATUSES[$this->status] ?? $this->status;
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }

    public function finalizedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'finalized_by');
    }

    public function paidBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'paid_by');
    }
}
