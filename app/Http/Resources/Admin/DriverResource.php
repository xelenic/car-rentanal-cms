<?php

namespace App\Http\Resources\Admin;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** A driver as the admin app's roster shows it. Password is never exposed. */
class DriverResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'license' => $this->license,
            'contact_number' => $this->contact_number,
            'additional_phone_number' => $this->additional_phone_number,
            'email' => $this->email,
        ];
    }
}
