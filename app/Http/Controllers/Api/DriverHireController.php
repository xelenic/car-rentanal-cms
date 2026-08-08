<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverHireResource;
use App\Models\Hire;
use App\Support\MonthlyPeriods;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class DriverHireController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $hires = $driver->hires()
            ->with(['package', 'vehicle', 'locations.location', 'trackingPoints', 'expenses'])
            ->when($request->filled('year'), fn ($query) => $query->whereYear('created_at', $request->integer('year')))
            ->when($request->filled('month'), fn ($query) => $query->whereMonth('created_at', $request->integer('month')))
            ->latest()
            ->paginate(50);

        return DriverHireResource::collection($hires);
    }

    public function periods(Request $request): JsonResponse
    {
        $driver = $request->user()->driver;

        abort_if(! $driver, 403, 'No driver profile is linked to this account.');

        $periods = MonthlyPeriods::fromTimestamps($driver->hires()->pluck('created_at'));

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
