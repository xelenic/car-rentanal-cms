<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\VehicleLeasing;
use App\Models\VehicleLeasingSettlement;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

class VehicleLeasingSettlementController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:vehicles.update', only: ['store', 'destroy']),
        ];
    }

    public function store(Request $request, VehicleLeasing $leasing): RedirectResponse
    {
        $data = $request->validate([
            'year' => ['required', 'integer', 'min:2000', 'max:2100'],
            'month' => ['required', 'integer', 'min:1', 'max:12'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        VehicleLeasingSettlement::create([
            'leasing_id' => $leasing->id,
            'year' => $data['year'],
            'month' => $data['month'],
            'amount' => $data['amount'],
            'notes' => $data['notes'] ?? null,
        ]);

        // Each settlement is a payment against the running balance — reduce
        // it, and mark the lease/loan as settled once it hits zero.
        $newBalance = max((float) $leasing->balance_remaining - $data['amount'], 0);
        $leasing->update([
            'balance_remaining' => $newBalance,
            'status' => $newBalance <= 0 && $leasing->status === 'active' ? 'completed' : $leasing->status,
        ]);

        return redirect()->route('admin.leasing.index')
            ->with('status', "Settlement recorded for \"{$leasing->vehicle->model}\".");
    }

    public function destroy(VehicleLeasing $leasing, VehicleLeasingSettlement $settlement): RedirectResponse
    {
        abort_if($settlement->leasing_id !== $leasing->id, 404);

        $amount = (float) $settlement->amount;
        $settlement->delete();

        $newBalance = min((float) $leasing->balance_remaining + $amount, (float) $leasing->loan_amount);
        $leasing->update([
            'balance_remaining' => $newBalance,
            'status' => $newBalance > 0 && $leasing->status === 'completed' ? 'active' : $leasing->status,
        ]);

        return redirect()->route('admin.leasing.index')
            ->with('status', 'Settlement was removed.');
    }
}
