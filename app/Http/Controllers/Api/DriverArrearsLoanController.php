<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverArrearsLoanResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DriverArrearsLoanController extends Controller
{
    /**
     * All of a driver's arrears loans (converted deficits), each with its
     * full month-by-month deduction schedule — mirrors the admin panel's
     * "Arrears Loan Schedule" view, but scoped to the logged-in driver and
     * not limited to a single salary period.
     */
    public function index(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $loans = $driver->arrearsLoans()->with('deductions')->get();

        return response()->json([
            'data' => DriverArrearsLoanResource::collection($loans),
        ]);
    }
}
