<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['model', 'condition', 'description', 'seats', 'pax'])]
class Vehicle extends Model
{
    public const CONDITIONS = ['New', 'Excellent', 'Good', 'Fair', 'Poor'];

    /** The validation rules for adding or editing a vehicle — shared by the web panel and the admin app's API. */
    public static function rules(): array
    {
        return [
            'model' => ['required', 'string', 'max:255'],
            'condition' => ['required', 'string', 'in:'.implode(',', self::CONDITIONS)],
            'description' => ['nullable', 'string'],
            'seats' => ['required', 'integer', 'min:1', 'max:100'],
            'pax' => ['required', 'integer', 'min:1', 'max:100'],
        ];
    }

    protected function casts(): array
    {
        return [
            'seats' => 'integer',
            'pax' => 'integer',
        ];
    }

    /**
     * Adds the per-vehicle numbers the admin app shows, as attributes: hire
     * counts per tab (see Hire::scopeTab()), and money totals over the hires
     * that count (cancelled ones earned nothing). Everything covers all time,
     * or just one year/month when $year (and optionally $month) is given; the
     * "month" figures are always for the current month.
     */
    public function scopeWithHireStats(Builder $query, ?int $year = null, ?int $month = null): Builder
    {
        $now = now();
        $inPeriod = fn (Builder $hires) => $year === null ? $hires : $hires->inMonth($year, $month);
        $counted = fn (Builder $hires) => $inPeriod($hires)->counted();
        $thisMonth = fn (Builder $hires) => $hires->counted()->inMonth($now->year, $now->month);

        return $query
            ->withCount([
                'hires as all_count' => $inPeriod,
                'hires as today_count' => fn (Builder $hires) => $inPeriod($hires)->tab('today'),
                'hires as scheduled_count' => fn (Builder $hires) => $inPeriod($hires)->tab('scheduled'),
                'hires as completed_count' => fn (Builder $hires) => $inPeriod($hires)->tab('completed'),
                'hires as cancelled_count' => fn (Builder $hires) => $inPeriod($hires)->tab('cancelled'),
                'hires as running_count' => fn (Builder $hires) => $inPeriod($hires)->where('status', 'started'),
                'hires as counted_count' => $counted,
                'hires as month_count' => $thisMonth,
            ])
            ->withSum(['hires as full_value_total' => $counted], 'hire_full_value')
            ->withSum(['hires as our_value_total' => $counted], 'our_hire_value')
            ->withSum(['hires as month_full_value_total' => $thisMonth], 'hire_full_value')
            ->withSum(['hires as month_our_value_total' => $thisMonth], 'our_hire_value');
    }

    public function hires(): HasMany
    {
        return $this->hasMany(Hire::class);
    }

    public function maintenanceRecords(): HasMany
    {
        return $this->hasMany(VehicleMaintenanceRecord::class);
    }

    public function leasings(): HasMany
    {
        return $this->hasMany(VehicleLeasing::class)->latest('start_date');
    }
}
