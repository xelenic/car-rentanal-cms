<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['hire_id', 'latitude', 'longitude', 'recorded_at'])]
class HireTrackingPoint extends Model
{
    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
            'recorded_at' => 'datetime',
        ];
    }

    public function hire(): BelongsTo
    {
        return $this->belongsTo(Hire::class);
    }
}
