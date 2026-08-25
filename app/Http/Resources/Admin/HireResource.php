<?php

namespace App\Http\Resources\Admin;

use App\Models\Hire;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class HireResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'tour_type' => $this->tour_type,
            'tour_type_label' => Hire::TOUR_TYPES[$this->tour_type] ?? $this->tour_type,
            'status' => $this->status,
            'status_label' => $this->status_label,
            'is_upcoming' => $this->is_upcoming,
            'start_time' => $this->start_time?->toIso8601String(),
            'end_time' => $this->end_time?->toIso8601String(),
            'from_location' => $this->fromLocation?->location?->name,
            'to_location' => $this->toLocation?->location?->name,
            'stay_locations' => $this->stayLocations->pluck('location.name')->values(),
            'day_locations' => $this->stayLocationsByDay()
                ->map(fn ($group) => $group->pluck('location.name')->values())
                ->values(),
            'package' => $this->package?->name,
            'hire_full_value' => (float) $this->hire_full_value,
            'our_hire_value' => (float) $this->our_hire_value,
            'commission' => $this->commission,
            'payment_type' => $this->payment_type,
            'payment_type_label' => Hire::PAYMENT_TYPES[$this->payment_type] ?? $this->payment_type,
            'paid_amount' => $this->paid_amount,
            'balance_remaining' => $this->balance_remaining,
            'payment_status' => $this->payment_status,
            'customer' => $this->whenLoaded('customer', fn () => [
                'id' => $this->customer->id,
                'name' => $this->customer->name,
                'phone' => $this->customer->phone,
            ]),
            'driver' => $this->whenLoaded('driver', fn () => $this->driver ? [
                'id' => $this->driver->id,
                'name' => $this->driver->name,
            ] : null),
            'vehicle' => $this->whenLoaded('vehicle', fn () => $this->vehicle ? [
                'id' => $this->vehicle->id,
                'model' => $this->vehicle->model,
            ] : null),
            'description' => $this->description,
            'is_tracking' => $this->is_tracking,
            'total_distance_km' => $this->total_distance_km,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
