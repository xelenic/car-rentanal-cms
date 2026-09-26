<?php

namespace App\Services;

use Illuminate\Http\Request;

/**
 * Validating what the "add/edit income" form (web) and the admin app send —
 * one set of rules, so the two can't disagree.
 */
class OtherIncomeService
{
    /**
     * @return array{title: string, amount: string|float, income_date: string, notes: ?string}
     */
    public function validated(Request $request): array
    {
        return $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'amount' => ['required', 'numeric', 'min:0.01', 'max:9999999999.99'],
            'income_date' => ['required', 'date'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);
    }
}
