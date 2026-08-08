<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One month's scheduled installment against an approved salary advance —
 * deducted from that driver's calculated salary for the given year/month.
 */
#[Fillable(['salary_advance_request_id', 'driver_id', 'year', 'month', 'amount'])]
class SalaryAdvanceDeduction extends Model
{
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
        ];
    }

    public function salaryAdvanceRequest(): BelongsTo
    {
        return $this->belongsTo(SalaryAdvanceRequest::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }
}
