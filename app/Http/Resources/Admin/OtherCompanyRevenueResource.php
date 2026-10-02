<?php

namespace App\Http\Resources\Admin;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OtherCompanyRevenueResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'hire' => $this->hire,
            'booking_number' => $this->booking_number,
            'vehicle' => $this->vehicle,
            'full_amount' => (float) $this->full_amount,
            'credited_amount' => (float) $this->credited_amount,
            'balance' => (float) $this->balance,
            'vehicle_amount' => (float) $this->vehicle_amount,
            'revenue_date' => $this->revenue_date->format('Y-m-d'),
            'slip_url' => $this->slip_url,
        ];
    }
}
