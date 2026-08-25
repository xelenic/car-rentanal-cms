<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Hire;
use App\Models\HirePayment;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;

class HirePaymentController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:hires.update'),
        ];
    }

    /**
     * Records a "Claim Payment" — either the full remaining balance (the
     * Hires page's "Mark Full Payment" button submits a hidden amount
     * already equal to it) or a custom partial amount. Either way the
     * amount can never exceed what's actually still owed.
     */
    public function store(Request $request, Hire $hire): RedirectResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01', 'max:'.max($hire->balance_remaining, 0.01)],
            'notes' => ['nullable', 'string', 'max:255'],
        ]);

        $hire->payments()->create([
            'amount' => $data['amount'],
            'paid_at' => now()->toDateString(),
            'notes' => $data['notes'] ?? null,
        ]);

        $fullyPaid = round($hire->fresh()->balance_remaining, 2) <= 0;

        return redirect()->route('admin.hires.index')->with(
            'status',
            "Rs. ".number_format($data['amount'], 2)." payment recorded for Hire #{$hire->id}."
                .($fullyPaid ? ' It is now fully paid.' : '')
        );
    }

    public function destroy(Hire $hire, HirePayment $payment): RedirectResponse
    {
        abort_unless($payment->hire_id === $hire->id, 404);

        $payment->delete();

        return redirect()->route('admin.hires.index')->with('status', "Payment removed from Hire #{$hire->id}.");
    }
}
