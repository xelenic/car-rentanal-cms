<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A vehicle service / repair / parts record logged by a driver. Deliberately
 * separate from HireExpense: it's about the vehicle, not a specific hire,
 * and must never be counted as a deductible expense or affect the driver's
 * salary calculation (see DriverSalaryCalculator, which never touches this
 * table).
 */
#[Fillable(['vehicle_id', 'driver_id', 'type', 'mileage', 'cost', 'description', 'bill_path'])]
class VehicleMaintenanceRecord extends Model
{
    public const TYPES = [
        'service' => 'Vehicle Service',
        'repair' => 'Vehicle Repair',
        'parts' => 'Vehicle Parts',
    ];

    protected function casts(): array
    {
        return [
            'mileage' => 'integer',
            'cost' => 'decimal:2',
        ];
    }

    public function getTypeLabelAttribute(): string
    {
        return self::TYPES[$this->type] ?? $this->type;
    }

    public function getBillUrlAttribute(): ?string
    {
        return $this->bill_path ? route('vehicle-maintenance.bill', $this) : null;
    }

    public function vehicle(): BelongsTo
    {
        return $this->belongsTo(Vehicle::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }
}
