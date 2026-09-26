<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

/**
 * One of the owner's own costs — rent, utilities, marketing… Not to be
 * confused with HireExpense, which is what a driver spends on a hire.
 */
#[Fillable(['title', 'category', 'amount', 'expense_date', 'notes'])]
class MyExpense extends Model
{
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'expense_date' => 'date',
        ];
    }

    public function categoryRecord(): BelongsTo
    {
        return $this->belongsTo(MyExpenseCategory::class, 'category', 'key');
    }

    /** The category's current name (renames show up on old expenses), or a tidied key if the category is gone. */
    public function getCategoryLabelAttribute(): string
    {
        return $this->categoryRecord?->name ?? Str::headline($this->category);
    }

    /** Narrows to one category key and/or a search of the title and notes. Blank means no narrowing. */
    public function scopeMatching(Builder $query, ?string $category, ?string $search): Builder
    {
        return $query
            ->when($category, fn (Builder $query) => $query->where('category', $category))
            ->when($search, function (Builder $query, string $search) {
                $query->where(fn (Builder $query) => $query->where('title', 'like', "%{$search}%")->orWhere('notes', 'like', "%{$search}%"));
            });
    }

    /** Expenses dated within one calendar month. */
    public function scopeInMonth(Builder $query, int $year, int $month): Builder
    {
        return $query->whereYear('expense_date', $year)->whereMonth('expense_date', $month);
    }
}
