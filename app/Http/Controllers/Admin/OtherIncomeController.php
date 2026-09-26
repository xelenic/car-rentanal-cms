<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\OtherIncome;
use App\Services\OtherIncomeService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

/**
 * Adding, editing and deleting the owner's other income (money that isn't a
 * hire). It lives on the My Expenses & Income page, so it is guarded by the
 * same permissions: "create", "update" and "delete" under my-expenses.*.
 */
class OtherIncomeController extends Controller implements HasMiddleware
{
    public function __construct(private readonly OtherIncomeService $incomes) {}

    public static function middleware(): array
    {
        return [
            new Middleware('permission:my-expenses.create', only: ['store']),
            new Middleware('permission:my-expenses.update', only: ['update']),
            new Middleware('permission:my-expenses.delete', only: ['destroy']),
        ];
    }

    public function store(Request $request): RedirectResponse
    {
        $income = OtherIncome::create($this->incomes->validated($request));

        return $this->backToMonthOf($income, "Income \"{$income->title}\" was added.");
    }

    public function update(Request $request, OtherIncome $otherIncome): RedirectResponse
    {
        $otherIncome->update($this->incomes->validated($request));

        return $this->backToMonthOf($otherIncome, "Income \"{$otherIncome->title}\" was updated.");
    }

    public function destroy(OtherIncome $otherIncome): RedirectResponse
    {
        $otherIncome->delete();

        return $this->backToMonthOf($otherIncome, "Income \"{$otherIncome->title}\" was deleted.");
    }

    /**
     * Straight back to the income tab of the month the entry is in — otherwise
     * adding one dated last month would leave the page showing nothing new.
     */
    private function backToMonthOf(OtherIncome $income, string $status): RedirectResponse
    {
        return redirect()
            ->route('admin.my-expenses.index', ['tab' => 'income', 'year' => $income->income_date->year, 'month' => $income->income_date->month])
            ->with('status', $status);
    }
}
