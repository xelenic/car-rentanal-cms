<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
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

    public function getIsCompletedAttribute(): bool
    {
        return $this->status === 'completed';
    }

    public function getTotalDistanceKmAttribute(): float
    {
        $points = $this->relationLoaded('trackingPoints')
            ? $this->trackingPoints
            : $this->trackingPoints()->get();

        $total = 0.0;
        $previous = null;

        foreach ($points as $point) {
            if ($previous !== null) {
                $total += self::haversineKm(
                    $previous->latitude,
                    $previous->longitude,
                    $point->latitude,
                    $point->longitude,
                );
            }
            $previous = $point;
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
}
