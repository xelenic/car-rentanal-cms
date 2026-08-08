# Car Rental CMS

A management platform for a car rental / chauffeur-hire business — an admin panel for the office and a companion mobile app for drivers, sharing one backend and one source of truth.

The system covers the day-to-day of running a hire fleet: taking bookings, assigning drivers and vehicles, tracking a hire while it's on the road, working out what each driver is owed at the end of the month, and keeping tabs on what the fleet itself costs — fuel-adjacent expenses, servicing/repairs, and vehicle leasing/loan installments.

## What it's made of

|Part|Stack|
|---|---|
|**Admin panel**|Laravel 13 + Blade, Bootstrap 5 and Chart.js via CDN (no npm build step), SQLite|
|**Driver app**|Flutter (`driver_app/`) — a companion app drivers use on their own phone|
|**Auth**|Laravel Sanctum (driver app API tokens) + Spatie `laravel-permission` (roles/permissions in the admin panel)|

## Admin panel

Everything the office runs day to day, organized around these areas:

- **Dashboard** — this month's key numbers (Our Hire Value, Driver Salary, Commission, Full Hire Value, Total Profit) with month-over-month deltas and a 6-month trend chart. The **Total Profit** card is clickable and opens the full calculation: hire value → expenses by category → net before salary → driver salary → leasing installments → vehicle repair costs → profit.
- **Fleet** — Vehicles, Repair/service records, and **Leasing** (loan/leasing agreements per vehicle with month-wise settlement tracking, balance-remaining progress, and auto-completion when a loan is paid off).
- **Drivers** — driver profiles, monthly salary calculation and payroll finalization/payment, salary advances, arrears loans, deposit transfers, and a dedicated "Loan Arrears" view.
- **Hires** — bookings for Day Tours and Multi-Day Tours, each with day-by-day itineraries that can hold multiple stay locations per day, live GPS tracking while a hire is in progress, and per-hire expenses.
- **Expenses** — a reporting page breaking down fuel, food, room, parking, and highway charges by driver, by hire, and separately by expenses logged *without* a hire attached, with totals and a trend chart.
- **Customers, Locations, Packages** — supporting records used across bookings.
- **Users, Roles, Permissions** — role-based access control for admin staff.

## Driver app (`driver_app/`)

A Flutter app drivers use directly:

- View assigned hires and their day-by-day itinerary, start/stop GPS tracking during a trip.
- Log expenses (fuel, food, room, parking, highway) either against an active hire or standalone, with a photo receipt.
- Check monthly salary, request salary advances, view arrears-loan and deposit-transfer history.
- Log vehicle maintenance/repair issues from the road.

The app talks to the same Laravel backend over a token-authenticated JSON API (`routes/api.php`).

## Getting started

```bash
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve
```

Default seeded admin login is set up in `database/seeders/RolePermissionSeeder.php` — **change that password** before using this anywhere beyond local development.

For the driver app:

```bash
cd driver_app
flutter pub get
flutter run
```

Point the app at your backend's URL in its API client configuration.
