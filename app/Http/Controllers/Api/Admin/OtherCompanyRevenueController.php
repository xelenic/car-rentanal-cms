<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\OtherCompanyRevenueResource;
use App\Models\OtherCompanyRevenue;
use App\Services\MyExpenseReport;
use App\Services\OtherCompanyRevenueService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Storage;

/**
 * The admin mobile app's Revenue-from-other-companies API: a month's entries
 * with the same "summary" block as the expenses/income lists, and adding,
 * editing and deleting one — each optionally with a bank slip photo. It sits
 * under the My Expenses & Income page, so it uses the same permissions
 * (my-expenses.*) as Expenses and Other Income.
 */
class OtherCompanyRevenueController extends Controller
{
    private const PER_PAGE = 20;

    private const MAX_PER_PAGE = 50;

    public function __construct(private readonly OtherCompanyRevenueService $revenues) {}

    /**
     * One month's revenue from other companies, newest first. The "summary"
     * always covers the whole month; a search only narrows the list (and
     * gives "filtered_total" — the credited total of what's shown).
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize($request, 'view', 'view revenue');

        $filters = $request->validate([
            'year' => ['nullable', 'integer', 'min:2000', 'max:2100'],
            'month' => ['nullable', 'integer', 'min:1', 'max:12'],
            'search' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:'.self::MAX_PER_PAGE],
        ]);

        [$year, $month] = MyExpenseReport::periodFrom($filters['year'] ?? null, $filters['month'] ?? null);

        $listQuery = OtherCompanyRevenue::query()->inMonth($year, $month)->matching($filters['search'] ?? null);

        $revenues = (clone $listQuery)
            ->orderByDesc('revenue_date')
            ->orderByDesc('id')
            ->paginate((int) ($filters['per_page'] ?? self::PER_PAGE));

        return OtherCompanyRevenueResource::collection($revenues)->additional([
            'summary' => MyExpenseReport::summaryFor($year, $month),
            'filtered_total' => round((float) $listQuery->sum('credited_amount'), 2),
            'years' => MyExpenseReport::availableYears($year),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorize($request, 'create', 'add revenue');

        $data = $this->revenues->validated($request);
        unset($data['slip']);
        $data['slip_path'] = $this->revenues->storeSlip($request);

        $revenue = OtherCompanyRevenue::create($data);

        return (new OtherCompanyRevenueResource($revenue))->response()->setStatusCode(201);
    }

    public function update(Request $request, OtherCompanyRevenue $otherCompanyRevenue): OtherCompanyRevenueResource
    {
        $this->authorize($request, 'update', 'edit revenue');

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

        return new OtherCompanyRevenueResource($otherCompanyRevenue->fresh());
    }

    public function destroy(Request $request, OtherCompanyRevenue $otherCompanyRevenue): JsonResponse
    {
        $this->authorize($request, 'delete', 'delete revenue');

        if ($otherCompanyRevenue->slip_path) {
            Storage::disk('public')->delete($otherCompanyRevenue->slip_path);
        }
        $otherCompanyRevenue->delete();

        return response()->json(['message' => "Revenue \"{$otherCompanyRevenue->hire}\" was deleted."]);
    }

    private function authorize(Request $request, string $ability, string $what): void
    {
        abort_unless($request->user()->can("my-expenses.{$ability}"), 403, "You do not have permission to {$what}.");
    }
}
