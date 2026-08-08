<?php

namespace App\Support;

use Illuminate\Support\Collection;

class MonthlyPeriods
{
    /**
     * Given a collection of Carbon-ish timestamps, group them into distinct
     * years and the months present within each year, both sorted most
     * recent first. Computed in PHP (rather than a raw YEAR()/MONTH() SQL
     * query) so this works the same regardless of the underlying database
     * driver.
     *
     * @return array{years: array<int, int>, months_by_year: array<int, array<int, int>>}
     */
    public static function fromTimestamps(Collection $timestamps): array
    {
        $monthsByYear = [];

        foreach ($timestamps as $timestamp) {
            $year = (int) $timestamp->format('Y');
            $month = (int) $timestamp->format('n');
            $monthsByYear[$year] ??= [];
            if (! in_array($month, $monthsByYear[$year], true)) {
                $monthsByYear[$year][] = $month;
            }
        }

        krsort($monthsByYear);
        foreach ($monthsByYear as &$months) {
            rsort($months);
        }

        return [
            'years' => array_keys($monthsByYear),
            'months_by_year' => $monthsByYear,
        ];
    }
}
