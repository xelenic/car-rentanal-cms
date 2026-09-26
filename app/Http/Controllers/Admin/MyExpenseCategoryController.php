<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\MyExpenseCategory;
use App\Services\MyExpenseCategoryService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

/**
 * Adding, renaming and removing the categories My Expenses are filed under.
 * Guarded by the My Expenses permissions: creating a category needs
 * "create", renaming "update", removing "delete".
 */
class MyExpenseCategoryController extends Controller implements HasMiddleware
{
    public function __construct(private readonly MyExpenseCategoryService $categories) {}

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
        $category = $this->categories->create($request);

        return $this->backToManager()->with('status', "Category \"{$category->name}\" was added.");
    }

    public function update(Request $request, MyExpenseCategory $myExpenseCategory): RedirectResponse
    {
        $category = $this->categories->rename($myExpenseCategory, $request);

        return $this->backToManager()->with('status', "Category renamed to \"{$category->name}\".");
    }

    public function destroy(MyExpenseCategory $myExpenseCategory): RedirectResponse
    {
        $name = $myExpenseCategory->name;

        if ($problem = $this->categories->delete($myExpenseCategory)) {
            return $this->backToManager()->with('error', $problem);
        }

        return $this->backToManager()->with('status', "Category \"{$name}\" was deleted.");
    }

    /** Back to the page, with the category manager reopened so several changes can be made in a row. */
    private function backToManager(): RedirectResponse
    {
        return back()->with('reopen_modal', 'categories');
    }
}
