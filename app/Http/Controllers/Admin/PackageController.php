<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Location;
use App\Models\Package;
use App\Models\PackageItinerary;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

class PackageController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:packages.view', only: ['index', 'show']),
            new Middleware('permission:packages.create', only: ['store']),
            new Middleware('permission:packages.update', only: ['update']),
            new Middleware('permission:packages.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $packages = Package::query()
            ->withCount('itineraries')
            ->with('itineraries.location')
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where('name', 'like', "%{$search}%");
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        return view('admin.packages.index', [
            'packages' => $packages,
            'search' => $request->string('search')->toString(),
            'locations' => Location::orderBy('name')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $package = DB::transaction(function () use ($data) {
            $package = Package::create([
                'name' => $data['name'],
                'hours' => $data['hours'],
                'price' => $data['price'],
            ]);

            $this->syncItineraries($package, $data['itinerary']);

            return $package;
        });

        return redirect()->route('admin.packages.index')->with('status', "Package \"{$package->name}\" was created.");
    }

    public function update(Request $request, Package $package): RedirectResponse
    {
        $data = $this->validated($request);

        DB::transaction(function () use ($data, $package) {
            $package->update([
                'name' => $data['name'],
                'hours' => $data['hours'],
                'price' => $data['price'],
            ]);

            $this->syncItineraries($package, $data['itinerary']);
        });

        return redirect()->route('admin.packages.index')->with('status', "Package \"{$package->name}\" was updated.");
    }

    public function destroy(Package $package): RedirectResponse
    {
        if ($package->hires()->exists()) {
            return redirect()->route('admin.packages.index')->with('error', "Package \"{$package->name}\" is used in a hire and cannot be deleted.");
        }

        $package->delete();

        return redirect()->route('admin.packages.index')->with('status', "Package \"{$package->name}\" was deleted.");
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'hours' => ['required', 'integer', 'min:1', 'max:1000'],
            'price' => ['required', 'numeric', 'min:0', 'max:9999999.99'],
            'itinerary' => ['required', 'array', 'min:1'],
            'itinerary.*.location_id' => ['required', 'integer', 'exists:locations,id'],
            'itinerary.*.note' => ['nullable', 'string', 'max:255'],
        ]);
    }

    private function syncItineraries(Package $package, array $itinerary): void
    {
        $package->itineraries()->delete();

        foreach (array_values($itinerary) as $index => $stop) {
            PackageItinerary::create([
                'package_id' => $package->id,
                'location_id' => $stop['location_id'],
                'order' => $index,
                'note' => $stop['note'] ?? null,
            ]);
        }
    }
}
