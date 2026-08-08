<?php

namespace App\Http\Resources;

use App\Models\Hire;
use App\Models\HireExpense;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DriverExpenseResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'hire_id' => $this->hire_id,
            'hire_tour_type_label' => $this->hire ? (Hire::TOUR_TYPES[$this->hire->tour_type] ?? $this->hire->tour_type) : null,
            'category' => $this->category,
            'category_label' => HireExpense::CATEGORIES[$this->category] ?? $this->category,
            'amount' => (float) $this->amount,
            'receipt_url' => $this->receipt_url,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
