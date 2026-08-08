# Driver App

A companion mobile app for drivers to sign in and view their assigned hires from the Car Rental CMS.
Dark theme, neon-green accents, iOS-style clean layout.

## Running it

The project is fully scaffolded (`flutter create .` has already been run — `android/`, `ios/`, `macos/`,
`linux/`, `windows/`, and `web/` are all present) and verified: `flutter analyze` reports no issues,
`flutter test` passes, and `flutter build web` builds cleanly.

```bash
cd driver_app
flutter pub get
flutter run              # or: flutter run -d chrome / -d macos / a connected device
```

Start the backend first (see below) so the app has something to talk to.

## Connecting to the backend

The app talks to the Laravel CMS's API (Sanctum token auth), added under `routes/api.php`:

- `POST /api/auth/login` — email + password, restricted to accounts with the **Driver** role
- `POST /api/auth/logout`
- `GET /api/driver/me` — the signed-in driver's profile
- `GET /api/driver/hires` — hires assigned to the signed-in driver (paginated; the app reads `meta.total`
  for the "Total Hire Count" card)

Start the backend first:

```bash
php artisan serve
```

By default it listens on `http://127.0.0.1:8000`. The app's base URL is configured in
[`lib/services/api_client.dart`](lib/services/api_client.dart):

- **Android emulator** — already set to `http://10.0.2.2:8000/api` (the emulator's alias for the host machine).
- **iOS simulator / macOS/desktop/web** — already set to `http://127.0.0.1:8000/api`.
- **Physical device** — replace the host with your computer's LAN IP (e.g. `http://192.168.1.20:8000/api`),
  since the device can't reach `localhost` on your machine.

## Logging in

Only users with the **Driver** role can sign in. A driver's app login credentials are the same email/password
you enter when creating them under **Drivers** in the admin panel — creating a Driver there automatically
registers a matching user account with the Driver role.

## Screens

- **Login** — dark, neon-green branded sign-in.
- **Home** — profile avatar + name, a "Total Hire Count" card (real data, from the API), and a "Your
  Payments" summary card (salary/advance/collection — UI shell, marked "Coming soon"; no payroll backend
  exists yet).
- **Notifications** — two tabs: "Assigned Tours" (the driver's real hires as interactive route cards) and
  "Admin Messages" (empty state for now — no messaging backend exists yet).
- **Options** — a 2-column grid: Fuel Expenses, Driver Foods, Room Charges, Parking Tickets, Highway
  Charges, Others, My Salary, Salary Advance, Payslips & Current Collection, Vehicle Repair. Each opens a
  polished "coming soon" placeholder — these are UI shells, not wired to a backend yet by design.
- **Hire detail** — tour info, locations, vehicle, payment type, total value.

The dark/neon theme lives in [`lib/theme/app_theme.dart`](lib/theme/app_theme.dart) — one place to adjust
colors across the whole app.

## What's here vs. what's not

Built: login, home dashboard, notifications (tours + messages tabs), the options grid, and hire detail —
all real screens wired to the live API where the data exists.

Deliberately **not** shown to drivers: `our_hire_value`, `commission`, or the hire owner's contact details —
those stay admin-only, filtered out server-side in `App\Http\Resources\DriverHireResource`.

Not built yet (all the Options grid items, plus "Your Payments" and "Admin Messages"): expense claims,
salary/payslips, salary advance requests, admin messaging. These need real Laravel tables/APIs before they
can be more than placeholders — ask for any of these next and specify how deep to go.
