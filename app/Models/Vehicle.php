<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['model', 'condition', 'description', 'seats', 'pax'])]
class Vehicle extends Model
{
    public const CONDITIONS = ['New', 'Excellent', 'Good', 'Fair', 'Poor'];

    protected function casts(): array
    {
        return [
            'seats' => 'integer',
            'pax' => 'integer',
        ];
    }

    public function hires(): HasMany
    {
        return $this->hasMany(Hire::class);
    }

    public function maintenanceRecords(): HasMany
    {
        return $this->hasMany(VehicleMaintenanceRecord::class);
    }

    public function leasings(): HasMany
    {
        return $this->hasMany(VehicleLeasing::class)->latest('start_date');
    }
}
