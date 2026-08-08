<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class VehicleMaintenanceRecordResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'vehicle_id' => (int) $this->vehicle_id,
            'vehicle_model' => $this->vehicle?->model,
            'type' => $this->type,
            'type_label' => $this->type_label,
            'mileage' => $this->mileage,
            'cost' => (float) $this->cost,
            'description' => $this->description,
            'bill_url' => $this->bill_url,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
