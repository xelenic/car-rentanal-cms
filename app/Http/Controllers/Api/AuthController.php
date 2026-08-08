<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DriverResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $credentials['email'])->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password) || ! $user->hasRole('Driver')) {
            throw ValidationException::withMessages([
                'email' => ['These credentials do not match a driver account.'],
            ]);
        }

        $driver = $user->driver;

        if (! $driver) {
            throw ValidationException::withMessages([
                'email' => ['No driver profile is linked to this account.'],
            ]);
        }

        $token = $user->createToken('driver-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'driver' => new DriverResource($driver),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    public function me(Request $request): DriverResource
    {
        return new DriverResource($request->user()->driver);
    }
}
