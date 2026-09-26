<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\MyExpenseResource;
use App\Models\MyExpense;
use App\Models\MyExpenseCategory;
use App\Services\MyExpenseReport;
use App\Services\MyExpenseService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

/**
 * The admin mobile app's My Expenses API: a month's expenses with the cards
 * above them (total, profit before, My Profit), and adding, editing and
 * deleting one. Permissions are checked directly, like the rest of the admin
 * API — these are Sanctum-token requests, not the web session the
 * permission:* middleware assumes.
 */
class MyExpenseController extends Controller
{
    private const PER_PAGE = 20;

    private const MAX_PER_PAGE = 50;

    public function __construct(private readonly MyExpenseService $expenses) {}

    /**
     * One month's expenses, newest first. The "summary" always covers the
     * whole month; a category or search only narrows the list (and gives
     * "filtered_total").
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize($request, 'view', 'view expenses');

        $filters = $request->validate([
            'year' => ['nullable', 'integer', 'min:2000', 'max:2100'],
            'month' => ['nullable', 'integer', 'min:1', 'max:12'],
            'category' => ['nullable', 'string', 'max:100'],
            'search' => ['nullable', 'string', 'max:100'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:'.self::MAX_PER_PAGE],
        ]);

        [$year, $month] = MyExpenseReport::periodFrom($filters['year'] ?? null, $filters['month'] ?? null);
        $categories = MyExpenseCategory::query()->pluck('name', 'key');
        // An unknown category is treated as no category, like the web page does.
        $category = isset($filters['category']) && $categories->has($filters['category']) ? $filters['category'] : null;

        $listQuery = MyExpense::query()->inMonth($year, $month)->matching($category, $filters['search'] ?? null);

        $expenses = (clone $listQuery)
            ->with('categoryRecord')
            ->orderByDesc('expense_date')
            ->orderByDesc('id')
            ->paginate((int) ($filters['per_page'] ?? self::PER_PAGE));

        return MyExpenseResource::collection($expenses)->additional([
            'summary' => MyExpenseReport::summaryFor($year, $month, $categories),
            'filtered_total' => round((float) $listQuery->sum('amount'), 2),
            'years' => MyExpenseReport::availableYears($year),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorize($request, 'create', 'add expenses');

        $expense = DB::transaction(fn () => MyExpense::create($this->expenses->validated($request)));

        return (new MyExpenseResource($expense->load('categoryRecord')))->response()->setStatusCode(201);
    }

    public function update(Request $request, MyExpense $myExpense): MyExpenseResource
    {
        $this->authorize($request, 'update', 'edit expenses');

        DB::transaction(fn () => $myExpense->update($this->expenses->validated($request)));

        return new MyExpenseResource($myExpense->fresh('categoryRecord'));
    }

    public function destroy(Request $request, MyExpense $myExpense): JsonResponse
    {
        $this->authorize($request, 'delete', 'delete expenses');

        $myExpense->delete();

        return response()->json(['message' => "Expense \"{$myExpense->title}\" was deleted."]);
    }

    private function authorize(Request $request, string $ability, string $what): void
    {
        abort_unless($request->user()->can("my-expenses.{$ability}"), 403, "You do not have permission to {$what}.");
    }
}
