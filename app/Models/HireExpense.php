<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['hire_id', 'driver_id', 'category', 'amount', 'receipt_path'])]
class HireExpense extends Model
{
    public const CATEGORIES = [
        'fuel' => 'Fuel',
        'repair' => 'Vehicle Repair',
        'emergency' => 'Emergency',
        'highway' => 'Highway Charges',
        'food' => 'Driver Foods',
        'room' => 'Room Charges',
        'parking' => 'Parking Tickets',
        'others' => 'Others',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
        ];
    }

    public function getCategoryLabelAttribute(): string
    {
        return self::CATEGORIES[$this->category] ?? $this->category;
    }

    public function getReceiptUrlAttribute(): ?string
    {
        return $this->receipt_path ? route('hire-expenses.receipt', $this) : null;
    }

    public function hire(): BelongsTo
    {
        return $this->belongsTo(Hire::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }
}
