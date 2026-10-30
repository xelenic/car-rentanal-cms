<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A vehicle service / repair / parts / revenue license record logged by a
 * driver. Deliberately separate from HireExpense: it's about the vehicle,
 * not a specific hire. Its cost comes off the driver's deposit (see
 * DriverSalaryCalculator::$vehicleMaintenanceTotal) — cash they already
 * laid out of pocket — but never off their salary: it isn't a per-hire
 * operating cost, so it never touches net_before_salary/salary.
 */
#[Fillable(['vehicle_id', 'driver_id', 'type', 'mileage', 'cost', 'description', 'bill_path'])]
class VehicleMaintenanceRecord extends Model
{
    public const TYPES = [
        'service' => 'Vehicle Service',
        'repair' => 'Vehicle Repair',
        'parts' => 'Vehicle Parts',
        'revenue_license' => 'Revenue License',
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
