<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\OtherCompanyRevenue;
use App\Services\OtherCompanyRevenueService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

/**
 * Adding, editing and deleting revenue from other rental companies. It lives
 * on the My Expenses & Income page, so it is guarded by the same
 * permissions as its other tabs: "create", "update" and "delete" under
 * my-expenses.*.
 */
class OtherCompanyRevenueController extends Controller implements HasMiddleware
{
    public function __construct(private readonly OtherCompanyRevenueService $revenues) {}

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
        $revenue = OtherCompanyRevenue::create($this->revenues->validated($request));

        return $this->backToMonthOf($revenue, "Revenue \"{$revenue->hire}\" was added.");
    }

    public function update(Request $request, OtherCompanyRevenue $otherCompanyRevenue): RedirectResponse
    {
        $otherCompanyRevenue->update($this->revenues->validated($request));

        return $this->backToMonthOf($otherCompanyRevenue, "Revenue \"{$otherCompanyRevenue->hire}\" was updated.");
    }

    public function destroy(OtherCompanyRevenue $otherCompanyRevenue): RedirectResponse
    {
        $otherCompanyRevenue->delete();

        return $this->backToMonthOf($otherCompanyRevenue, "Revenue \"{$otherCompanyRevenue->hire}\" was deleted.");
    }

    /**
     * Straight back to the revenue tab of the month the entry is in —
     * otherwise adding one dated last month would leave the page showing
     * nothing new.
     */
    private function backToMonthOf(OtherCompanyRevenue $revenue, string $status): RedirectResponse
    {
        return redirect()
            ->route('admin.my-expenses.index', ['tab' => 'revenue', 'year' => $revenue->revenue_date->year, 'month' => $revenue->revenue_date->month])
            ->with('status', $status);
    }
}
