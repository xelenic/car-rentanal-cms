<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Driver;
use App\Models\Hire;
use App\Models\Package;
use App\Models\Vehicle;
use App\Services\HireService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;

class HireController extends Controller implements HasMiddleware
{
    public function __construct(private readonly HireService $hires)
    {
    }

    public static function middleware(): array
    {
        return [
            new Middleware('permission:hires.view', only: ['index', 'show', 'tracking']),
            new Middleware('permission:hires.create', only: ['store']),
            new Middleware('permission:hires.update', only: ['update']),
            new Middleware('permission:hires.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $showUpcoming = $request->boolean('upcoming');

        $upcomingScope = fn ($query) => $query->where('status', 'pending')
            ->whereNotNull('start_time')
            ->where('start_time', '>=', now());

        $hires = Hire::query()
            ->with([
                'package', 'customer', 'driver', 'vehicle', 'trackingPoints', 'expenses', 'payments',
                'locations.location', 'fromLocation.location', 'toLocation.location', 'stayLocations.location',
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
            ->when($showUpcoming, $upcomingScope)
            // Upcoming hires read soonest-first; otherwise newest-created-first, as before.
            ->when($showUpcoming, fn ($query) => $query->orderBy('start_time'), fn ($query) => $query->latest())
            ->paginate(10)
            ->withQueryString();

        return view('admin.hires.index', [
            'hires' => $hires,
            'search' => $request->string('search')->toString(),
            'showUpcoming' => $showUpcoming,
            'upcomingCount' => Hire::query()->tap($upcomingScope)->count(),
            'packages' => Package::orderBy('name')->get(),
            'customers' => Customer::orderBy('name')->get(),
            'drivers' => Driver::orderBy('name')->get(),
            'vehicles' => Vehicle::orderBy('model')->get(),
            'googleMapsApiKey' => config('services.google_maps.key'),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $hire = $this->hires->create($data);

        return redirect()->route('admin.hires.index')->with('status', "Hire #{$hire->id} was created.");
    }

    public function update(Request $request, Hire $hire): RedirectResponse
    {
        $data = $this->validated($request);

        $hire = $this->hires->update($hire, $data);

        return redirect()->route('admin.hires.index')->with('status', "Hire #{$hire->id} was updated.");
    }

    public function destroy(Hire $hire): RedirectResponse
    {
        $hire->delete();

        return redirect()->route('admin.hires.index')->with('status', "Hire #{$hire->id} was deleted.");
    }

    /**
     * Polled by the "Location Track" modal (see hires/index.blade.php) so
     * it can update live while a driver is out on an active hire, instead
     * of only ever showing whatever was on the page at the last full load.
     */
    public function tracking(Hire $hire): JsonResponse
    {
        $hire->load('trackingPoints');

        return response()->json([
            'status' => $hire->status,
            'status_label' => $hire->status_label,
            'is_tracking' => $hire->is_tracking,
            'total_distance_km' => $hire->total_distance_km,
            'points' => $hire->trackingPoints->map(fn ($p) => ['lat' => $p->latitude, 'lng' => $p->longitude])->values(),
        ]);
    }

    private function validated(Request $request): array
    {
        $rules = $this->hires->rules($request->input('tour_type'), $request->input('customer_id') === 'new');

        return $request->validate($rules);
    }
}
