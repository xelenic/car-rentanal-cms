<?php

namespace App\Support;

/**
 * The year/month the navbar's own period switcher last picked, remembered
 * in the session so it carries over as the default across every admin page
 * that has a month concept (Dashboard, Drivers, Vehicles) — until a page's
 * own request explicitly asks for a different one (its own prev/next
 * arrows, or a bookmarked URL with ?year=&month=). See
 * SyncSelectedPeriod, the middleware that keeps this in sync with
 * whatever ?year=&month= a request actually used.
 */
class SelectedPeriod
{
    private const YEAR_KEY = 'admin_period_year';

    private const MONTH_KEY = 'admin_period_month';

    /** The session's remembered year, or $fallback (else this real month) when nothing's been picked yet. */
    public static function year(?int $fallback = null): int
    {
        return (int) session(self::YEAR_KEY, $fallback ?? (int) now()->format('Y'));
    }

    /** The session's remembered month, or $fallback (else this real month) when nothing's been picked yet. */
    public static function month(?int $fallback = null): int
    {
        $month = (int) session(self::MONTH_KEY, $fallback ?? (int) now()->format('n'));

        return $month >= 1 && $month <= 12 ? $month : (int) now()->format('n');
    }

    public static function remember(int $year, int $month): void
    {
        session([self::YEAR_KEY => $year, self::MONTH_KEY => $month]);
    }
}
