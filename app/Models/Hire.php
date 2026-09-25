<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

#[Fillable([
    'tour_type', 'package_id', 'start_time', 'end_time',
    'hire_full_value', 'our_hire_value', 'customer_id',
    'driver_id', 'vehicle_id', 'description', 'payment_type', 'status',
    'tracking_started_at', 'tracking_stopped_at',
])]
class Hire extends Model
{
    public const TOUR_TYPES = [
        'drop_pickup' => 'Drop and Pickup',
        'multi_day' => 'Multi day tours',
        'day_tour' => 'Day tours',
        'package' => 'Packages',
    ];

    public const PAYMENT_TYPES = [
        'cash' => 'Cash',
        'credit' => 'Credit',
    ];

    public const STATUSES = [
        'pending' => 'Pending',
        'started' => 'Driver Hire Started',
        'completed' => 'Completed',
    ];

    protected function casts(): array
    {
        return [
            'start_time' => 'datetime',
            'end_time' => 'datetime',
            'hire_full_value' => 'decimal:2',
            'our_hire_value' => 'decimal:2',
            'tracking_started_at' => 'datetime',
            'tracking_stopped_at' => 'datetime',
        ];
    }

    public function getCommissionAttribute(): float
    {
        return round($this->hire_full_value - $this->our_hire_value, 2);
    }

    public function getIsTrackingAttribute(): bool
    {
        return $this->tracking_started_at !== null && $this->tracking_stopped_at === null;
    }

    public function getStatusLabelAttribute(): string
    {
        return self::STATUSES[$this->status] ?? $this->status;
    }

    /**
     * A hire scheduled for a future date/time that hasn't started yet —
     * still "pending" and its start_time (the general "when is this hire
     * scheduled" field for every tour type, not just packages) is ahead of
     * now.
     */
    public function getIsUpcomingAttribute(): bool
    {
        return $this->status === 'pending' && $this->start_time !== null && $this->start_time->isFuture();
    }

    /**
     * The month a hire actually belongs to for every monthly report/salary
     * calculation: its scheduled start_time when one was set, otherwise
     * when it was recorded (created_at) — a hire scheduled for next month
     * must not count toward this month's numbers just because it happened
     * to be booked today. Used by scopeInMonth() and by every "available
     * year/month" period picker (admin panel and driver app alike).
     */
    public function getEffectiveMonthDateAttribute(): ?Carbon
    {
        return $this->start_time ?? $this->created_at;
    }

    /**
     * Scopes hires to the given calendar year (and, optionally, month) by
     * their effective month (see getEffectiveMonthDateAttribute()) rather
     * than raw created_at, so a hire scheduled ahead of time is only
     * counted in the year/month it's actually scheduled for. $month may be
     * omitted to filter by year alone.
     */
    public function scopeInMonth(Builder $query, int $year, ?int $month = null): Builder
    {
        return $query->where(function (Builder $query) use ($year, $month) {
            $query->where(function (Builder $query) use ($year, $month) {
                $query->whereNotNull('start_time')->whereYear('start_time', $year);
                if ($month !== null) {
                    $query->whereMonth('start_time', $month);
                }
            })->orWhere(function (Builder $query) use ($year, $month) {
                $query->whereNull('start_time')->whereYear('created_at', $year);
                if ($month !== null) {
                    $query->whereMonth('created_at', $month);
                }
            });
        });
    }

    public function getIsCompletedAttribute(): bool
    {
        return $this->status === 'completed';
    }

    /**
     * GPS fixes wobble by several metres even while the vehicle is parked, and
     * a fix arrives every 15 seconds — adding up every wobble would invent
     * kilometres of "travel" per hour. A move only counts once a fix is at
     * least this far from the last position that counted.
     */
    public const TRACK_MIN_MOVE_METERS = 20;

    public function getTotalDistanceKmAttribute(): float
    {
        $points = $this->relationLoaded('trackingPoints')
            ? $this->trackingPoints
            : $this->trackingPoints()->get();

        $total = 0.0;
        $anchor = null;

        foreach ($points as $point) {
            if ($anchor === null) {
                $anchor = $point;

                continue;
            }

            $km = self::haversineKm(
                $anchor->latitude,
                $anchor->longitude,
                $point->latitude,
                $point->longitude,
            );

            if ($km * 1000 >= self::TRACK_MIN_MOVE_METERS) {
                $total += $km;
                $anchor = $point;
            }
        }

        return round($total, 2);
    }

    public static function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadiusKm = 6371;

        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadiusKm * $c;
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(Package::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }

    public function vehicle(): BelongsTo
    {
        return $this->belongsTo(Vehicle::class);
    }

    public function locations(): HasMany
    {
        return $this->hasMany(HireLocation::class)->orderBy('order');
    }

    public function fromLocation(): HasOne
    {
        return $this->hasOne(HireLocation::class)->where('role', 'from');
    }

    public function toLocation(): HasOne
    {
        return $this->hasOne(HireLocation::class)->where('role', 'to');
    }

