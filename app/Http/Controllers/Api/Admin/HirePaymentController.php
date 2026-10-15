<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\HireResource;
use App\Models\Hire;
use App\Models\HirePayment;
use Illuminate\Http\Request;

/**
 * The admin app's "claim payment" action for a credit hire — mirrors the
 * web panel's Admin\HirePaymentController, just answering JSON instead of
 * redirecting. There's no payment method/reference or date field: paid_at
 * is always today, and the only inputs are the amount and an optional note
 * (see HirePaymentController on the web side for the same rules).
 */
class HirePaymentController extends Controller
{
    private const EAGER_LOAD = [
        'package', 'customer', 'driver', 'vehicle',
        'fromLocation.location', 'toLocation.location', 'stayLocations.location',
        'payments',
    ];

    public function store(Request $request, Hire $hire): HireResource
    {
        abort_unless($request->user()->can('hires.update'), 403, 'You do not have permission to edit hires.');

        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01', 'max:'.max($hire->balance_remaining, 0.01)],
            'notes' => ['nullable', 'string', 'max:255'],
        ]);

        $hire->payments()->create([
            'amount' => $data['amount'],
            'paid_at' => now()->toDateString(),
            'notes' => $data['notes'] ?? null,
        ]);

        return new HireResource($hire->fresh(self::EAGER_LOAD));
    }

    public function destroy(Request $request, Hire $hire, HirePayment $payment): HireResource
    {
        abort_unless($request->user()->can('hires.update'), 403, 'You do not have permission to edit hires.');
        abort_unless($payment->hire_id === $hire->id, 404);

        $payment->delete();

        return new HireResource($hire->fresh(self::EAGER_LOAD));
    }
}
