<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\MyExpense;
use App\Models\MyExpenseCategory;
use App\Models\OtherIncome;
use App\Services\MyExpenseReport;
use App\Services\MyExpenseService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

/**
 * The owner's own expenses and other income, month by month, and My Profit —
 * the month's profit from hires plus other income, less the expenses (see
 * ProfitCalculator and MyExpenseReport). One page, two tabs; the expenses
 * and the other income are edited by the same permissions.
 */
class MyExpenseController extends Controller implements HasMiddleware
{
    public function __construct(private readonly MyExpenseService $expenses) {}

    public static function middleware(): array
    {
        return [
            new Middleware('permission:my-expenses.view', only: ['index']),
            new Middleware('permission:my-expenses.create', only: ['store']),
            new Middleware('permission:my-expenses.update', only: ['update']),
            new Middleware('permission:my-expenses.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $now = now();
        [$year, $month] = MyExpenseReport::periodFrom($request->integer('year') ?: null, $request->has('month') ? $request->integer('month') : null);
        $tab = $request->string('tab')->toString() === 'income' ? 'income' : 'expenses';
        $categoryList = MyExpenseCategory::query()->withCount('expenses')->orderBy('name')->get();
        $categories = $categoryList->pluck('name', 'key');
        $category = $request->string('category')->toString();
        // A category only narrows the expenses; on the income tab it is ignored.
        $category = $tab === 'expenses' && $categories->has($category) ? $category : null;
        $search = $request->string('search')->toString();

        $report = MyExpenseReport::forMonth($year, $month);

        // Only the tab on show is listed, and paged.
        $expenses = null;
        $filteredTotal = 0.0;
        $incomes = null;
        $filteredIncomeTotal = 0.0;

        if ($tab === 'income') {
            $incomeQuery = OtherIncome::query()->inMonth($year, $month)->matching($search);
            $incomes = (clone $incomeQuery)->orderByDesc('income_date')->orderByDesc('id')->paginate(15)->withQueryString();
            $filteredIncomeTotal = round((float) $incomeQuery->sum('amount'), 2);
        } else {
            $listQuery = MyExpense::query()->inMonth($year, $month)->matching($category, $search);
            $expenses = (clone $listQuery)->with('categoryRecord')->orderByDesc('expense_date')->orderByDesc('id')->paginate(15)->withQueryString();
            $filteredTotal = round((float) $listQuery->sum('amount'), 2);
        }

        return view('admin.my-expenses.index', [
            'tab' => $tab,
            'expenses' => $expenses,
            'filteredTotal' => $filteredTotal,
            'incomes' => $incomes,
            'filteredIncomeTotal' => $filteredIncomeTotal,
            'otherIncomeTotal' => $report['other_income_total'],
            'otherIncomeCount' => $report['other_income_count'],
            'total' => $report['total'],
            'recordCount' => $report['record_count'],
            'byCategory' => $report['by_category'],
            'profitBeforeExpenses' => $report['profit_before_expenses'],
            'myProfit' => $report['my_profit'],
            'profitBreakdown' => $report['profit'],
            'categories' => $categories,
            'categoryList' => $categoryList,
            // A new expense starts under "Others" if there is one, else the first category.
            'defaultCategory' => $categories->has('others') ? 'others' : $categories->keys()->first(),
            'selectedCategory' => $category,
            'search' => $search,
            'selectedYear' => $year,
            'selectedMonth' => $month,
            'availableYears' => MyExpenseReport::availableYears($year),
            'periodLabel' => $now->copy()->setDate($year, $month, 1)->format('F Y'),
            // A new expense starts dated today if today is in the month being viewed, else the 1st of it.
            'defaultDate' => ($year === (int) $now->format('Y') && $month === (int) $now->format('n') ? $now->copy() : $now->copy()->setDate($year, $month, 1))->format('Y-m-d'),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $expense = DB::transaction(fn () => MyExpense::create($this->expenses->validated($request)));

        return $this->backToMonthOf($expense, "Expense \"{$expense->title}\" was added.");
    }

    public function update(Request $request, MyExpense $myExpense): RedirectResponse
    {
        DB::transaction(fn () => $myExpense->update($this->expenses->validated($request)));

        return $this->backToMonthOf($myExpense, "Expense \"{$myExpense->title}\" was updated.");
    }

    public function destroy(MyExpense $myExpense): RedirectResponse
    {
        $myExpense->delete();

        return $this->backToMonthOf($myExpense, "Expense \"{$myExpense->title}\" was deleted.");
    }

    /**
     * Straight back to the month the expense is in — otherwise adding one
     * dated last month would leave the page on this month with nothing to show.
     */
    private function backToMonthOf(MyExpense $expense, string $status): RedirectResponse
    {
        return redirect()
            ->route('admin.my-expenses.index', ['year' => $expense->expense_date->year, 'month' => $expense->expense_date->month])
            ->with('status', $status);
    }
}
