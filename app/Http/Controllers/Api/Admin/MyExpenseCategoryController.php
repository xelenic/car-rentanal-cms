<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\MyExpenseCategoryResource;
use App\Models\MyExpenseCategory;
use App\Services\MyExpenseCategoryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * The admin mobile app's My Expenses categories: the list the expense form
 * and filter use, and adding, renaming and removing one. Same permissions as
 * the expenses themselves (create / update / delete).
 */
class MyExpenseCategoryController extends Controller
{
    public function __construct(private readonly MyExpenseCategoryService $categories) {}

    /** Every category A to Z, each with how many expenses are filed under it. */
    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize($request, 'view', 'view expenses');

        return MyExpenseCategoryResource::collection(
            MyExpenseCategory::query()->withCount('expenses')->orderBy('name')->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorize($request, 'create', 'add categories');

        $category = $this->categories->create($request);

        return (new MyExpenseCategoryResource($category->loadCount('expenses')))->response()->setStatusCode(201);
    }

    public function update(Request $request, MyExpenseCategory $myExpenseCategory): MyExpenseCategoryResource
    {
        $this->authorize($request, 'update', 'rename categories');

        return new MyExpenseCategoryResource($this->categories->rename($myExpenseCategory, $request)->loadCount('expenses'));
    }

    /** A category with expenses filed under it is refused (422) with how many. */
    public function destroy(Request $request, MyExpenseCategory $myExpenseCategory): JsonResponse
    {
        $this->authorize($request, 'delete', 'delete categories');

        $name = $myExpenseCategory->name;

        if ($problem = $this->categories->delete($myExpenseCategory)) {
            return response()->json(['message' => $problem], 422);
        }

        return response()->json(['message' => "Category \"{$name}\" was deleted."]);
    }

    private function authorize(Request $request, string $ability, string $what): void
    {
        abort_unless($request->user()->can("my-expenses.{$ability}"), 403, "You do not have permission to {$what}.");
    }
}
