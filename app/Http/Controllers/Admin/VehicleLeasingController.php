<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Vehicle;
use App\Models\VehicleLeasing;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class VehicleLeasingController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:vehicles.view', only: ['index']),
            new Middleware('permission:vehicles.create', only: ['store']),
            new Middleware('permission:vehicles.update', only: ['update']),
            new Middleware('permission:vehicles.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $vehicleId = $request->integer('vehicle_id') ?: null;
        $type = $request->string('type')->toString() ?: null;
        $status = $request->string('status')->toString() ?: null;

        $leasings = VehicleLeasing::query()
            ->with(['vehicle', 'settlements'])
            ->when($vehicleId, fn ($query) => $query->where('vehicle_id', $vehicleId))
            ->when($type, fn ($query) => $query->where('type', $type))
            ->when($status, fn ($query) => $query->where('status', $status))
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('company', 'like', "%{$search}%")
                        ->orWhere('agreement_number', 'like', "%{$search}%")
                        ->orWhereHas('vehicle', fn ($query) => $query->where('model', 'like', "%{$search}%"));
                });
            })
            ->latest('start_date')
            ->paginate(10)
            ->withQueryString();

        $activeQuery = VehicleLeasing::query()->where('status', 'active');

        return view('admin.leasing.index', [
            'leasings' => $leasings,
            'vehicles' => Vehicle::query()->orderBy('model')->get(['id', 'model']),
            'types' => VehicleLeasing::TYPES,
            'statuses' => VehicleLeasing::STATUSES,
            'selectedVehicleId' => $vehicleId,
            'selectedType' => $type,
            'selectedStatus' => $status,
            'search' => $request->string('search')->toString(),
            'summary' => [
                'active_count' => (clone $activeQuery)->count(),
                'loan_amount_total' => round((float) VehicleLeasing::query()->sum('loan_amount'), 2),
                'monthly_installment_total' => round((float) (clone $activeQuery)->sum('monthly_installment'), 2),
                'balance_remaining_total' => round((float) (clone $activeQuery)->sum('balance_remaining'), 2),
            ],
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);
        $data['balance_remaining'] = $data['balance_remaining'] ?? $data['loan_amount'];

        $leasing = VehicleLeasing::create($data);

        return redirect()->route('admin.leasing.index')
            ->with('status', "Leasing record for \"{$leasing->vehicle->model}\" was created.");
    }

    public function update(Request $request, VehicleLeasing $leasing): RedirectResponse
    {
        $data = $this->validated($request);

        $leasing->update($data);

        return redirect()->route('admin.leasing.index')
            ->with('status', "Leasing record for \"{$leasing->vehicle->model}\" was updated.");
    }

    public function destroy(VehicleLeasing $leasing): RedirectResponse
    {
        $leasing->delete();

        return redirect()->route('admin.leasing.index')->with('status', 'Leasing record was deleted.');
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'vehicle_id' => ['required', 'integer', 'exists:vehicles,id'],
            'type' => ['required', Rule::in(array_keys(VehicleLeasing::TYPES))],
            'company' => ['required', 'string', 'max:255'],
            'agreement_number' => ['nullable', 'string', 'max:255'],
            'loan_amount' => ['required', 'numeric', 'min:0'],
            'monthly_installment' => ['required', 'numeric', 'min:0'],
            'interest_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'balance_remaining' => ['nullable', 'numeric', 'min:0'],
            'start_date' => ['required', 'date'],
            'term_months' => ['nullable', 'integer', 'min:1'],
            'end_date' => ['nullable', 'date'],
            'status' => ['required', Rule::in(array_keys(VehicleLeasing::STATUSES))],
            'notes' => ['nullable', 'string'],
        ]);
    }
}
