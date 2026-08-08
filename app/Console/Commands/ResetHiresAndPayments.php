<?php

namespace App\Console\Commands;

use App\Models\DriverArrearsLoan;
use App\Models\DriverDepositTransfer;
use App\Models\DriverPayroll;
use App\Models\DriverPayrollCarryover;
use App\Models\Hire;
use App\Models\SalaryAdvanceRequest;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

#[Signature('app:reset-hires-and-payments {--force : Skip the confirmation prompt}')]
#[Description('Wipe all hires and payment data (hires, expenses, tracking, payrolls, salary advances, arrears loans, deposit transfers) while keeping drivers, vehicles, locations, customers, and user accounts.')]
class ResetHiresAndPayments extends Command
{
    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        if (! $this->option('force') && ! $this->confirm(
            'This will PERMANENTLY delete all hires, hire expenses, tracking data, driver payrolls, '.
            'salary advances, arrears loans, deposit transfers, and their uploaded files (receipts, '.
            'bank slips) — but will KEEP drivers, vehicles, locations, customers, and user accounts. '.
            'Are you sure you want to continue?'
        )) {
            $this->info('Cancelled. No data was changed.');

            return self::SUCCESS;
        }

        DB::transaction(function () {
            // Each of these cascades to its own child records (deductions,
            // hire locations/expenses/tracking points, etc.) at the DB
            // level, so deleting the parent rows is enough.
            DriverArrearsLoan::query()->delete();
            DriverPayrollCarryover::query()->delete();
            DriverPayroll::query()->delete();
            SalaryAdvanceRequest::query()->delete();
            DriverDepositTransfer::query()->delete();
            Hire::query()->delete();
        });

        $this->clearUploadedFiles();

        $this->newLine();
        $this->info('All hires and payment data has been reset. Drivers, vehicles, locations, customers, and user accounts were left untouched.');

        return self::SUCCESS;
    }

    private function clearUploadedFiles(): void
    {
        $disk = Storage::disk('public');

        foreach (['hire-expenses', 'deposit-slips'] as $directory) {
            $disk->deleteDirectory($directory);
        }

        $this->info('Cleared uploaded files (expense receipts, deposit slips).');
    }
}
