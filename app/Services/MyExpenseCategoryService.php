<?php

namespace App\Services;

use App\Models\MyExpenseCategory;
use Closure;
use Illuminate\Http\Request;

/**
 * Adding, renaming and removing My Expenses categories — the rules shared by
 * the web panel and the admin app.
 */
class MyExpenseCategoryService
{
    public function create(Request $request): MyExpenseCategory
    {
        $name = $this->validatedName($request);

        return MyExpenseCategory::create(['name' => $name, 'key' => MyExpenseCategory::uniqueKeyFor($name)]);
    }

    /** Only the name changes — the key is what expenses point at, so they follow the rename. */
    public function rename(MyExpenseCategory $category, Request $request): MyExpenseCategory
    {
        $category->update(['name' => $this->validatedName($request, $category)]);

        return $category;
    }

    /**
     * Deletes the category unless expenses are filed under it.
     *
     * @return string|null why it wasn't deleted, or null when it was
     */
    public function delete(MyExpenseCategory $category): ?string
    {
        $inUse = $category->expenses()->count();

        if ($inUse > 0) {
            return "\"{$category->name}\" is used by {$inUse} ".str('expense')->plural($inUse).' — move or delete them first.';
        }

        $category->delete();

        return null;
    }

    /** The tidied name, required and not already taken by another category (ignoring case). */
    private function validatedName(Request $request, ?MyExpenseCategory $current = null): string
    {
        $request->merge(['name' => MyExpenseCategory::tidy((string) $request->input('name'))]);

        return $request->validate([
            'name' => [
                'required', 'string', 'max:'.MyExpenseCategory::NAME_MAX,
                function (string $attribute, mixed $value, Closure $fail) use ($current) {
                    $existing = MyExpenseCategory::findByName($value);

                    if ($existing && $existing->id !== $current?->id) {
                        $fail('A category with this name already exists.');
                    }
                },
            ],
        ])['name'];
    }
}
