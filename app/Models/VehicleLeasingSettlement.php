<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A single month's settlement (payment) made against a VehicleLeasing
 * record — the running total of these is what reduces the leasing's
 * balance_remaining.
 */
#[Fillable(['leasing_id', 'year', 'month', 'amount', 'notes'])]
class VehicleLeasingSettlement extends Model
{
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'year' => 'integer',
            'month' => 'integer',
        ];
    }

    public function getMonthLabelAttribute(): string
    {
        return Carbon::create($this->year, $this->month, 1)->format('F Y');
    }

    public function leasing(): BelongsTo
    {
        return $this->belongsTo(VehicleLeasing::class, 'leasing_id');
    }
}
