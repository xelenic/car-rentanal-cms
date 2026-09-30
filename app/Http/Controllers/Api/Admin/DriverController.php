<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\Admin\DriverResource;
use App\Models\Driver;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

/**
 * The admin mobile app's Drivers API: the roster, adding, editing and
 * removing a driver. Mirrors the web panel's Admin\DriverController for the
 * fields this app manages, minus the two optional document uploads (no
 * multipart precedent exists in this app, and the web form treats them as
 * optional too) — a driver here is always also a User with the Driver role,
 * exactly as the web panel creates them.
 */
class DriverController extends Controller
{
    private const PER_PAGE = 20;

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorizeView($request);

        $drivers = Driver::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('contact_number', 'like', "%{$search}%");
                });
            })
            ->orderBy('name')
            ->paginate(self::PER_PAGE);

        return DriverResource::collection($drivers);
    }

    public function store(Request $request): JsonResponse
    {
        abort_unless($request->user()->can('drivers.create'), 403, 'You do not have permission to add drivers.');

        $data = $this->validated($request);

        $driver = DB::transaction(function () use ($data) {
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'],
                'password' => Hash::make($data['password']),
            ]);
            $user->syncRoles(['Driver']);

            return Driver::create([
                ...$data,
                'user_id' => $user->id,
                'password' => Hash::make($data['password']),
            ]);
        });

        return (new DriverResource($driver))->response()->setStatusCode(201);
    }

    public function show(Request $request, Driver $driver): DriverResource
    {
        $this->authorizeView($request);

        return new DriverResource($driver);
    }

    public function update(Request $request, Driver $driver): DriverResource
    {
        abort_unless($request->user()->can('drivers.update'), 403, 'You do not have permission to edit drivers.');

        $data = $this->validated($request, $driver);
        $plainPassword = $data['password'] ?? null;
        unset($data['password']);

        DB::transaction(function () use ($data, $plainPassword, $driver) {
            $user = $driver->user;
            if ($user) {
                $user->update([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    ...($plainPassword ? ['password' => Hash::make($plainPassword)] : []),
                ]);
                $user->syncRoles(['Driver']);
            } else {
                $user = User::create([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    'password' => Hash::make($plainPassword ?? Str::random(24)),
                ]);
                $user->syncRoles(['Driver']);
                $data['user_id'] = $user->id;
            }

            if ($plainPassword) {
                $data['password'] = Hash::make($plainPassword);
            }

            $driver->update($data);
        });

        return new DriverResource($driver->fresh());
    }

    public function destroy(Request $request, Driver $driver): JsonResponse
    {
        abort_unless($request->user()->can('drivers.delete'), 403, 'You do not have permission to delete drivers.');

        DB::transaction(function () use ($driver) {
            $driver->user?->delete();
            $driver->delete();
        });

        return response()->json(['message' => "Driver \"{$driver->name}\" was deleted."]);
    }

    private function validated(Request $request, ?Driver $driver = null): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'license' => ['required', 'string', 'max:255'],
            'contact_number' => ['required', 'string', 'max:30'],
            'additional_phone_number' => ['nullable', 'string', 'max:30'],
            'email' => [
                'required', 'string', 'email', 'max:255',
                Rule::unique('drivers', 'email')->ignore($driver?->id),
                Rule::unique('users', 'email')->ignore($driver?->user_id),
            ],
            'password' => [$driver ? 'nullable' : 'required', 'string', 'min:8'],
        ]);
    }

    private function authorizeView(Request $request): void
    {
        abort_unless($request->user()->can('drivers.view'), 403, 'You do not have permission to view drivers.');
    }
}
