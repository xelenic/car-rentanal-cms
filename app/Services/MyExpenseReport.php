<?php

namespace App\Services;

use App\Models\Hire;
use App\Models\MyExpense;
use App\Models\MyExpenseCategory;
use App\Models\OtherIncome;
use App\Support\MonthlyPeriods;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;

/**
 * One month of My Expenses and Other Income, and what My Profit comes to:
 * the month's profit from hires, plus other income, less the owner's own
 * expenses. The numbers behind both the web page and the admin app's cards.
 */
class MyExpenseReport
{
    /**
     * Always the whole month: a category filter or search only ever narrows
     * the list, never these figures.
     *
     * `profit_before_expenses` is the profit from hires alone (the dashboard's
     * Total Profit) — before both the owner's expenses and other income.
     *
     * @return array{
     *     total: float, record_count: int, by_category: Collection<string, float>,
     *     other_income_total: float, other_income_count: int,
     *     profit: array<string, mixed>, profit_before_expenses: float, my_profit: float
     * }
     */
    public static function forMonth(int $year, int $month): array
    {
        $monthExpenses = MyExpense::query()->inMonth($year, $month);

        $total = round((float) (clone $monthExpenses)->sum('amount'), 2);
        $byCategory = (clone $monthExpenses)
            ->selectRaw('category, SUM(amount) as total')
            ->groupBy('category')
            ->orderByDesc('total')
            ->pluck('total', 'category')
            ->map(fn ($amount) => round((float) $amount, 2));

        $monthIncome = OtherIncome::query()->inMonth($year, $month);
        $otherIncomeTotal = round((float) (clone $monthIncome)->sum('amount'), 2);

        $profit = ProfitCalculator::breakdownFor($year, $month);

        return [
            'total' => $total,
            'record_count' => (clone $monthExpenses)->count(),
            'by_category' => $byCategory,
            'other_income_total' => $otherIncomeTotal,
            'other_income_count' => (clone $monthIncome)->count(),
            'profit' => $profit,
            'profit_before_expenses' => $profit['profit_total'],
            'my_profit' => round($profit['profit_total'] + $otherIncomeTotal - $total, 2),
        ];
    }

    /**
     * The month's figures as the admin app's cards and "how is this worked out"
     * sheet want them — the same block whichever list (expenses or other
     * income) is being fetched, so the cards stay right after any change.
     *
     * @param  Collection<string, string>|null  $categoryNames  key => name, if the caller already has them
     * @return array<string, mixed>
     */
    public static function summaryFor(int $year, int $month, ?Collection $categoryNames = null): array
    {
        $report = self::forMonth($year, $month);
        $categoryNames ??= MyExpenseCategory::query()->pluck('name', 'key');

        return [
            'year' => $year,
            'month' => $month,
            'label' => now()->setDate($year, $month, 1)->format('F Y'),
            'total' => $report['total'],
            'record_count' => $report['record_count'],
            // The profit from hires alone; My Profit adds the other income and takes the expenses off.
            'profit_before_expenses' => $report['profit_before_expenses'],
            'other_income_total' => $report['other_income_total'],
            'other_income_count' => $report['other_income_count'],
            'my_profit' => $report['my_profit'],
            'by_category' => $report['by_category']->map(fn (float $total, string $key) => [
                'key' => $key,
                'name' => $categoryNames->get($key) ?? str($key)->headline()->toString(),
                'total' => $total,
            ])->values(),
            // The working behind the profit figure.
            'breakdown' => Arr::only($report['profit'], [
                'our_hire_value_total', 'expenses_total', 'net_before_salary', 'salary_percentage',
                'salary_total', 'leasing_installment_total', 'repair_cost_total', 'profit_total',
            ]),
        ];
    }

    /**
     * Years to pick from: any with an expense, other income or a hire, plus the one being
     * viewed and this one — so an empty month of the current year is always reachable.
     *
     * @return array<int, int>
     */
    public static function availableYears(int $selectedYear): array
    {
        $expenseYears = MyExpense::query()->pluck('expense_date')->map(fn ($date) => $date->year)
            ->merge(OtherIncome::query()->pluck('income_date')->map(fn ($date) => $date->year));
        $hireYears = MonthlyPeriods::fromTimestamps(
            Hire::query()->get(['start_time', 'created_at'])->pluck('effective_month_date')
        )['years'];

        return collect($expenseYears)->merge($hireYears)->push($selectedYear)->push((int) now()->format('Y'))
            ->unique()->sortDesc()->values()->all();
    }

    /**
     * The year and month to show: what was asked for, else this month. A
     * month outside 1–12 counts as not asked for.
     *
     * @return array{0: int, 1: int}
     */
    public static function periodFrom(?int $year, ?int $month): array
    {
        $now = now();

        return [
            $year ?: (int) $now->format('Y'),
            $month !== null && $month >= 1 && $month <= 12 ? $month : (int) $now->format('n'),
        ];
    }
}
