<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hire;
use App\Models\HireTrackingPoint;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HireTrackingController extends Controller
{
    public function start(Request $request, Hire $hire): JsonResponse
    {
        $this->authorizeDriver($request, $hire);
        $this->assertNotCompleted($hire);
        $this->assertScheduleReached($hire);

        $hire->update([
            'status' => 'started',
            'tracking_started_at' => now(),
            'tracking_stopped_at' => null,
        ]);

        return $this->statusResponse($hire);
    }

    public function stop(Request $request, Hire $hire): JsonResponse
    {
        $this->authorizeDriver($request, $hire);
        $this->assertNotCompleted($hire);

        $hire->update(['tracking_stopped_at' => now()]);

        return $this->statusResponse($hire);
    }

    public function complete(Request $request, Hire $hire): JsonResponse
    {
        $this->authorizeDriver($request, $hire);
        $this->assertNotCompleted($hire);
        $this->assertScheduleReached($hire);

        $hire->update([
            'status' => 'completed',
            'tracking_stopped_at' => now(),
        ]);

        return $this->statusResponse($hire);
    }

    public function storePoint(Request $request, Hire $hire): JsonResponse
    {
        $this->authorizeDriver($request, $hire);

        if (! $hire->is_tracking) {
            abort(422, 'Tracking is not active for this hire.');
        }

        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'recorded_at' => ['nullable', 'date'],
        ]);

        HireTrackingPoint::create([
            'hire_id' => $hire->id,
            'latitude' => $data['latitude'],
            'longitude' => $data['longitude'],
            'recorded_at' => $data['recorded_at'] ?? now(),
        ]);

        return $this->statusResponse($hire);
    }

    private function authorizeDriver(Request $request, Hire $hire): void
    {
        $driver = $request->user()->driver;

        abort_if(! $driver || $hire->driver_id !== $driver->id, 403);
    }

    private function assertNotCompleted(Hire $hire): void
    {
        if ($hire->is_completed) {
            abort(422, 'This hire has already been completed and cannot be started again.');
        }
    }

    /**
     * A hire with a future scheduled start_time (see the admin panel's
     * "Schedule" field on the Hire form) can't be started or completed
     * ahead of that date — mirrors the driver app's own client-side check,
     * enforced here too since a client-side-only guard can be bypassed.
     */
    private function assertScheduleReached(Hire $hire): void
    {
        if ($hire->start_time !== null && $hire->start_time->isFuture()) {
            abort(422, 'This hire is scheduled for '.$hire->start_time->format('M j, Y \a\t g:i A').'. It can\'t be started before then.');
        }
    }

    private function statusResponse(Hire $hire): JsonResponse
    {
        $hire->refresh();

        return response()->json([
            'status' => $hire->status,
            'status_label' => $hire->status_label,
            'is_tracking' => $hire->is_tracking,
            'tracking_started_at' => $hire->tracking_started_at?->toIso8601String(),
            'tracking_stopped_at' => $hire->tracking_stopped_at?->toIso8601String(),
            'total_distance_km' => $hire->total_distance_km,
        ]);
    }
}
