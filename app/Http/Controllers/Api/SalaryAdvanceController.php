<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\SalaryAdvanceRequestResource;
use App\Models\SalaryAdvanceRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SalaryAdvanceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        return response()->json([
            'data' => SalaryAdvanceRequestResource::collection($driver->salaryAdvanceRequests),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        $advance = SalaryAdvanceRequest::create([
            'driver_id' => $driver->id,
            'amount' => $data['amount'],
            'reason' => $data['reason'] ?? null,
            'status' => 'pending',
        ]);

        return response()->json([
            'data' => new SalaryAdvanceRequestResource($advance),
        ], 201);
    }
}
