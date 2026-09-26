<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

/**
 * A category for My Expenses. Expenses refer to it by `key` — a slug fixed
 * when the category is made — so renaming one (`name`) never disturbs the
 * expenses filed under it.
 */
#[Fillable(['name', 'key'])]
class MyExpenseCategory extends Model
{
    /** Longest name the form accepts. */
    public const NAME_MAX = 60;

    /** What the category dropdown submits when "Add new category…" is picked. */
    public const NEW_OPTION = '__new__';

    public function expenses(): HasMany
    {
        return $this->hasMany(MyExpense::class, 'category', 'key');
    }

    /** Trims and collapses inner whitespace, so "  Bank   fees " and "Bank fees" are the same name. */
    public static function tidy(string $name): string
    {
        return trim(preg_replace('/\s+/u', ' ', $name));
    }

    /** The category with this name, ignoring case and stray spacing — or null. */
    public static function findByName(string $name): ?self
    {
        return static::query()->whereRaw('LOWER(name) = ?', [mb_strtolower(self::tidy($name))])->first();
    }

    public static function findOrCreateNamed(string $name): self
    {
        $name = self::tidy($name);

        return self::findByName($name) ?? static::create(['name' => $name, 'key' => self::uniqueKeyFor($name)]);
    }

    /** A slug for the name that no other category already has ("bank-fees", then "bank-fees-2"…). */
    public static function uniqueKeyFor(string $name): string
    {
        // A name with no Latin letters or digits slugs to nothing at all.
        $base = Str::slug($name) ?: 'category';
        $key = $base;

        for ($n = 2; static::query()->where('key', $key)->exists(); $n++) {
            $key = "{$base}-{$n}";
        }

        return $key;
    }
}
