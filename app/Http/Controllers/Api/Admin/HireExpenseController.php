<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverExpenseResource;
use App\Models\Driver;
use App\Models\HireExpense;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

/**
 * The admin app's add/edit/delete for a driver-logged expense — mirrors the
 * web panel's Admin\ExpenseController, just answering JSON instead of
 * redirecting. Who it's attributed to isn't editable once created, just
 * what was mis-entered (category, amount).
 */
class HireExpenseController extends Controller
{
    /**
     * Logs a new expense directly against this driver, not tied to any
     * particular hire — mirrors the driver app's own
     * Api\HireExpenseController::storeForDriver(), just admin-initiated.
     */
    public function store(Request $request, Driver $driver): JsonResponse
    {
        abort_unless($request->user()->can('hires.create'), 403, 'You do not have permission to add expenses.');

        $data = $request->validate([
            'category' => ['required', 'string', Rule::in(array_keys(HireExpense::CATEGORIES))],
            'amount' => ['required', 'numeric', 'min:0.01'],
        ]);

        $expense = HireExpense::create([
            'driver_id' => $driver->id,
            'hire_id' => null,
            'category' => $data['category'],
            'amount' => $data['amount'],
        ]);

        return response()->json(['data' => new DriverExpenseResource($expense)], 201);
    }

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
