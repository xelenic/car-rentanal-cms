<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['name', 'hours', 'price'])]
class Package extends Model
{
    protected function casts(): array
    {
        return [
            'hours' => 'integer',
            'price' => 'decimal:2',
        ];
    }

    public function itineraries(): HasMany
    {
        return $this->hasMany(PackageItinerary::class)->orderBy('order');
    }

    public function hires(): HasMany
    {
        return $this->hasMany(Hire::class);
    }
}
