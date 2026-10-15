<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverExpenseResource;
use App\Models\HireExpense;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

/**
 * The admin app's edit/delete for a driver-logged expense — mirrors the web
 * panel's Admin\ExpenseController::update()/destroy(), just answering JSON
 * instead of redirecting. Who it's attributed to (driver/hire) isn't
 * editable here, just what was mis-entered (category, amount).
 */
class HireExpenseController extends Controller
{
    public function update(Request $request, HireExpense $hireExpense): DriverExpenseResource
    {
        abort_unless($request->user()->can('hires.update'), 403, 'You do not have permission to edit expenses.');

        $data = $request->validate([
            'category' => ['required', 'string', Rule::in(array_keys(HireExpense::CATEGORIES))],
            'amount' => ['required', 'numeric', 'min:0.01'],
        ]);

        $hireExpense->update($data);

        return new DriverExpenseResource($hireExpense->fresh('hire'));
    }

    public function destroy(Request $request, HireExpense $hireExpense): JsonResponse
    {
        abort_unless($request->user()->can('hires.delete'), 403, 'You do not have permission to delete expenses.');

        if ($hireExpense->receipt_path) {
            Storage::disk('public')->delete($hireExpense->receipt_path);
        }

        $hireExpense->delete();

        return response()->json(['message' => 'Expense deleted.']);
    }
}
