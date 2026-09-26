<?php

namespace App\Http\Resources\Admin;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MyExpenseCategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'key' => $this->key,
            'name' => $this->name,
            // How many expenses are filed under it (all months) — a category with any can't be deleted.
            'expenses_count' => $this->whenCounted('expenses'),
        ];
    }
}
