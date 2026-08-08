<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\VehicleMaintenanceRecordResource;
use App\Models\VehicleMaintenanceRecord;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class VehicleMaintenanceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $type = $request->string('type')->toString() ?: null;

        $records = $driver->vehicleMaintenanceRecords()
            ->when($type, fn ($query) => $query->where('type', $type))
            ->with('vehicle')
            ->get();

        return response()->json([
            'data' => VehicleMaintenanceRecordResource::collection($records),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $data = $request->validate([
            'vehicle_id' => ['required', 'integer', 'exists:vehicles,id'],
            'type' => ['required', 'string', Rule::in(array_keys(VehicleMaintenanceRecord::TYPES))],
            // Mileage only makes sense for a Vehicle Service entry.
            'mileage' => ['required_if:type,service', 'nullable', 'integer', 'min:0'],
            'cost' => ['required', 'numeric', 'min:0.01'],
            'description' => ['nullable', 'string', 'max:2000'],
            'bill' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:8192'],
        ]);

        $billPath = $request->file('bill')->store('vehicle-maintenance/'.$driver->id, 'public');

        $record = VehicleMaintenanceRecord::create([
            'vehicle_id' => $data['vehicle_id'],
            'driver_id' => $driver->id,
            'type' => $data['type'],
            'mileage' => $data['type'] === 'service' ? ($data['mileage'] ?? null) : null,
            'cost' => $data['cost'],
            'description' => $data['description'] ?? null,
            'bill_path' => $billPath,
        ]);

        return response()->json([
            'data' => new VehicleMaintenanceRecordResource($record->load('vehicle')),
        ], 201);
    }

    public function bill(VehicleMaintenanceRecord $vehicleMaintenanceRecord): Response
    {
        abort_unless(
            Storage::disk('public')->exists($vehicleMaintenanceRecord->bill_path),
            404
        );

        return response(
            Storage::disk('public')->get($vehicleMaintenanceRecord->bill_path),
            200,
            ['Content-Type' => Storage::disk('public')->mimeType($vehicleMaintenanceRecord->bill_path)]
        );
    }
}
