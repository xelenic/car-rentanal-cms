<?php

use App\Models\Driver;
use App\Models\Hire;
use App\Models\HireLocation;
use App\Models\Location;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;

uses(RefreshDatabase::class);

const DIRECTIONS_URL = 'https://maps.googleapis.com/maps/api/directions/json*';

beforeEach(function () {
    config(['services.google_maps.key' => 'test-key']);
    Cache::flush();
});

function routeHire(array $attributes = [], bool $withPlaces = true, bool $signedIn = true): array
{
    $user = User::factory()->create();
    $driver = Driver::create([
        'user_id' => $user->id, 'name' => 'Driver', 'license' => 'B1', 'contact_number' => '077',
        'email' => uniqid('driver').'@example.test', 'password' => 'secret-pass',
    ]);
    $hire = Hire::create($attributes + [
        'tour_type' => 'drop_pickup', 'hire_full_value' => 1000, 'our_hire_value' => 800,
        'payment_type' => 'cash', 'driver_id' => $driver->id,
    ]);

    if ($withPlaces) {
        HireLocation::create(['hire_id' => $hire->id, 'role' => 'from', 'location_id' => Location::create(['name' => 'Colombo Fort', 'latitude' => 6.9344, 'longitude' => 79.8428])->id]);
        HireLocation::create(['hire_id' => $hire->id, 'role' => 'to', 'location_id' => Location::create(['name' => 'Kandy', 'latitude' => 7.2906, 'longitude' => 80.6337])->id]);
    }

    if ($signedIn) {
        Sanctum::actingAs($user);
    }

    return [$user, $hire];
}

function googleRoute(string $polyline = '_p~iF~ps|U_ulLnnqC_mqNvxq`@'): array
{
    return [
        'status' => 'OK',
        'routes' => [[
            'overview_polyline' => ['points' => $polyline],
            'legs' => [
                ['distance' => ['value' => 10000], 'duration' => ['value' => 900]],
                ['distance' => ['value' => 84000], 'duration' => ['value' => 6300]],
            ],
        ]],
    ];
}

test('before the hire starts the route runs from the driver through the pickup to the end', function () {
    Http::fake([DIRECTIONS_URL => Http::response(googleRoute())]);
    [, $hire] = routeHire();

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.05&origin_lng=80.22")
        ->assertOk()
        ->assertExactJson(['polyline' => '_p~iF~ps|U_ulLnnqC_mqNvxq`@', 'distance_m' => 94000, 'duration_s' => 7200]);

    Http::assertSent(function (HttpRequest $request) {
        parse_str((string) parse_url($request->url(), PHP_URL_QUERY), $query);

        return $query['origin'] === '6.05,80.22'
            && $query['waypoints'] === '6.9344,79.8428'   // the pickup is on the way…
            && $query['destination'] === '7.2906,80.6337' // …and the end is where it finishes
            && $query['mode'] === 'driving'
            && $query['key'] === 'test-key';
    });
});

test('once the hire has started the pickup is behind the driver: straight to the end', function () {
    Http::fake([DIRECTIONS_URL => Http::response(googleRoute())]);
    [, $hire] = routeHire(['status' => 'started', 'tracking_started_at' => now()->subMinutes(20)]);

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.95&origin_lng=79.90")->assertOk();

    Http::assertSent(function (HttpRequest $request) {
        parse_str((string) parse_url($request->url(), PHP_URL_QUERY), $query);

        return $query['destination'] === '7.2906,80.6337' && ! array_key_exists('waypoints', $query);
    });
});

test('an identical request shortly afterwards is answered from the cache, not billed again', function () {
    Http::fake([DIRECTIONS_URL => Http::response(googleRoute())]);
    [, $hire] = routeHire();

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.0500&origin_lng=80.2200")->assertOk();
    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.0501&origin_lng=80.2201")->assertOk(); // ~15 m away

    Http::assertSentCount(1);
});

test('a driver who has moved on gets a fresh route', function () {
    Http::fake([DIRECTIONS_URL => Http::response(googleRoute())]);
    [, $hire] = routeHire();

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.05&origin_lng=80.22")->assertOk();
    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.50&origin_lng=79.95")->assertOk();

    Http::assertSentCount(2);
});

test('a Google failure (bad key, disabled API, quota) is a 502 the app can shrug off', function () {
    Http::fake([DIRECTIONS_URL => Http::response(['status' => 'REQUEST_DENIED', 'error_message' => 'The provided API key is invalid.'])]);
    [, $hire] = routeHire();

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.05&origin_lng=80.22")
        ->assertStatus(502)
        ->assertJsonPath('message', 'Could not plan a route right now.');
});

test('a failed lookup is not cached', function () {
    Http::fakeSequence(DIRECTIONS_URL)
        ->push(['status' => 'OVER_QUERY_LIMIT'])
        ->push(googleRoute());
    [, $hire] = routeHire();

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.05&origin_lng=80.22")->assertStatus(502);
    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.05&origin_lng=80.22")->assertOk();
});

test('no drivable route is a 422', function () {
    Http::fake([DIRECTIONS_URL => Http::response(['status' => 'ZERO_RESULTS', 'routes' => []])]);
    [, $hire] = routeHire();

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.05&origin_lng=80.22")->assertStatus(422);
});

test('a hire with no located destination, or a completed one, is refused without calling Google', function () {
    Http::fake();
    [, $noPlaces] = routeHire(withPlaces: false);
    $this->getJson("/api/driver/hires/{$noPlaces->id}/route?origin_lat=6.05&origin_lng=80.22")
        ->assertStatus(422)
        ->assertJsonPath('message', 'This hire has no destination with saved coordinates.');

    [, $done] = routeHire(['status' => 'completed']);
    $this->getJson("/api/driver/hires/{$done->id}/route?origin_lat=6.05&origin_lng=80.22")->assertStatus(422);

    Http::assertNothingSent();
});

test('the origin is required and must be a real coordinate', function () {
    Http::fake();
    [, $hire] = routeHire();

    $this->getJson("/api/driver/hires/{$hire->id}/route")->assertStatus(422)->assertJsonValidationErrors(['origin_lat', 'origin_lng']);
    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=95&origin_lng=80")->assertStatus(422)->assertJsonValidationErrors(['origin_lat']);
    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=abc&origin_lng=80")->assertStatus(422);

    Http::assertNothingSent();
});

test('only the hire\'s own driver can plan its route', function () {
    Http::fake();
    [, $hire] = routeHire();

    $other = User::factory()->create();
    Driver::create(['user_id' => $other->id, 'name' => 'Other', 'license' => 'X', 'contact_number' => '1', 'email' => 'other@example.test', 'password' => 'secret-pass']);
    Sanctum::actingAs($other);

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.05&origin_lng=80.22")->assertForbidden();
    Http::assertNothingSent();
});

test('a signed-out request is rejected', function () {
    Http::fake();
    [, $hire] = routeHire(signedIn: false);

    $this->getJson("/api/driver/hires/{$hire->id}/route?origin_lat=6.05&origin_lng=80.22")->assertUnauthorized();
    Http::assertNothingSent();
});
