<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Driver;
use App\Models\Hire;
use App\Models\HireLocation;
use App\Models\Location;
use App\Models\Package;
use App\Models\Vehicle;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class HireController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:hires.view', only: ['index', 'show']),
            new Middleware('permission:hires.create', only: ['store']),
            new Middleware('permission:hires.update', only: ['update']),
            new Middleware('permission:hires.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $hires = Hire::query()
            ->with(['package', 'customer', 'driver', 'vehicle', 'locations.location', 'trackingPoints', 'expenses'])
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('description', 'like', "%{$search}%")
                        ->orWhereHas('customer', function ($query) use ($search) {
                            $query->where('name', 'like', "%{$search}%")
                                ->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        return view('admin.hires.index', [
            'hires' => $hires,
            'search' => $request->string('search')->toString(),
            'locations' => Location::orderBy('name')->get(),
            'packages' => Package::orderBy('name')->get(),
            'customers' => Customer::orderBy('name')->get(),
            'drivers' => Driver::orderBy('name')->get(),
            'vehicles' => Vehicle::orderBy('model')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $hire = DB::transaction(function () use ($data) {
            $data['customer_id'] = $this->resolveCustomerId($data);
            $hire = Hire::create($this->hireAttributes($data));
            $this->syncLocations($hire, $data);

            return $hire;
        });

        return redirect()->route('admin.hires.index')->with('status', "Hire #{$hire->id} was created.");
    }

    public function update(Request $request, Hire $hire): RedirectResponse
    {
        $data = $this->validated($request);

        DB::transaction(function () use ($data, $hire) {
            $data['customer_id'] = $this->resolveCustomerId($data);
            $hire->update($this->hireAttributes($data));
            $this->syncLocations($hire, $data);
        });

        return redirect()->route('admin.hires.index')->with('status', "Hire #{$hire->id} was updated.");
    }

    public function destroy(Hire $hire): RedirectResponse
    {
        $hire->delete();

        return redirect()->route('admin.hires.index')->with('status', "Hire #{$hire->id} was deleted.");
    }

    private function validated(Request $request): array
    {
        $tourType = $request->input('tour_type');

        $rules = [
            'tour_type' => ['required', Rule::in(array_keys(Hire::TOUR_TYPES))],
            'hire_full_value' => ['required', 'numeric', 'min:0'],
            'our_hire_value' => ['required', 'numeric', 'min:0'],
            'customer_id' => ['required'],
            'driver_id' => ['nullable', 'integer', 'exists:drivers,id'],
            'vehicle_id' => ['nullable', 'integer', 'exists:vehicles,id'],
            'description' => ['nullable', 'string'],
            'payment_type' => ['required', Rule::in(array_keys(Hire::PAYMENT_TYPES))],
        ];

        if ($request->input('customer_id') === 'new') {
            $rules['new_customer_name'] = ['required', 'string', 'max:255'];
            $rules['new_customer_phone'] = ['required', 'string', 'max:30'];
        } else {
            $rules['customer_id'] = ['required', 'integer', 'exists:customers,id'];
        }

        if (in_array($tourType, ['drop_pickup', 'day_tour'], true)) {
            $rules['from_location_id'] = ['required', 'integer', 'exists:locations,id'];
            $rules['to_location_id'] = ['required', 'integer', 'exists:locations,id'];
        }

        if ($tourType === 'day_tour') {
            $rules['stay_locations'] = ['required', 'array', 'min:1'];
            $rules['stay_locations.*'] = ['required', 'integer', 'exists:locations,id'];
        }

        // Multi-day tours: one group of locations per day — a day can hold
        // more than one location, in order.
        if ($tourType === 'multi_day') {
            $rules['day_locations'] = ['required', 'array', 'min:1'];
            $rules['day_locations.*'] = ['required', 'array', 'min:1'];
            $rules['day_locations.*.*'] = ['required', 'integer', 'exists:locations,id'];
        }

        if ($tourType === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
            $rules['start_time'] = ['required', 'date'];
            $rules['end_time'] = ['required', 'date', 'after:start_time'];
        }

        return $request->validate($rules);
    }

    private function resolveCustomerId(array $data): int
    {
        if (($data['customer_id'] ?? null) === 'new') {
            $customer = Customer::create([
                'name' => $data['new_customer_name'],
                'phone' => $data['new_customer_phone'],
            ]);

            return $customer->id;
        }

        return (int) $data['customer_id'];
    }

    private function hireAttributes(array $data): array
    {
        $isPackage = $data['tour_type'] === 'package';

        return [
            'tour_type' => $data['tour_type'],
            'package_id' => $isPackage ? $data['package_id'] : null,
            'start_time' => $isPackage ? $data['start_time'] : null,
            'end_time' => $isPackage ? $data['end_time'] : null,
            'hire_full_value' => $data['hire_full_value'],
            'our_hire_value' => $data['our_hire_value'],
            'customer_id' => $data['customer_id'],
            'driver_id' => $data['driver_id'] ?? null,
            'vehicle_id' => $data['vehicle_id'] ?? null,
            'description' => $data['description'] ?? null,
            'payment_type' => $data['payment_type'],
        ];
    }

    private function syncLocations(Hire $hire, array $data): void
    {
        $hire->locations()->delete();

        $order = 0;

        if (in_array($data['tour_type'], ['drop_pickup', 'day_tour'], true)) {
            HireLocation::create([
                'hire_id' => $hire->id,
                'location_id' => $data['from_location_id'],
                'role' => 'from',
                'order' => $order++,
            ]);

            HireLocation::create([
                'hire_id' => $hire->id,
                'location_id' => $data['to_location_id'],
                'role' => 'to',
                'order' => $order++,
            ]);
        }

        if ($data['tour_type'] === 'day_tour') {
            foreach (array_values($data['stay_locations'] ?? []) as $locationId) {
                HireLocation::create([
                    'hire_id' => $hire->id,
                    'location_id' => $locationId,
                    'role' => 'stay',
                    'order' => $order++,
                ]);
            }
        }

        if ($data['tour_type'] === 'multi_day') {
            foreach (array_values($data['day_locations'] ?? []) as $dayIndex => $dayLocationIds) {
                foreach (array_values($dayLocationIds) as $locationId) {
                    HireLocation::create([
                        'hire_id' => $hire->id,
                        'location_id' => $locationId,
                        'role' => 'stay',
                        'day_number' => $dayIndex + 1,
                        'order' => $order++,
                    ]);
                }
            }
        }
    }
}
