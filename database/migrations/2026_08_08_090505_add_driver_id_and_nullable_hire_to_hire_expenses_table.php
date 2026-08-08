<?php

use App\Models\Hire;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('hire_expenses', function (Blueprint $table) {
            // Expenses logged from the driver app's Options page (Fuel,
            // Foods, Room, Parking, Highway) aren't tied to a specific hire,
            // so they need their own driver attribution and hire_id must
            // become optional.
            $table->foreignId('driver_id')->nullable()->after('hire_id')->constrained()->cascadeOnDelete();
        });

        Schema::table('hire_expenses', function (Blueprint $table) {
            $table->foreignId('hire_id')->nullable()->change();
        });

        // Backfill driver_id for existing hire-tied rows so every row is
        // attributable to a driver without needing a join. Done in PHP
        // (rather than a joined UPDATE) since SQLite can't reference a
        // joined table's column in an UPDATE's SET clause.
        Hire::query()->pluck('driver_id', 'id')->each(function (int $driverId, int $hireId) {
            DB::table('hire_expenses')
                ->where('hire_id', $hireId)
                ->update(['driver_id' => $driverId]);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('hire_expenses', function (Blueprint $table) {
            $table->dropConstrainedForeignId('driver_id');
        });

        Schema::table('hire_expenses', function (Blueprint $table) {
            $table->foreignId('hire_id')->nullable(false)->change();
        });
    }
};
