<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Revenue from a booking made through another rental company — see the
 * migration. Every field is entered by hand (there's no link to our own
 * Hire records); counts toward the month it's dated in, and the credited
 * amount adds to My Profit, same as OtherIncome.
 */
#[Fillable(['hire', 'booking_number', 'vehicle', 'full_amount', 'credited_amount', 'balance', 'vehicle_amount', 'revenue_date'])]
class OtherCompanyRevenue extends Model
{
    protected function casts(): array
    {
        return [
            'full_amount' => 'decimal:2',
            'credited_amount' => 'decimal:2',
            'balance' => 'decimal:2',
            'vehicle_amount' => 'decimal:2',
            'revenue_date' => 'date',
        ];
    }

    /** Narrows to entries whose hire, booking number or vehicle contain the search. Blank means no narrowing. */
    public function scopeMatching(Builder $query, ?string $search): Builder
    {
        return $query->when($search, function (Builder $query, string $search) {
            $query->where(fn (Builder $query) => $query
                ->where('hire', 'like', "%{$search}%")
                ->orWhere('booking_number', 'like', "%{$search}%")
                ->orWhere('vehicle', 'like', "%{$search}%"));
        });
    }

    /** Revenue dated within one calendar month. */
    public function scopeInMonth(Builder $query, int $year, int $month): Builder
    {
        return $query->whereYear('revenue_date', $year)->whereMonth('revenue_date', $month);
    }
}
