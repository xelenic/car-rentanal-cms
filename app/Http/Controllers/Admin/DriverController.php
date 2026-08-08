<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Models\DriverArrearsLoan;
use App\Models\DriverDepositTransfer;
use App\Models\DriverPayroll;
use App\Models\Hire;
use App\Models\User;
use App\Services\DriverSalaryCalculator;
use App\Support\MonthlyPeriods;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class DriverController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [
            new Middleware('permission:drivers.view', only: ['index', 'show']),
            new Middleware('permission:drivers.create', only: ['store']),
            new Middleware('permission:drivers.update', only: ['update']),
            new Middleware('permission:drivers.delete', only: ['destroy']),
        ];
    }

    public function index(Request $request): View
    {
        $drivers = Driver::query()
            ->when($request->string('search')->toString(), function ($query, $search) {
                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('contact_number', 'like', "%{$search}%");
                });
            })
            ->latest()
            ->paginate(10)
            ->withQueryString();

        $periods = MonthlyPeriods::fromTimestamps(Hire::query()->pluck('created_at'));
        $availableYears = $periods['years'];
        $monthsByYear = $periods['months_by_year'];

        $selectedYear = $request->filled('year')
            ? $request->integer('year')
            : ($availableYears[0] ?? (int) now()->format('Y'));

        $selectedMonth = $request->filled('month')
            ? $request->integer('month')
            : ($monthsByYear[$selectedYear][0] ?? (int) now()->format('n'));

        $salaries = $drivers->getCollection()->mapWithKeys(
            fn (Driver $driver) => [$driver->id => DriverSalaryCalculator::calculate($driver, $selectedYear, $selectedMonth)]
        );

        $summary = DriverSalaryCalculator::calculateForAllDrivers($selectedYear, $selectedMonth);
        // Company profit: what's left of the net after paying out driver
        // salaries. Deliberately kept out of DriverSalaryCalculator's shared
        // return shape since that same method feeds the driver-facing API —
        // this figure is admin-only.
        $summary['profit'] = round($summary['net_before_salary'] - $summary['salary'], 2);

        $driverIds = $drivers->getCollection()->pluck('id');

        $payrolls = DriverPayroll::query()
            ->whereIn('driver_id', $driverIds)
            ->where('year', $selectedYear)
            ->where('month', $selectedMonth)
            ->with(['finalizedBy', 'paidBy'])
            ->get()
            ->keyBy('driver_id');

        $hiresByDriver = Hire::query()
            ->whereIn('driver_id', $driverIds)
            ->whereYear('created_at', $selectedYear)
            ->whereMonth('created_at', $selectedMonth)
            ->with(['fromLocation', 'toLocation'])
            ->latest()
            ->get()
            ->groupBy('driver_id');

        $depositTransferTotals = DriverDepositTransfer::query()
            ->whereIn('driver_id', $driverIds)
            ->where('year', $selectedYear)
            ->where('month', $selectedMonth)
            ->get()
            ->groupBy('driver_id')
            ->map(fn ($group) => round((float) $group->sum('amount'), 2));

        $arrearsLoansByDriver = DriverArrearsLoan::query()
            ->whereIn('driver_id', $driverIds)
            ->where('source_year', $selectedYear)
            ->where('source_month', $selectedMonth)
            ->with('deductions')
            ->latest()
            ->get()
            ->groupBy('driver_id');

        return view('admin.drivers.index', [
            'drivers' => $drivers,
            'salaries' => $salaries,
            'summary' => $summary,
            'payrolls' => $payrolls,
            'hiresByDriver' => $hiresByDriver,
            'depositTransferTotals' => $depositTransferTotals,
            'arrearsLoansByDriver' => $arrearsLoansByDriver,
            'periodLabel' => now()->setDate($selectedYear, $selectedMonth, 1)->format('F Y'),
            'availableYears' => $availableYears,
            'monthsByYear' => $monthsByYear,
            'selectedYear' => $selectedYear,
            'selectedMonth' => $selectedMonth,
            'search' => $request->string('search')->toString(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);
        unset($data['driver_id_softcopy'], $data['tourism_board_license']);

        $plainPassword = $data['password'];
        $data['driver_id_softcopy_path'] = $this->storeFile($request, 'driver_id_softcopy');
        $data['tourism_board_license_path'] = $this->storeFile($request, 'tourism_board_license');

        $driver = DB::transaction(function () use ($data, $plainPassword) {
            $user = User::create([
                'name' => $data['name'],
                'email' => $data['email'],
                'password' => Hash::make($plainPassword),
            ]);
            $user->syncRoles(['Driver']);

            $data['user_id'] = $user->id;
            $data['password'] = Hash::make($plainPassword);

            return Driver::create($data);
        });

        return redirect()->route('admin.drivers.index')->with('status', "Driver \"{$driver->name}\" was created and registered as a user with the Driver role.");
    }

    public function update(Request $request, Driver $driver): RedirectResponse
    {
        $data = $this->validated($request, $driver);
        unset($data['driver_id_softcopy'], $data['tourism_board_license']);

        $plainPassword = $data['password'] ?? null;
        unset($data['password']);

        if ($path = $this->storeFile($request, 'driver_id_softcopy')) {
            $this->deleteFile($driver->driver_id_softcopy_path);
            $data['driver_id_softcopy_path'] = $path;
        }

        if ($path = $this->storeFile($request, 'tourism_board_license')) {
            $this->deleteFile($driver->tourism_board_license_path);
            $data['tourism_board_license_path'] = $path;
        }

        DB::transaction(function () use ($data, $plainPassword, $driver) {
            if ($plainPassword) {
                $data['password'] = Hash::make($plainPassword);
            }

            $user = $driver->user;

            if ($user) {
                $user->update([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    ...($plainPassword ? ['password' => Hash::make($plainPassword)] : []),
                ]);
                $user->syncRoles(['Driver']);
            } else {
                $user = User::create([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    'password' => Hash::make($plainPassword ?? Str::random(24)),
                ]);
                $user->syncRoles(['Driver']);
                $data['user_id'] = $user->id;
            }

            $driver->update($data);
        });

        return redirect()->route('admin.drivers.index')->with('status', "Driver \"{$driver->name}\" was updated.");
    }

    public function destroy(Driver $driver): RedirectResponse
    {
        DB::transaction(function () use ($driver) {
            $this->deleteFile($driver->driver_id_softcopy_path);
            $this->deleteFile($driver->tourism_board_license_path);

            $driver->user?->delete();
            $driver->delete();
        });

        return redirect()->route('admin.drivers.index')->with('status', "Driver \"{$driver->name}\" was deleted.");
    }

    private function validated(Request $request, ?Driver $driver = null): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'license' => ['required', 'string', 'max:255'],
            'driver_id_softcopy' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:5120'],
            'contact_number' => ['required', 'string', 'max:30'],
            'additional_phone_number' => ['nullable', 'string', 'max:30'],
            'tourism_board_license' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:5120'],
            'email' => [
                'required', 'string', 'email', 'max:255',
                Rule::unique('drivers', 'email')->ignore($driver?->id),
                Rule::unique('users', 'email')->ignore($driver?->user_id),
            ],
            'password' => [$driver ? 'nullable' : 'required', 'string', 'min:8', 'confirmed'],
        ]);
    }

    private function storeFile(Request $request, string $field): ?string
    {
        if (! $request->hasFile($field)) {
            return null;
        }

        return $request->file($field)->store('drivers', 'public');
    }

    private function deleteFile(?string $path): void
    {
        if ($path) {
            Storage::disk('public')->delete($path);
        }
    }
}
