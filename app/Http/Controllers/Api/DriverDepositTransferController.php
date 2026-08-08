<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverDepositTransferResource;
use App\Models\DriverDepositTransfer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Storage;

class DriverDepositTransferController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $year = $request->filled('year') ? $request->integer('year') : (int) now()->format('Y');
        $month = $request->filled('month') ? $request->integer('month') : (int) now()->format('n');

        $transfers = $driver->depositTransfers()
            ->where('year', $year)
            ->where('month', $month)
            ->get();

        return response()->json([
            'data' => DriverDepositTransferResource::collection($transfers),
            'total' => round((float) $transfers->sum('amount'), 2),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $data = $request->validate([
            'year' => ['required', 'integer', 'min:2000', 'max:2100'],
            'month' => ['required', 'integer', 'min:1', 'max:12'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'slip' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:8192'],
        ]);

        $slipPath = $request->file('slip')->store('deposit-slips/'.$driver->id, 'public');

        $transfer = DriverDepositTransfer::create([
            'driver_id' => $driver->id,
            'year' => $data['year'],
            'month' => $data['month'],
            'amount' => $data['amount'],
            'slip_path' => $slipPath,
        ]);

        return response()->json([
            'data' => new DriverDepositTransferResource($transfer),
        ], 201);
    }

    public function slip(DriverDepositTransfer $depositTransfer): Response
    {
        abort_unless(
            Storage::disk('public')->exists($depositTransfer->slip_path),
            404
        );

        return response(
            Storage::disk('public')->get($depositTransfer->slip_path),
            200,
            ['Content-Type' => Storage::disk('public')->mimeType($depositTransfer->slip_path)]
        );
    }
}
