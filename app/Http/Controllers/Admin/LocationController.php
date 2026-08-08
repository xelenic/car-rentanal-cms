<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Location;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;

class LocationController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:locations.view', only: ['index', 'show']),
            new Middleware('permission:locations.create', only: ['store']),
            new Middleware('permission:locations.update', only: ['update']),
            new Middleware('permission:locations.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $locations = Location::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('description', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        return view('admin.locations.index', [
            'locations' => $locations,
            'search' => $request->string('search')->toString(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);

        $location = Location::create($data);

        return redirect()->route('admin.locations.index')->with('status', "Location \"{$location->name}\" was created.");
    }

    public function update(Request $request, Location $location): RedirectResponse
    {
        $data = $this->validated($request);

        $location->update($data);

        return redirect()->route('admin.locations.index')->with('status', "Location \"{$location->name}\" was updated.");
    }

    public function destroy(Location $location): RedirectResponse
    {
        if ($location->packageItineraries()->exists()) {
            return redirect()->route('admin.locations.index')->with('error', "Location \"{$location->name}\" is used in a package itinerary and cannot be deleted.");
        }

        if ($location->hireLocations()->exists()) {
            return redirect()->route('admin.locations.index')->with('error', "Location \"{$location->name}\" is used in a hire and cannot be deleted.");
        }

        $location->delete();

        return redirect()->route('admin.locations.index')->with('status', "Location \"{$location->name}\" was deleted.");
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);
    }
}
