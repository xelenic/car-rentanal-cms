<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Models\HireExpense;
use App\Support\MonthlyPeriods;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;

class ExpenseController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:hires.view', only: ['index']),
        ];
    }

    public function index(Request $request): View
    {
        $driverId = $request->integer('driver_id') ?: null;
        $category = $request->string('category')->toString() ?: null;
        // 'with_hire' | 'without_hire' | null (all)
        $attribution = $request->string('attribution')->toString() ?: null;

        $expenses = HireExpense::query()
            ->with(['driver', 'hire'])
            ->when($driverId, fn ($query) => $query->where('driver_id', $driverId))
            ->when($category, fn ($query) => $query->where('category', $category))
            ->when($attribution === 'with_hire', fn ($query) => $query->whereNotNull('hire_id'))
            ->when($attribution === 'without_hire', fn ($query) => $query->whereNull('hire_id'))
            ->when($request->filled('year'), fn ($query) => $query->whereYear('created_at', $request->integer('year')))
            ->when($request->filled('month'), fn ($query) => $query->whereMonth('created_at', $request->integer('month')))
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->whereHas('driver', fn ($query) => $query->where('name', 'like', "%{$search}%"));
            })
            ->latest()
            ->get();

        $totalExpenses = round((float) $expenses->sum('amount'), 2);
        $withHireExpenses = $expenses->whereNotNull('hire_id');
        $withoutHireExpenses = $expenses->whereNull('hire_id');
        $withHireTotal = round((float) $withHireExpenses->sum('amount'), 2);
        $withoutHireTotal = round((float) $withoutHireExpenses->sum('amount'), 2);

        $byDriver = $expenses->groupBy('driver_id')->map(function ($group) {
            return [
                'driver' => $group->first()->driver,
                'count' => $group->count(),
                'total' => round((float) $group->sum('amount'), 2),
                'without_hire_total' => round((float) $group->whereNull('hire_id')->sum('amount'), 2),
            ];
        })->filter(fn ($row) => $row['driver'] !== null)->sortByDesc('total')->values();

        $byHire = $withHireExpenses->groupBy('hire_id')->map(function ($group) {
            $hire = $group->first()->hire;

            return [
                'hire' => $hire,
                'driver' => $group->first()->driver,
                'count' => $group->count(),
                'total' => round((float) $group->sum('amount'), 2),
            ];
        })->filter(fn ($row) => $row['hire'] !== null)->sortByDesc('total')->values();

        $byCategory = $expenses->groupBy('category')->map(fn ($group) => round((float) $group->sum('amount'), 2))
            ->sortDesc();

        $periods = MonthlyPeriods::fromTimestamps(HireExpense::query()->pluck('created_at'));

        return view('admin.expenses.index', [
            'totalExpenses' => $totalExpenses,
            'withHireTotal' => $withHireTotal,
            'withoutHireTotal' => $withoutHireTotal,
            'recordCount' => $expenses->count(),
            'byDriver' => $byDriver,
            'byHire' => $byHire,
            'byCategory' => $byCategory,
            'withoutHireExpenses' => $withoutHireExpenses->values(),
            'trend' => $this->trend(),
            'drivers' => Driver::query()->orderBy('name')->get(['id', 'name']),
            'categories' => HireExpense::CATEGORIES,
            'selectedDriverId' => $driverId,
            'selectedCategory' => $category,
            'selectedAttribution' => $attribution,
            'search' => $request->string('search')->toString(),
            'selectedYear' => $request->integer('year') ?: null,
            'selectedMonth' => $request->integer('month') ?: null,
            'availableYears' => $periods['years'],
            'monthsByYear' => $periods['months_by_year'],
        ]);
    }

    /**
     * Trailing 6-month totals split by with-hire vs without-hire, for the
     * trend chart.
     */
    private function trend(): array
    {
        $months = collect(range(5, 0))->map(fn ($monthsAgo) => now()->subMonthsNoOverflow($monthsAgo));

        return $months->map(function ($date) {
            $year = (int) $date->format('Y');
            $month = (int) $date->format('n');

            $monthExpenses = HireExpense::query()
                ->whereYear('created_at', $year)
                ->whereMonth('created_at', $month)
                ->get(['hire_id', 'amount']);

            return [
                'label' => $date->format('M Y'),
                'with_hire' => round((float) $monthExpenses->whereNotNull('hire_id')->sum('amount'), 2),
                'without_hire' => round((float) $monthExpenses->whereNull('hire_id')->sum('amount'), 2),
            ];
        })->values()->all();
    }
}
