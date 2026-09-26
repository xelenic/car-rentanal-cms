<?php

namespace App\Services;

use App\Models\MyExpenseCategory;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Validating what the "add/edit expense" form (web) and the admin app send —
 * one set of rules, so the two can't disagree.
 */
class MyExpenseService
{
    /**
     * The expense's fields, with `category` resolved to a category key. Picking
     * "Add new category…" (MyExpenseCategory::NEW_OPTION) carries the new name
     * in `new_category`; it is found (ignoring case) or created here, so a
     * category can be made right from the expense form. Throws a
     * ValidationException — before touching the categories — if anything is wrong.
     *
     * @return array{title: string, category: string, amount: string|float, expense_date: string, notes: ?string}
     */
    public function validated(Request $request): array
    {
        $isNewCategory = $request->input('category') === MyExpenseCategory::NEW_OPTION;

        if ($isNewCategory) {
            $request->merge(['new_category' => MyExpenseCategory::tidy((string) $request->input('new_category'))]);
        }

        $data = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', Rule::when(! $isNewCategory, [Rule::exists('my_expense_categories', 'key')])],
            'new_category' => [Rule::requiredIf($isNewCategory), 'nullable', 'string', 'max:'.MyExpenseCategory::NAME_MAX],
            'amount' => ['required', 'numeric', 'min:0.01', 'max:9999999999.99'],
            'expense_date' => ['required', 'date'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ], ['new_category.required' => 'Type a name for the new category.']);

        if ($isNewCategory) {
            $data['category'] = MyExpenseCategory::findOrCreateNamed($data['new_category'])->key;
        }

        unset($data['new_category']);

        return $data;
    }
}