    /**
     * The place the driver has to reach before this hire can begin — the
     * driver app highlights its Start button once the phone is near it.
     * Depends on the tour type: the "from" location for drop-and-pickup and
     * day tours, the first stay for multi day tours, the first stop of a
     * package's itinerary otherwise. Null when the hire has none.
     */
    public function pickupLocation(): ?Location
    {
        $locations = $this->relationLoaded('locations')
            ? $this->locations
            : $this->locations()->with('location')->get();

        $from = $locations->firstWhere('role', 'from');
        if ($from !== null) {
            return $from->location;
        }

        $stay = $locations->where('role', 'stay')->sortBy([['day_number', 'asc'], ['order', 'asc']])->first();
        if ($stay !== null) {
            return $stay->location;
        }

        return $this->package?->itineraries()->with('location')->orderBy('order')->first()?->location;
    }

    /**
     * Every place on this hire's trip that has coordinates, in journey order —
     * what the driver app plots on its map. Roles follow the trip: the first
     * place is the "pickup", the last the "end" and anything between a "stop"
     * (a lone place is a "single"). Roles are worked out over the whole trip
     * *before* places without coordinates are dropped, so a missing pickup
     * never makes the first stop look like one.
     *
     * Drop-and-pickup and day tours run from → to; multi day tours through
     * their stays (by day, then position); package tours through the
     * package's itinerary.
     *
     * @return list<array{role: string, name: string, latitude: float, longitude: float}>
     */
    public function mapLocations(): array
    {
        $links = $this->relationLoaded('locations')
            ? $this->locations
            : $this->locations()->with('location')->get();

        $stays = fn () => $links->where('role', 'stay')->sortBy([['day_number', 'asc'], ['order', 'asc']])->pluck('location');

        $trip = match ($this->tour_type) {
            'multi_day' => $stays(),
            'package' => $this->package?->itineraries()->with('location')->orderBy('order')->get()->pluck('location'),
            default => collect([$links->firstWhere('role', 'from')?->location, $links->firstWhere('role', 'to')?->location])
                ->filter(),
        } ?? collect();

        // A hire of any type that has only stays still gets a trip.
        if ($trip->isEmpty()) {
            $trip = $stays();
        }

        $last = $trip->count() - 1;

        return $trip->values()
            ->map(fn (?Location $location, int $i) => $location === null ? null : [
                'role' => $last === 0 ? 'single' : ($i === 0 ? 'pickup' : ($i === $last ? 'end' : 'stop')),
                'name' => $location->name,
                'latitude' => $location->latitude,
                'longitude' => $location->longitude,
            ])
            ->filter(fn (?array $place) => $place !== null && $place['latitude'] !== null && $place['longitude'] !== null)
            ->values()
            ->all();
    }

    public function stayLocations(): HasMany
    {
        return $this->hasMany(HireLocation::class)->where('role', 'stay')->orderBy('order');
    }

    /**
     * A multi-day tour's stay locations grouped by day — each day can hold
     * more than one location, in order. Keyed by day_number (1, 2, 3, ...).
     *
     * @return Collection<int, Collection<int, HireLocation>>
     */
    public function stayLocationsByDay(): Collection
    {
        $locations = $this->relationLoaded('stayLocations') ? $this->stayLocations : $this->stayLocations()->get();

        return $locations->groupBy('day_number')->sortKeys();
    }

    public function trackingPoints(): HasMany
    {
        return $this->hasMany(HireTrackingPoint::class)->orderBy('recorded_at');
    }

    public function expenses(): HasMany
    {
        return $this->hasMany(HireExpense::class)->latest();
    }

    public function getFuelCostTotalAttribute(): float
    {
        $expenses = $this->relationLoaded('expenses')
            ? $this->expenses
            : $this->expenses()->get();

        return round((float) $expenses->where('category', 'fuel')->sum('amount'), 2);
    }

    /**
     * "Claim Payment" records against this hire — mainly meaningful for
     * payment_type "credit" (cash is assumed collected on the spot), but
     * not restricted to it in case that's ever useful.
     */
    public function payments(): HasMany
    {
        return $this->hasMany(HirePayment::class)->orderByDesc('paid_at')->latest('id');
    }

    public function getPaidAmountAttribute(): float
    {
        $payments = $this->relationLoaded('payments') ? $this->payments : $this->payments()->get();

        return round((float) $payments->sum('amount'), 2);
    }

    public function getBalanceRemainingAttribute(): float
    {
        return round(max($this->hire_full_value - $this->paid_amount, 0), 2);
    }

    /**
     * "unpaid" (nothing claimed yet), "partial" (some but not all claimed),
     * or "paid" (fully claimed) — drives the Hires page's Claim Payment
     * button vs. "Fully Paid" badge.
     */
    public function getPaymentStatusAttribute(): string
    {
        if ($this->paid_amount <= 0) {
            return 'unpaid';
        }

        return $this->balance_remaining <= 0 ? 'paid' : 'partial';
    }
}
