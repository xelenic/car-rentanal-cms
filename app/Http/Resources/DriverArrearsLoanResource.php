<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DriverArrearsLoanResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'amount' => (float) $this->amount,
            'source_year' => $this->source_year,
            'source_month' => $this->source_month,
            'deduction_type' => $this->deduction_type,
            'deduction_type_label' => $this->deduction_type_label,
            'created_at' => $this->created_at?->toIso8601String(),
            'deductions' => $this->deductions->map(fn ($deduction) => [
                'year' => $deduction->year,
                'month' => $deduction->month,
                'amount' => (float) $deduction->amount,
            ])->values(),
        ];
    }
}
