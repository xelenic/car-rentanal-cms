<?php

namespace App\Http\Resources\Admin;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A vehicle as the admin app's cards show it. The "stats" block needs the
 * vehicle loaded through Vehicle::withHireStats(); without it the block is
 * left out rather than reported as zeros.
 */
class VehicleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'model' => $this->model,
            'condition' => $this->condition,
            'seats' => $this->seats,
            'pax' => $this->pax,
            'description' => $this->description,
            'stats' => $this->when(isset($this->all_count), fn () => $this->stats()),
        ];
    }

    private function stats(): array
    {
        $full = (float) $this->full_value_total;
        $our = (float) $this->our_value_total;
        $monthFull = (float) $this->month_full_value_total;
        $monthOur = (float) $this->month_our_value_total;

        return [
            // Hires that earn money — cancelled ones are counted separately.
            'hire_count' => (int) $this->counted_count,
            'hire_full_value_total' => round($full, 2),
            'our_hire_value_total' => round($our, 2),
            'commission_total' => round($full - $our, 2),
            'month' => [
                'hire_count' => (int) $this->month_count,
                'hire_full_value_total' => round($monthFull, 2),
                'commission_total' => round($monthFull - $monthOur, 2),
            ],
            'counts' => [
                'all' => (int) $this->all_count,
                'today' => (int) $this->today_count,
                'scheduled' => (int) $this->scheduled_count,
                'completed' => (int) $this->completed_count,
                'cancelled' => (int) $this->cancelled_count,
                'running' => (int) $this->running_count,
            ],
        ];
    }
}
