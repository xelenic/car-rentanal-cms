<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DriverDepositTransferResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'year' => $this->year,
            'month' => $this->month,
            'amount' => (float) $this->amount,
            'slip_url' => $this->slip_url,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
