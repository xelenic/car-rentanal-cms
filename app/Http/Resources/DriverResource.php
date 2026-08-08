<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DriverResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'license' => $this->license,
            'contact_number' => $this->contact_number,
            'additional_phone_number' => $this->additional_phone_number,
        ];
    }
}
