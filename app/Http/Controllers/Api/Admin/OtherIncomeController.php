<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\OtherIncomeResource;
use App\Models\OtherIncome;
use App\Services\MyExpenseReport;
use App\Services\OtherIncomeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * The admin mobile app's Other Income API: a month's income entries (money
 * that isn't a hire) with the same "summary" block as the expenses list, and
 * adding, editing and deleting one. It sits under the My Expenses & Income
 * page, so it uses the same permissions (my-expenses.*).
 */
class OtherIncomeController extends Controller
{
    private const PER_PAGE = 20;

    private const MAX_PER_PAGE = 50;

    public function __construct(private readonly OtherIncomeService $incomes) {}

    /**
     * One month's other income, newest first. The "summary" always covers the
     * whole month; a search only narrows the list (and gives "filtered_total").
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize($request, 'view', 'view income');

        $filters = $request->validate([
            'year' => ['nullable', 'integer', 'min:2000', 'max:2100'],
            'month' => ['nullable', 'integer', 'min:1', 'max:12'],
            'search' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:'.self::MAX_PER_PAGE],
        ]);

        [$year, $month] = MyExpenseReport::periodFrom($filters['year'] ?? null, $filters['month'] ?? null);

        $listQuery = OtherIncome::query()->inMonth($year, $month)->matching($filters['search'] ?? null);

        $incomes = (clone $listQuery)
            ->orderByDesc('income_date')
            ->orderByDesc('id')
            ->paginate((int) ($filters['per_page'] ?? self::PER_PAGE));

        return OtherIncomeResource::collection($incomes)->additional([
            'summary' => MyExpenseReport::summaryFor($year, $month),
            'filtered_total' => round((float) $listQuery->sum('amount'), 2),
            'years' => MyExpenseReport::availableYears($year),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorize($request, 'create', 'add income');

        $income = OtherIncome::create($this->incomes->validated($request));

        return (new OtherIncomeResource($income))->response()->setStatusCode(201);
    }

    public function update(Request $request, OtherIncome $otherIncome): OtherIncomeResource
    {
        $this->authorize($request, 'update', 'edit income');

        $otherIncome->update($this->incomes->validated($request));

        return new OtherIncomeResource($otherIncome->fresh());
    }

    public function destroy(Request $request, OtherIncome $otherIncome): JsonResponse
    {
        $this->authorize($request, 'delete', 'delete income');

        $otherIncome->delete();

        return response()->json(['message' => "Income \"{$otherIncome->title}\" was deleted."]);
    }

    private function authorize(Request $request, string $ability, string $what): void
    {
        abort_unless($request->user()->can("my-expenses.{$ability}"), 403, "You do not have permission to {$what}.");
    }
}
