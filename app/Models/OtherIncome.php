<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Money the owner receives that isn't a hire — see the migration. Counts
 * toward the month it is dated in, and adds to My Profit.
 */
#[Fillable(['title', 'amount', 'income_date', 'notes'])]
class OtherIncome extends Model
{
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'income_date' => 'date',
        ];
    }

    /** Narrows to entries whose title or notes contain the search. Blank means no narrowing. */
    public function scopeMatching(Builder $query, ?string $search): Builder
    {
        return $query->when($search, function (Builder $query, string $search) {
            $query->where(fn (Builder $query) => $query->where('title', 'like', "%{$search}%")->orWhere('notes', 'like', "%{$search}%"));
        });
    }

    /** Income dated within one calendar month. */
    public function scopeInMonth(Builder $query, int $year, int $month): Builder
    {
        return $query->whereYear('income_date', $year)->whereMonth('income_date', $month);
    }
}
