<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['driver_id', 'amount', 'reason', 'status', 'deduction_type', 'admin_note', 'reviewed_by', 'reviewed_at'])]
class SalaryAdvanceRequest extends Model
{
    public const STATUSES = [
        'pending' => 'Pending',
        'approved' => 'Approved',
        'rejected' => 'Rejected',
    ];

    public const DEDUCTION_TYPES = [
        'full' => 'Full amount this month',
        'installments' => 'Split across upcoming months',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'reviewed_at' => 'datetime',
        ];
    }

    public function getStatusLabelAttribute(): string
    {
        return self::STATUSES[$this->status] ?? $this->status;
    }

    public function getDeductionTypeLabelAttribute(): ?string
    {
        return $this->deduction_type ? (self::DEDUCTION_TYPES[$this->deduction_type] ?? $this->deduction_type) : null;
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function deductions(): HasMany
    {
        return $this->hasMany(SalaryAdvanceDeduction::class)->orderBy('year')->orderBy('month');
    }
}
