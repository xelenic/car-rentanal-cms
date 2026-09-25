<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverHireResource;
use App\Models\Hire;
use App\Support\MonthlyPeriods;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class DriverHireController extends Controller
{
    /** The status groups the driver app's tabs ask for — see Hire::scopeStatusGroup(). */
    private const STATUS_GROUPS = ['open', 'completed', 'cancelled'];

    private const MAX_PER_PAGE = 50;

    /**
     * The driver's hires, newest first, in pages. Optional filters:
     *  - year (and month): by the hire's effective month;
     *  - status: "open", "completed" or "cancelled";
     *  - per_page (1-50, default 50) and page.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $filters = $request->validate([
            'status' => ['nullable', Rule::in(self::STATUS_GROUPS)],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:'.self::MAX_PER_PAGE],
        ]);

        $query = $driver->hires()
            ->statusGroup($filters['status'] ?? null)
            ->when(
                $request->filled('year'),
                fn ($query) => $query->inMonth(
                    $request->integer('year'),
                    $request->filled('month') ? $request->integer('month') : null,
                ),
            );

        // Cancelled hires are listed (the app has a Cancelled tab) but a
        // "Total Hires" figure shouldn't count them.
        $countedTotal = (clone $query)->counted()->count();

        $hires = $query
            ->with(['package', 'vehicle', 'locations.location', 'trackingPoints', 'expenses'])
            ->latest()
            ->paginate((int) ($filters['per_page'] ?? self::MAX_PER_PAGE));

        return DriverHireResource::collection($hires)->additional(['counted_total' => $countedTotal]);
    }

    /**
     * The years and months that have hires — optionally only hires of one
     * status group ("open", "completed", "cancelled"), so a tab's filter lists
     * just the periods that have something to show.
     */
    public function periods(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $filters = $request->validate(['status' => ['nullable', Rule::in(self::STATUS_GROUPS)]]);

        $periods = MonthlyPeriods::fromTimestamps(
            $driver->hires()->statusGroup($filters['status'] ?? null)->get(['start_time', 'created_at'])->pluck('effective_month_date')
        );

        return response()->json([
            'years' => $periods['years'],
            // A driver with zero hires yet has an empty months_by_year — PHP
            // can't tell an empty array from an empty map, so it would
            // serialize as `[]` instead of `{}` and break the app's
            // `Map<String, dynamic>` parsing. Force object semantics.
            'months_by_year' => (object) $periods['months_by_year'],
        ]);
    }

    public function show(Request $request, Hire $hire): DriverHireResource
    {
        $driver = $request->user()->driver;

        abort_if(! $driver || $hire->driver_id !== $driver->id, 403);

        $hire->load(['package', 'vehicle', 'locations.location', 'trackingPoints', 'expenses']);

        return new DriverHireResource($hire);
    }
}
