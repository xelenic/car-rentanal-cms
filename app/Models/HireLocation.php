<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['hire_id', 'location_id', 'role', 'day_number', 'order'])]
class HireLocation extends Model
{
    public function hire(): BelongsTo
    {
        return $this->belongsTo(Hire::class);
    }

    public function location(): BelongsTo
    {
        return $this->belongsTo(Location::class);
    }
}
