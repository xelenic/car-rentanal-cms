<?php

namespace App\Http\Resources\Admin;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OtherIncomeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'amount' => (float) $this->amount,
            'income_date' => $this->income_date->format('Y-m-d'),
            'notes' => $this->notes,
        ];
    }
}
