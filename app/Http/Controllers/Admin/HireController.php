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
use Illuminate\Http\JsonResponse;
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
            new Middleware('permission:hires.view', only: ['index', 'show', 'tracking']),
            new Middleware('permission:hires.create', only: ['store']),
            new Middleware('permission:hires.update', only: ['update']),
            new Middleware('permission:hires.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $showUpcoming = $request->boolean('upcoming');

        $upcomingScope = fn ($query) => $query->where('status', 'pending')
            ->whereNotNull('start_time')
            ->where('start_time', '>=', now());

        $hires = Hire::query()
            ->with([
                'package', 'customer', 'driver', 'vehicle', 'trackingPoints', 'expenses',
                'locations.location', 'fromLocation.location', 'toLocation.location', 'stayLocations.location',
            ])
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('description', 'like', "%{$search}%")
                        ->orWhereHas('customer', function ($query) use ($search) {
                            $query->where('name', 'like', "%{$search}%")
                                ->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            })
            ->when($showUpcoming, $upcomingScope)
            // Upcoming hires read soonest-first; otherwise newest-created-first, as before.
            ->when($showUpcoming, fn ($query) => $query->orderBy('start_time'), fn ($query) => $query->latest())
            ->paginate(10)
            ->withQueryString();

        return view('admin.hires.index', [
            'hires' => $hires,
            'search' => $request->string('search')->toString(),
            'showUpcoming' => $showUpcoming,
            'upcomingCount' => Hire::query()->tap($upcomingScope)->count(),
            'packages' => Package::orderBy('name')->get(),
            'customers' => Customer::orderBy('name')->get(),
            'drivers' => Driver::orderBy('name')->get(),
            'vehicles' => Vehicle::orderBy('model')->get(),
            'googleMapsApiKey' => config('services.google_maps.key'),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $hire = DB::transaction(function () use ($data) {
            $data['customer_id'] = $this->resolveCustomerId($data);
            $data = $this->resolveLocationFields($data);
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
            $data = $this->resolveLocationFields($data);
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

    /**
     * Polled by the "Location Track" modal (see hires/index.blade.php) so
     * it can update live while a driver is out on an active hire, instead
     * of only ever showing whatever was on the page at the last full load.
     */
    public function tracking(Hire $hire): JsonResponse
    {
        $hire->load('trackingPoints');

        return response()->json([
            'status' => $hire->status,
            'status_label' => $hire->status_label,
            'is_tracking' => $hire->is_tracking,
            'total_distance_km' => $hire->total_distance_km,
            'points' => $hire->trackingPoints->map(fn ($p) => ['lat' => $p->latitude, 'lng' => $p->longitude])->values(),
        ]);
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

        // Every location is now typed directly (with Google Places
        // suggestions) rather than picked from a dropdown — the name is
        // what the admin typed/selected; lat/lng only ever arrive filled in
        // when they actually picked a suggestion, so they stay optional
        // (see resolveLocationId(), which creates or reuses the Location
        // record by that name).
        $latLngRules = ['nullable', 'numeric'];

        if (in_array($tourType, ['drop_pickup', 'day_tour'], true)) {
            $rules['from_location_name'] = ['required', 'string', 'max:255'];
            $rules['from_location_lat'] = $latLngRules;
            $rules['from_location_lng'] = $latLngRules;
            $rules['to_location_name'] = ['required', 'string', 'max:255'];
            $rules['to_location_lat'] = $latLngRules;
            $rules['to_location_lng'] = $latLngRules;
        }

        if ($tourType === 'day_tour') {
            $rules['stay_location_names'] = ['required', 'array', 'min:1'];
            $rules['stay_location_names.*'] = ['required', 'string', 'max:255'];
            $rules['stay_location_lats'] = ['nullable', 'array'];
            $rules['stay_location_lats.*'] = $latLngRules;
            $rules['stay_location_lngs'] = ['nullable', 'array'];
            $rules['stay_location_lngs.*'] = $latLngRules;
        }

        // Multi-day tours: one group of locations per day — a day can hold
        // more than one location, in order.
        if ($tourType === 'multi_day') {
            $rules['day_location_names'] = ['required', 'array', 'min:1'];
            $rules['day_location_names.*'] = ['required', 'array', 'min:1'];
            $rules['day_location_names.*.*'] = ['required', 'string', 'max:255'];
            $rules['day_location_lats'] = ['nullable', 'array'];
            $rules['day_location_lats.*'] = ['nullable', 'array'];
            $rules['day_location_lats.*.*'] = $latLngRules;
            $rules['day_location_lngs'] = ['nullable', 'array'];
            $rules['day_location_lngs.*'] = ['nullable', 'array'];
            $rules['day_location_lngs.*.*'] = $latLngRules;
        }

        if ($tourType === 'package') {
            $rules['package_id'] = ['required', 'integer', 'exists:packages,id'];
            $rules['start_time'] = ['required', 'date'];
            $rules['end_time'] = ['required', 'date', 'after:start_time'];
        } else {
            // Every other tour type can optionally be scheduled ahead of
            // time too — just a single date/time, no range.
            $rules['start_time'] = ['nullable', 'date'];
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

    /**
     * Every location on this form is typed directly (Google Places
     * suggestions, no dropdown) — this turns each typed name into a real
     * Location record (reusing one of that exact name if it already
     * exists, with coordinates too when the admin picked a Places
     * suggestion rather than just typing free text) and swaps the ids
     * back into $data so hireAttributes()/syncLocations() work exactly as
     * before, unaware any of this happened.
     */
    private function resolveLocationFields(array $data): array
    {
        if (in_array($data['tour_type'], ['drop_pickup', 'day_tour'], true)) {
            $data['from_location_id'] = $this->resolveLocationId(
                $data['from_location_name'], $data['from_location_lat'] ?? null, $data['from_location_lng'] ?? null,
            );
            $data['to_location_id'] = $this->resolveLocationId(
                $data['to_location_name'], $data['to_location_lat'] ?? null, $data['to_location_lng'] ?? null,
            );
        }

        if ($data['tour_type'] === 'day_tour') {
            $lats = $data['stay_location_lats'] ?? [];
            $lngs = $data['stay_location_lngs'] ?? [];

            $data['stay_locations'] = collect($data['stay_location_names'])
                ->values()
                ->map(fn ($name, $index) => $this->resolveLocationId($name, $lats[$index] ?? null, $lngs[$index] ?? null))
                ->all();
        }

        if ($data['tour_type'] === 'multi_day') {
            $latGroups = $data['day_location_lats'] ?? [];
            $lngGroups = $data['day_location_lngs'] ?? [];

            $data['day_locations'] = collect($data['day_location_names'])
                ->map(function ($dayNames, $dayIndex) use ($latGroups, $lngGroups) {
                    $dayLats = $latGroups[$dayIndex] ?? [];
                    $dayLngs = $lngGroups[$dayIndex] ?? [];

                    return collect($dayNames)
                        ->values()
                        ->map(fn ($name, $index) => $this->resolveLocationId($name, $dayLats[$index] ?? null, $dayLngs[$index] ?? null))
                        ->all();
                })
                ->all();
        }

        return $data;
    }

    /**
     * $name has already passed "required|string" validation, so it's
     * guaranteed non-empty here — reuses an existing location of that exact
     * name if one exists, otherwise creates it. $lat/$lng come from the
     * Google Places suggestion the admin picked (blank if they just typed
     * free text without choosing one) and are only applied when actually
     * creating a new record.
     */
    private function resolveLocationId(string $name, mixed $lat = null, mixed $lng = null): int
    {
        return Location::firstOrCreate(['name' => trim($name)], [
            'latitude' => is_numeric($lat) ? (float) $lat : null,
            'longitude' => is_numeric($lng) ? (float) $lng : null,
        ])->id;
    }

    private function hireAttributes(array $data): array
    {
        $isPackage = $data['tour_type'] === 'package';

        return [
            'tour_type' => $data['tour_type'],
            'package_id' => $isPackage ? $data['package_id'] : null,
            // Packages carry their own required start/end range; every
            // other tour type can optionally carry just a scheduled
            // start_time (see the "Scheduled Date & Time" field), which is
            // what powers the Upcoming Hires filter.
            'start_time' => $isPackage ? $data['start_time'] : ($data['start_time'] ?? null),
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
