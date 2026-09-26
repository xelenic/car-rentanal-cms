<?php

namespace App\Http\Resources\Admin;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MyExpenseResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'category' => $this->category,
            'category_name' => $this->category_label,
            'amount' => (float) $this->amount,
            'expense_date' => $this->expense_date->format('Y-m-d'),
            'notes' => $this->notes,
        ];
    }
}
