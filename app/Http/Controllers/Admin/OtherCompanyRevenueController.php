<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\OtherCompanyRevenue;
use App\Services\OtherCompanyRevenueService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Storage;

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
        $data = $this->revenues->validated($request);
        unset($data['slip']);
        $data['slip_path'] = $this->revenues->storeSlip($request);

        $revenue = OtherCompanyRevenue::create($data);

        return $this->backToMonthOf($revenue, "Revenue \"{$revenue->hire}\" was added.");
    }

    public function update(Request $request, OtherCompanyRevenue $otherCompanyRevenue): RedirectResponse
    {
        $data = $this->revenues->validated($request);
        unset($data['slip']);

        $newSlipPath = $this->revenues->storeSlip($request);
        if ($newSlipPath !== null) {
            if ($otherCompanyRevenue->slip_path) {
                Storage::disk('public')->delete($otherCompanyRevenue->slip_path);
            }
            $data['slip_path'] = $newSlipPath;
        }

        $otherCompanyRevenue->update($data);

        return $this->backToMonthOf($otherCompanyRevenue, "Revenue \"{$otherCompanyRevenue->hire}\" was updated.");
    }

    public function destroy(OtherCompanyRevenue $otherCompanyRevenue): RedirectResponse
    {
        if ($otherCompanyRevenue->slip_path) {
            Storage::disk('public')->delete($otherCompanyRevenue->slip_path);
        }
        $otherCompanyRevenue->delete();

        return $this->backToMonthOf($otherCompanyRevenue, "Revenue \"{$otherCompanyRevenue->hire}\" was deleted.");
    }

    /**
     * Streams the bank slip image — unauthenticated, like the other document
     * routes in this app (hire-expenses receipts, vehicle-maintenance bills,
     * driver deposit-transfer slips): reachable by anyone who knows the id.
     */
    public function slip(OtherCompanyRevenue $otherCompanyRevenue): Response
    {
        abort_unless(
            $otherCompanyRevenue->slip_path && Storage::disk('public')->exists($otherCompanyRevenue->slip_path),
            404
        );

        return response(
            Storage::disk('public')->get($otherCompanyRevenue->slip_path),
            200,
            ['Content-Type' => Storage::disk('public')->mimeType($otherCompanyRevenue->slip_path)]
        );
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
