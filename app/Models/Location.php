<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['name', 'description', 'latitude', 'longitude'])]
class Location extends Model
{
    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }

    public function packageItineraries(): HasMany
    {
        return $this->hasMany(PackageItinerary::class);
    }

    public function hireLocations(): HasMany
    {
        return $this->hasMany(HireLocation::class);
    }
}
