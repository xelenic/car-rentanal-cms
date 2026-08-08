<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A vehicle financing record — either a Leasing facility (the finance
 * company holds ownership until fully paid, common for "hire purchase"
 * style vehicle financing) or a Loan (the vehicle is owned outright and
 * money was borrowed against it).
 */
#[Fillable([
    'vehicle_id', 'type', 'company', 'agreement_number', 'loan_amount',
    'monthly_installment', 'interest_rate', 'balance_remaining',
    'start_date', 'term_months', 'end_date', 'status', 'notes',
])]
class VehicleLeasing extends Model
{
    public const TYPES = [
        'leasing' => 'Leasing',
        'loan' => 'Loan',
    ];

    public const STATUSES = [
        'active' => 'Active',
        'completed' => 'Completed',
        'defaulted' => 'Defaulted',
    ];

    protected function casts(): array
    {
        return [
            'loan_amount' => 'decimal:2',
            'monthly_installment' => 'decimal:2',
            'interest_rate' => 'decimal:2',
            'balance_remaining' => 'decimal:2',
            'start_date' => 'date',
            'end_date' => 'date',
            'term_months' => 'integer',
        ];
    }

    public function getTypeLabelAttribute(): string
    {
        return self::TYPES[$this->type] ?? $this->type;
    }

    public function getStatusLabelAttribute(): string
    {
        return self::STATUSES[$this->status] ?? $this->status;
    }

    /**
     * How much of the loan has been paid off, as a percentage (0-100).
     */
    public function getProgressPercentAttribute(): float
    {
        if ((float) $this->loan_amount <= 0) {
            return 0.0;
        }

        $paid = (float) $this->loan_amount - (float) $this->balance_remaining;

        return round(max(0, min(100, ($paid / (float) $this->loan_amount) * 100)), 1);
    }

    public function vehicle(): BelongsTo
    {
        return $this->belongsTo(Vehicle::class);
    }

    public function settlements(): HasMany
    {
        return $this->hasMany(VehicleLeasingSettlement::class, 'leasing_id')
            ->orderByDesc('year')
            ->orderByDesc('month');
    }
}
