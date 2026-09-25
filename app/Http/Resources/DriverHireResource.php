<?php

namespace App\Http\Resources;

use App\Models\Hire;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DriverHireResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'tour_type' => $this->tour_type,
            'tour_type_label' => Hire::TOUR_TYPES[$this->tour_type] ?? $this->tour_type,
            'from_location' => $this->fromLocation?->location?->name,
            'to_location' => $this->toLocation?->location?->name,
            'stay_locations' => $this->stayLocations->pluck('location.name')->values(),
            'pickup_location' => $this->pickupLocationPayload(),
            'map_locations' => $this->mapLocations(),
            'package' => $this->package?->name,
            'start_time' => $this->start_time?->toIso8601String(),
            'end_time' => $this->end_time?->toIso8601String(),
            'vehicle' => $this->vehicle?->model,
            'hire_full_value' => (float) $this->hire_full_value,
            'payment_type' => $this->payment_type,
            'payment_type_label' => Hire::PAYMENT_TYPES[$this->payment_type] ?? $this->payment_type,
            'description' => $this->description,
            'created_at' => $this->created_at?->toIso8601String(),
            'status' => $this->status,
            'status_label' => $this->status_label,
            'is_tracking' => $this->is_tracking,
            'tracking_started_at' => $this->tracking_started_at?->toIso8601String(),
            'tracking_stopped_at' => $this->tracking_stopped_at?->toIso8601String(),
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),
            'cancel_reason' => $this->cancel_reason,
            'total_distance_km' => $this->total_distance_km,
            'fuel_cost_total' => $this->fuel_cost_total,
        ];
    }

    /**
     * Where the driver has to be for this hire to begin, with coordinates so
     * the app can tell when the phone gets there. Null when the hire has no
     * such location or it has no coordinates saved (the app then simply
     * doesn't highlight anything).
     *
     * @return array{name: string, latitude: float, longitude: float}|null
     */
    private function pickupLocationPayload(): ?array
    {
        $location = $this->pickupLocation();

        if ($location === null || $location->latitude === null || $location->longitude === null) {
            return null;
        }

        return [
            'name' => $location->name,
            'latitude' => $location->latitude,
            'longitude' => $location->longitude,
        ];
    }
}
