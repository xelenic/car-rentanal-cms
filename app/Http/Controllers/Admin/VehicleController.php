<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Hire;
use App\Models\Vehicle;
use App\Models\VehicleMaintenanceRecord;
use App\Support\MonthlyPeriods;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;

class VehicleController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:vehicles.view', only: ['index', 'show']),
            new Middleware('permission:vehicles.create', only: ['store']),
            new Middleware('permission:vehicles.update', only: ['update']),
            new Middleware('permission:vehicles.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $vehicles = Vehicle::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('model', 'like', "%{$search}%")
                        ->orWhere('condition', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        $periods = MonthlyPeriods::fromTimestamps(
            Hire::query()->get(['start_time', 'created_at'])->pluck('effective_month_date')
        );
        $availableYears = $periods['years'];
        $monthsByYear = $periods['months_by_year'];

        $selectedYear = $request->filled('year')
            ? $request->integer('year')
            : ($availableYears[0] ?? (int) now()->format('Y'));

        $selectedMonth = $request->filled('month')
            ? $request->integer('month')
            : ($monthsByYear[$selectedYear][0] ?? (int) now()->format('n'));

        $vehicleIds = $vehicles->getCollection()->pluck('id');

        $hireTotalsByVehicle = Hire::query()
            ->whereIn('vehicle_id', $vehicleIds)
            ->inMonth($selectedYear, $selectedMonth)
            ->get(['vehicle_id', 'hire_full_value', 'our_hire_value'])
            ->groupBy('vehicle_id')
            ->map(fn ($group) => [
                'hire_count' => $group->count(),
                'hire_full_value_total' => round((float) $group->sum('hire_full_value'), 2),
                'our_hire_value_total' => round((float) $group->sum('our_hire_value'), 2),
            ]);

        $summary = [
            'hire_full_value_total' => round((float) $hireTotalsByVehicle->sum('hire_full_value_total'), 2),
            'our_hire_value_total' => round((float) $hireTotalsByVehicle->sum('our_hire_value_total'), 2),
        ];

        // All-time (not period-filtered) — service/repair/parts history is
        // sporadic rather than monthly like hires, so a running lifetime
        // total is more useful here than a single month's slice.
        $maintenanceRecordsByVehicle = VehicleMaintenanceRecord::query()
            ->whereIn('vehicle_id', $vehicleIds)
            ->with('driver')
            ->latest()
            ->get()
            ->groupBy('vehicle_id');

        $maintenanceTotalsByVehicle = $maintenanceRecordsByVehicle->map(
            fn ($group) => round((float) $group->sum('cost'), 2)
        );

        return view('admin.vehicles.index', [
            'vehicles' => $vehicles,
            'search' => $request->string('search')->toString(),
            'conditions' => Vehicle::CONDITIONS,
            'hireTotalsByVehicle' => $hireTotalsByVehicle,
            'maintenanceRecordsByVehicle' => $maintenanceRecordsByVehicle,
            'maintenanceTotalsByVehicle' => $maintenanceTotalsByVehicle,
            'summary' => $summary,
            'periodLabel' => now()->setDate($selectedYear, $selectedMonth, 1)->format('F Y'),
            'availableYears' => $availableYears,
            'monthsByYear' => $monthsByYear,
            'selectedYear' => $selectedYear,
            'selectedMonth' => $selectedMonth,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $vehicle = Vehicle::create($data);

        return redirect()->route('admin.vehicles.index')->with('status', "Vehicle \"{$vehicle->model}\" was created.");
    }

    public function update(Request $request, Vehicle $vehicle): RedirectResponse
    {
        $data = $this->validated($request);

        $vehicle->update($data);

        return redirect()->route('admin.vehicles.index')->with('status', "Vehicle \"{$vehicle->model}\" was updated.");
    }

    public function destroy(Vehicle $vehicle): RedirectResponse
    {
        $vehicle->delete();

        return redirect()->route('admin.vehicles.index')->with('status', "Vehicle \"{$vehicle->model}\" was deleted.");
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'model' => ['required', 'string', 'max:255'],
            'condition' => ['required', 'string', 'in:'.implode(',', Vehicle::CONDITIONS)],
            'description' => ['nullable', 'string'],
            'seats' => ['required', 'integer', 'min:1', 'max:100'],
            'pax' => ['required', 'integer', 'min:1', 'max:100'],
        ]);
    }
}
