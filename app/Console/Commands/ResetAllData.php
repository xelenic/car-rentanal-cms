<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

#[Signature('app:reset-all-data {--force : Skip the confirmation prompt}')]
#[Description('Wipe all application data and restore a fresh seeded state (roles, permissions, and the default admin user).')]
class ResetAllData extends Command
{
    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        if (! $this->option('force') && ! $this->confirm(
            'This will PERMANENTLY delete all data — vehicles, drivers, locations, packages, '.
            'customers, hires, expenses, salary advances, payrolls, deposit transfers, and all '.
            'uploaded files (driver documents, receipts, bank slips) — then restore a fresh '.
            'seeded state. Are you sure you want to continue?'
        )) {
            $this->info('Cancelled. No data was changed.');

            return self::SUCCESS;
        }

        $this->call('migrate:fresh', ['--seed' => true, '--force' => true]);

        $this->clearUploadedFiles();

        $this->newLine();
        $this->info('All data has been reset. Roles, permissions, and the default admin user (admin@example.com / password) were re-seeded.');

        return self::SUCCESS;
    }

    private function clearUploadedFiles(): void
    {
        $disk = Storage::disk('public');

        foreach (['drivers', 'hire-expenses', 'deposit-slips'] as $directory) {
            $disk->deleteDirectory($directory);
        }

        $this->info('Cleared uploaded files (driver documents, expense receipts, deposit slips).');
    }
}
