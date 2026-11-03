<?php

namespace App\Http\Middleware;

use App\Support\SelectedPeriod;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Whenever a request carries a real ?year=&month= (any admin page's own
 * stepper, the navbar's period switcher, or a bookmarked URL), remember it
 * as the default for every other page — see SelectedPeriod.
 */
class SyncSelectedPeriod
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->filled('year') && $request->filled('month')) {
            $month = $request->integer('month');
            if ($month >= 1 && $month <= 12) {
                SelectedPeriod::remember($request->integer('year'), $month);
            }
        }

        return $next($request);
    }
}
