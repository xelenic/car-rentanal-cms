<?php

namespace App\Services;

use Illuminate\Http\Request;

/**
 * Validating what the "add/edit other company revenue" form sends — every
 * field is a plain manual entry, none derived or looked up.
 */
class OtherCompanyRevenueService
{
    /**
     * @return array{
     *     hire: string, booking_number: string, vehicle: string, full_amount: string|float,
     *     credited_amount: string|float, balance: string|float, vehicle_amount: string|float,
     *     revenue_date: string
     * }
     */
    public function validated(Request $request): array
    {
        return $request->validate([
            'hire' => ['required', 'string', 'max:255'],
            'booking_number' => ['required', 'string', 'max:100'],
            'vehicle' => ['required', 'string', 'max:255'],
            'full_amount' => ['required', 'numeric', 'min:0', 'max:9999999999.99'],
            'credited_amount' => ['required', 'numeric', 'min:0', 'max:9999999999.99'],
            // Independent of the two above — entered by hand, not derived, so an
            // overpayment or a rounding difference can still be recorded as-is.
            'balance' => ['required', 'numeric', 'min:-9999999999.99', 'max:9999999999.99'],
            'vehicle_amount' => ['required', 'numeric', 'min:0', 'max:9999999999.99'],
            'revenue_date' => ['required', 'date'],
        ]);
    }
}
