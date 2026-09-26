<?php

namespace App\Services;

use App\Models\Hire;
use App\Models\MyExpense;
use App\Support\MonthlyPeriods;
use Illuminate\Support\Collection;

/**
 * One month of My Expenses and what is left of that month's profit after
 * them — the numbers behind both the web page and the admin app's cards.
 */
class MyExpenseReport
{
    /**
     * Always the whole month: a category filter or search only ever narrows
     * the list, never these figures.
     *
     * @return array{
     *     total: float, record_count: int, by_category: Collection<string, float>,
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

        $profit = ProfitCalculator::breakdownFor($year, $month);

        return [
            'total' => $total,
            'record_count' => (clone $monthExpenses)->count(),
            'by_category' => $byCategory,
            'profit' => $profit,
            'profit_before_expenses' => $profit['profit_total'],
            'my_profit' => round($profit['profit_total'] - $total, 2),
        ];
    }

    /**
     * Years to pick from: any with an expense or a hire, plus the one being
     * viewed and this one — so an empty month of the current year is always reachable.
     *
     * @return array<int, int>
     */
    public static function availableYears(int $selectedYear): array
    {
        $expenseYears = MyExpense::query()->pluck('expense_date')->map(fn ($date) => $date->year);
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
