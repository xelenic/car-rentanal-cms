<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\HireResource;
use App\Models\Customer;
use App\Models\Driver;
use App\Models\Hire;
use App\Models\Package;
use App\Models\Vehicle;
use App\Services\HireService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * The admin mobile app's Hires API: list, show, create, edit and delete.
 * Every request here requires "hires.view"; store additionally requires
 * "hires.create", update "hires.update" and destroy "hires.delete" — checked
 * directly rather than via route permission middleware since these are
 * Sanctum-token requests, not the web session guard the permission:*
 * middleware assumes.
 */
class HireController extends Controller
{
    public function __construct(private readonly HireService $hires)
    {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorizeView($request);

        $showUpcoming = $request->boolean('upcoming');

        $hires = Hire::query()
            ->with([
                'package', 'customer', 'driver', 'vehicle',
                'fromLocation.location', 'toLocation.location', 'stayLocations.location',
            ])
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('description', 'like', "%{$search}%")
                        ->orWhereHas('customer', function ($query) use ($search) {
                            $query->where('name', 'like', "%{$search}%")
                                ->orWhere('phone', 'like', "%{$search}%");
                        });
                });
            })
            ->when($showUpcoming, function ($query) {
                $query->where('status', 'pending')
                    ->whereNotNull('start_time')
                    ->where('start_time', '>=', now());
            })
            ->when($showUpcoming, fn ($query) => $query->orderBy('start_time'), fn ($query) => $query->latest())
            ->paginate(20);

        return HireResource::collection($hires);
    }

    public function show(Request $request, Hire $hire): HireResource
    {
        $this->authorizeView($request);

        $hire->load([
            'package', 'customer', 'driver', 'vehicle',
            'fromLocation.location', 'toLocation.location', 'stayLocations.location',
        ]);

        return new HireResource($hire);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless($request->user()->can('hires.create'), 403, 'You do not have permission to create hires.');

        $rules = $this->hires->rules($request->input('tour_type'), $request->input('customer_id') === 'new');
        $data = $request->validate($rules);

        $hire = $this->hires->create($data);
        $hire->load([
            'package', 'customer', 'driver', 'vehicle',
            'fromLocation.location', 'toLocation.location', 'stayLocations.location',
        ]);

        return (new HireResource($hire))->response()->setStatusCode(201);
    }

    /**
     * Edits a hire — the same fields and rules as creating one. Status,
     * tracking and cancellation are the driver's business and stay as they are.
     */
    public function update(Request $request, Hire $hire): HireResource
    {
        abort_unless($request->user()->can('hires.update'), 403, 'You do not have permission to edit hires.');

        $rules = $this->hires->rules($request->input('tour_type'), $request->input('customer_id') === 'new');
        $hire = $this->hires->update($hire, $request->validate($rules));
        $hire->load([
            'package', 'customer', 'driver', 'vehicle',
            'fromLocation.location', 'toLocation.location', 'stayLocations.location',
        ]);

        return new HireResource($hire);
    }

    /**
     * Deletes a hire together with everything that hangs off it (its
     * locations, payments, expenses and tracking history) — the same as the
     * web panel's delete.
     */
    public function destroy(Request $request, Hire $hire): JsonResponse
    {
        abort_unless($request->user()->can('hires.delete'), 403, 'You do not have permission to delete hires.');

        $hire->delete();

        return response()->json(['message' => "Hire #{$hire->id} was deleted."]);
    }

    /**
     * Everything the Create Hire screen's pickers need, in one round trip.
     */
    public function referenceData(Request $request): JsonResponse
    {
        $this->authorizeView($request);

        return response()->json([
            'drivers' => Driver::query()->orderBy('name')->get(['id', 'name']),
            'vehicles' => Vehicle::query()->orderBy('model')->get(['id', 'model']),
            'customers' => Customer::query()->orderBy('name')->get(['id', 'name', 'phone']),
            'packages' => Package::query()->orderBy('name')->get(['id', 'name']),
        ]);
    }

    private function authorizeView(Request $request): void
    {
        abort_unless($request->user()->can('hires.view'), 403, 'You do not have permission to view hires.');
    }
}
