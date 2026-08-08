<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['name', 'phone', 'email', 'nic_passport', 'address', 'notes'])]
class Customer extends Model
{
    public function hires(): HasMany
    {
        return $this->hasMany(Hire::class)->latest();
    }
}
