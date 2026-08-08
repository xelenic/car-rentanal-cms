<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverExpenseResource;
use App\Http\Resources\HireExpenseResource;
use App\Models\Hire;
use App\Models\HireExpense;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class HireExpenseController extends Controller
{
    public function index(Request $request, Hire $hire): JsonResponse
    {
        $this->authorizeDriver($request, $hire);

        $expenses = $hire->expenses()->get();

        return response()->json([
            'data' => HireExpenseResource::collection($expenses),
            'fuel_cost_total' => $hire->fresh('expenses')->fuel_cost_total,
        ]);
    }

    public function driverIndex(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $category = $request->string('category')->toString() ?: null;

        $expenses = HireExpense::query()
            ->where('driver_id', $driver->id)
            ->when($category, fn ($query) => $query->where('category', $category))
            ->with('hire')
            ->latest()
            ->get();

        return response()->json([
            'data' => DriverExpenseResource::collection($expenses),
            'total' => round((float) $expenses->sum('amount'), 2),
        ]);
    }

    public function store(Request $request, Hire $hire): JsonResponse
    {
        $this->authorizeDriver($request, $hire);

        $data = $request->validate([
            'category' => ['nullable', 'string', Rule::in(array_keys(HireExpense::CATEGORIES))],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'receipt' => ['nullable', 'image', 'mimes:jpg,jpeg,png', 'max:8192'],
        ]);

        $receiptPath = $request->hasFile('receipt')
            ? $request->file('receipt')->store('hire-expenses/'.$hire->id, 'public')
            : null;

        $expense = HireExpense::create([
            'hire_id' => $hire->id,
            'driver_id' => $hire->driver_id,
            'category' => $data['category'] ?? 'fuel',
            'amount' => $data['amount'],
            'receipt_path' => $receiptPath,
        ]);

        return response()->json([
            'data' => new HireExpenseResource($expense),
            'fuel_cost_total' => $hire->fresh('expenses')->fuel_cost_total,
        ], 201);
    }

    /**
     * Log an expense (Fuel, Foods, Room, Parking, Highway) without tying it
     * to a specific hire — reached from the driver app's Options page
     * rather than a hire's quick actions. Still counts toward the driver's
     * monthly salary deduction (see DriverSalaryCalculator), attributed by
     * the month it's logged in instead of a hire's month.
     */
    public function storeForDriver(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $data = $request->validate([
            'category' => ['nullable', 'string', Rule::in(array_keys(HireExpense::CATEGORIES))],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'receipt' => ['nullable', 'image', 'mimes:jpg,jpeg,png', 'max:8192'],
        ]);

        $receiptPath = $request->hasFile('receipt')
            ? $request->file('receipt')->store('hire-expenses/driver-'.$driver->id, 'public')
            : null;

        $expense = HireExpense::create([
            'hire_id' => null,
            'driver_id' => $driver->id,
            'category' => $data['category'] ?? 'fuel',
            'amount' => $data['amount'],
            'receipt_path' => $receiptPath,
        ]);

        return response()->json([
            'data' => new DriverExpenseResource($expense),
        ], 201);
    }

    public function receipt(HireExpense $hireExpense): Response
    {
        abort_unless(
            $hireExpense->receipt_path && Storage::disk('public')->exists($hireExpense->receipt_path),
            404
        );

        return response(
            Storage::disk('public')->get($hireExpense->receipt_path),
            200,
            ['Content-Type' => Storage::disk('public')->mimeType($hireExpense->receipt_path)]
        );
    }

    private function authorizeDriver(Request $request, Hire $hire): void
    {
        $driver = $request->user()->driver;

        abort_if(! $driver || $hire->driver_id !== $driver->id, 403);
    }
}
