<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\VehicleResource;
use App\Models\Vehicle;
use Illuminate\Http\JsonResponse;

class VehicleController extends Controller
{
    /**
     * A lightweight list of the fleet, for the driver app's vehicle picker
     * (e.g. when logging a Vehicle Service / Repair / Parts record).
     */
    public function index(): JsonResponse
    {
        return response()->json([
            'data' => VehicleResource::collection(Vehicle::query()->orderBy('model')->get()),
        ]);
    }
}
