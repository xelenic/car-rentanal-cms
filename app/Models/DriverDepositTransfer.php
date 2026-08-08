<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['driver_id', 'year', 'month', 'amount', 'slip_path'])]
class DriverDepositTransfer extends Model
{
    protected function casts(): array
    {
        return [
            'year' => 'integer',
            'month' => 'integer',
            'amount' => 'decimal:2',
        ];
    }

    public function getSlipUrlAttribute(): ?string
    {
        return $this->slip_path ? route('driver-deposit-transfers.slip', $this) : null;
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }
}
