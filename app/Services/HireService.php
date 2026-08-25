<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Hire;
use App\Models\HireLocation;
use App\Models\Location;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * The hire create/update business logic — shared by the admin web panel
 * (Admin\HireController) and the admin mobile app's API (Api\Admin\HireController)
 * so the two never drift apart. Callers each do their own request validation
 * (a web Request vs. an API Request look different) but both end up handing
 * this the same shape of validated array.
 */
class HireService
{
    /**
     * The validation rules for a hire submission, parameterized by tour
     * type and whether the customer is an existing pick or a new inline
     * one — identical shape whether the caller is the web form or the API.
     */
    public function rules(?string $tourType, bool $isNewCustomer): array
    {
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

        if ($isNewCustomer) {
            $rules['new_customer_name'] = ['required', 'string', 'max:255'];
            $rules['new_customer_phone'] = ['required', 'string', 'max:30'];
        } else {
            $rules['customer_id'] = ['required', 'integer', 'exists:customers,id'];
        }

        // Every location is typed directly (with Google Places suggestions
        // on the web; a plain name on the admin app for now) rather than
        // picked from a dropdown — lat/lng only ever arrive filled in when
        // a suggestion was actually picked, so they stay optional (see
        // resolveLocationId(), which creates or reuses the Location record
        // by that name).
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

        return $rules;
    }

    public function create(array $data): Hire
    {
        return DB::transaction(function () use ($data) {
            $data['customer_id'] = $this->resolveCustomerId($data);
            $data = $this->resolveLocationFields($data);
            $hire = Hire::create($this->hireAttributes($data));
            $this->syncLocations($hire, $data);

            // hireAttributes() never sets 'status' — it's left to the
            // column's own DB default ('pending'), which create() doesn't
            // pull back into the in-memory model on its own. Callers that
            // serialize the returned hire directly (the admin app's API)
            // need status/status_label populated, not left null.
            return $hire->fresh();
        });
    }

    public function update(Hire $hire, array $data): Hire
    {
        DB::transaction(function () use ($hire, $data) {
            $data['customer_id'] = $this->resolveCustomerId($data);
            $data = $this->resolveLocationFields($data);
            $hire->update($this->hireAttributes($data));
            $this->syncLocations($hire, $data);
        });

        return $hire->fresh();
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
     * Turns each typed location name into a real Location record (reusing
     * one of that exact name if it already exists, with coordinates too
     * when a Places suggestion was picked) and swaps the ids back into
     * $data so hireAttributes()/syncLocations() never need to know a
     * location was just typed in rather than picked from a list.
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
     * name if one exists, otherwise creates it. $lat/$lng come from a
     * picked Places suggestion (blank if free text) and are only applied
     * when actually creating a new record.
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
            // start_time, which is what powers the Upcoming Hires filter.
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
