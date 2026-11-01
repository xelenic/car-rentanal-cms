<?php

namespace App\Services;

use App\Models\Hire;
use Illuminate\Support\Collection;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * The hire-by-hire CSV breakdown shared by the Hires page's own "Export
 * CSV" (whatever the current filters match) and a driver's Hires tab
 * (one driver, one month) — same columns either way, built from
 * DriverSalaryCalculator::SALARY_PERCENTAGE the same way driver salary is.
 */
class HireCsvExport
{
    public const HEADERS = [
        'Date', 'Hire', 'Full Value of Hire', 'Hire Value', 'Deposit Commission',
        'Fuel', 'High Way Charges', 'Driver Food', 'Other Chargess', 'Cost Of Hire',
        'Driver Charges', 'Full Cost Of Hire', 'Full Saving Of Hire',
        'Driver Payment', 'Deposit', 'Credit Hire', 'Car Repair',
    ];

    /**
     * Streams the CSV for $hires (every hire's `expenses` relation must
     * already be eager-loaded). $monthFigures carries the three columns
     * that aren't derivable from the hires themselves — Driver Payment
     * (salary payable), Deposit (transferred this period) and Car Repair
     * (vehicle maintenance cost) — each left blank (on every row, including
     * Total) when the caller has no single driver/period to compute them
     * for, which is why they're nullable rather than defaulting to 0.
     *
     * @param  array{salary_payable?: ?float, transferred_total?: ?float, vehicle_maintenance_total?: ?float}  $monthFigures
     */
    public static function stream(Collection $hires, string $filename, array $monthFigures = []): StreamedResponse
    {
        $salaryPayable = $monthFigures['salary_payable'] ?? null;
        $transferredTotal = $monthFigures['transferred_total'] ?? null;
        $vehicleMaintenanceTotal = $monthFigures['vehicle_maintenance_total'] ?? null;

        return response()->streamDownload(function () use ($hires, $salaryPayable, $transferredTotal, $vehicleMaintenanceTotal) {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, self::HEADERS);

            $totals = ['full' => 0, 'our' => 0, 'commission' => 0, 'fuel' => 0, 'highway' => 0, 'food' => 0, 'other' => 0, 'cost' => 0, 'charges' => 0, 'fullCost' => 0, 'saving' => 0, 'credit' => 0];

            foreach ($hires as $hire) {
                $figures = self::figuresFor($hire);
                fputcsv($handle, self::rowFor($hire, $figures));

                foreach (['full', 'our', 'commission', 'fuel', 'highway', 'food', 'other', 'cost', 'charges', 'fullCost', 'saving'] as $key) {
                    $totals[$key] += $figures[$key];
                }
                if ($figures['isCredit']) {
                    $totals['credit'] += $figures['full'];
                }
            }

            fputcsv($handle, [
                'Total', '',
                number_format($totals['full'], 2, '.', ''),
                number_format($totals['our'], 2, '.', ''),
                number_format($totals['commission'], 2, '.', ''),
                number_format($totals['fuel'], 2, '.', ''),
                number_format($totals['highway'], 2, '.', ''),
                number_format($totals['food'], 2, '.', ''),
                number_format($totals['other'], 2, '.', ''),
                number_format($totals['cost'], 2, '.', ''),
                number_format($totals['charges'], 2, '.', ''),
                number_format($totals['fullCost'], 2, '.', ''),
                number_format($totals['saving'], 2, '.', ''),
                $salaryPayable !== null ? number_format($salaryPayable, 2, '.', '') : '',
                $transferredTotal !== null ? number_format($transferredTotal, 2, '.', '') : '',
                number_format($totals['credit'], 2, '.', ''),
                $vehicleMaintenanceTotal !== null ? number_format($vehicleMaintenanceTotal, 2, '.', '') : '',
            ]);

            fclose($handle);
        }, $filename, ['Content-Type' => 'text/csv']);
    }

    /** @return array{full: float, our: float, commission: float, fuel: float, highway: float, food: float, other: float, cost: float, charges: float, fullCost: float, saving: float, isCredit: bool} */
    private static function figuresFor(Hire $hire): array
    {
        $byCategory = $hire->expenses->groupBy('category')->map(fn ($group) => round((float) $group->sum('amount'), 2));
        $fuel = $byCategory->get('fuel', 0.0);
        $highway = $byCategory->get('highway', 0.0);
        $food = $byCategory->get('food', 0.0);
        $other = round((float) $byCategory->except(['fuel', 'highway', 'food'])->sum(), 2);
        $cost = round($fuel + $highway + $food + $other, 2);
        $charges = round(((float) $hire->our_hire_value - $cost) * (DriverSalaryCalculator::SALARY_PERCENTAGE / 100), 2);
        $fullCost = round($cost + $charges, 2);
        $saving = round((float) $hire->our_hire_value - $fullCost, 2);

        return [
            'full' => (float) $hire->hire_full_value,
            'our' => (float) $hire->our_hire_value,
            'commission' => (float) $hire->commission,
            'fuel' => $fuel,
            'highway' => $highway,
            'food' => $food,
            'other' => $other,
            'cost' => $cost,
            'charges' => $charges,
            'fullCost' => $fullCost,
            'saving' => $saving,
            'isCredit' => $hire->payment_type === 'credit',
        ];
    }

    private static function rowFor(Hire $hire, array $f): array
    {
        return [
            $hire->effective_month_date?->format('d/m/y'),
            self::summary($hire),
            number_format($f['full'], 2, '.', ''),
            number_format($f['our'], 2, '.', ''),
            number_format($f['commission'], 2, '.', ''),
            $f['fuel'] ? number_format($f['fuel'], 2, '.', '') : '',
            $f['highway'] ? number_format($f['highway'], 2, '.', '') : '',
            $f['food'] ? number_format($f['food'], 2, '.', '') : '',
            $f['other'] ? number_format($f['other'], 2, '.', '') : '',
            number_format($f['cost'], 2, '.', ''),
            number_format($f['charges'], 2, '.', ''),
            number_format($f['fullCost'], 2, '.', ''),
            number_format($f['saving'], 2, '.', ''),
            '',
            '',
            $f['isCredit'] ? number_format($f['full'], 2, '.', '') : '',
            '',
        ];
    }

    /**
     * The same one-line route summary the Hires page's own table shows —
     * see resources/views/admin/hires/index.blade.php.
     */
    public static function summary(Hire $hire): string
    {
        if ($hire->tour_type === 'package') {
            return $hire->package?->name ?? '—';
        }

        if ($hire->tour_type === 'multi_day') {
            return $hire->stayLocations->pluck('location.name')->filter()->join(' → ') ?: '—';
        }

        if ($hire->tour_type === 'day_tour' && $hire->stayLocations->isNotEmpty()) {
            return collect([$hire->fromLocation?->location?->name])
                ->concat($hire->stayLocations->pluck('location.name'))
                ->push($hire->toLocation?->location?->name)
                ->filter()
                ->join(' → ');
        }

        return collect([$hire->fromLocation?->location?->name, $hire->toLocation?->location?->name])->filter()->join(' → ');
    }
}
