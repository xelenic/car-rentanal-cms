<?php

namespace App\Http\Resources;

use App\Models\HireExpense;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class HireExpenseResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'category' => $this->category,
            'category_label' => HireExpense::CATEGORIES[$this->category] ?? $this->category,
            'amount' => (float) $this->amount,
            'receipt_url' => $this->receipt_url,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
