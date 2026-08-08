<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Vehicle;
use App\Models\VehicleMaintenanceRecord;
use App\Support\MonthlyPeriods;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;

class VehicleMaintenanceController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:vehicles.view', only: ['index']),
            new Middleware('permission:vehicles.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $vehicleId = $request->integer('vehicle_id') ?: null;
        $type = $request->string('type')->toString() ?: null;

        $records = VehicleMaintenanceRecord::query()
            ->with(['vehicle', 'driver'])
            ->when($vehicleId, fn ($query) => $query->where('vehicle_id', $vehicleId))
            ->when($type, fn ($query) => $query->where('type', $type))
            ->when($request->filled('year'), fn ($query) => $query->whereYear('created_at', $request->integer('year')))
            ->when($request->filled('month'), fn ($query) => $query->whereMonth('created_at', $request->integer('month')))
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->whereHas('vehicle', fn ($query) => $query->where('model', 'like', "%{$search}%"))
                        ->orWhereHas('driver', fn ($query) => $query->where('name', 'like', "%{$search}%"))
                        ->orWhere('description', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(15)
            ->withQueryString();

        // Totals for the current filtered set (not just the current page).
        $totalsQuery = VehicleMaintenanceRecord::query()
            ->when($vehicleId, fn ($query) => $query->where('vehicle_id', $vehicleId))
            ->when($type, fn ($query) => $query->where('type', $type))
            ->when($request->filled('year'), fn ($query) => $query->whereYear('created_at', $request->integer('year')))
            ->when($request->filled('month'), fn ($query) => $query->whereMonth('created_at', $request->integer('month')));

        $periods = MonthlyPeriods::fromTimestamps(VehicleMaintenanceRecord::query()->pluck('created_at'));

        return view('admin.repairs.index', [
            'records' => $records,
            'vehicles' => Vehicle::query()->orderBy('model')->get(['id', 'model']),
            'types' => VehicleMaintenanceRecord::TYPES,
            'selectedVehicleId' => $vehicleId,
            'selectedType' => $type,
            'search' => $request->string('search')->toString(),
            'selectedYear' => $request->integer('year') ?: null,
            'selectedMonth' => $request->integer('month') ?: null,
            'availableYears' => $periods['years'],
            'monthsByYear' => $periods['months_by_year'],
            'recordCount' => (clone $totalsQuery)->count(),
            'totalCost' => round((float) (clone $totalsQuery)->sum('cost'), 2),
        ]);
    }

    public function destroy(VehicleMaintenanceRecord $vehicleMaintenanceRecord): RedirectResponse
    {
        Storage::disk('public')->delete($vehicleMaintenanceRecord->bill_path);
        $vehicleMaintenanceRecord->delete();

        return redirect()->route('admin.repairs.index')
            ->with('status', 'Repair record was deleted.');
    }
}
