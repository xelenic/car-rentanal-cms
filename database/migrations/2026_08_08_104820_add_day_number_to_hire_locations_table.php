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
        Schema::table('hire_locations', function (Blueprint $table) {
            // Which day of a multi-day tour this "stay" location belongs
            // to — a day can now hold more than one location. Null for
            // 'from'/'to' rows (drop & pickup, day tours), which aren't
            // day-grouped.
            $table->unsignedInteger('day_number')->nullable()->after('role');
        });

        // Backfill: every existing 'stay' row was, until now, exactly one
        // location per day — so each one becomes its own day, in the same
        // order they were already stored in.
        Hire::query()->where('tour_type', 'multi_day')->pluck('id')->each(function (int $hireId) {
            $stayLocations = DB::table('hire_locations')
                ->where('hire_id', $hireId)
                ->where('role', 'stay')
                ->orderBy('order')
                ->get(['id']);

            foreach ($stayLocations as $index => $row) {
                DB::table('hire_locations')->where('id', $row->id)->update(['day_number' => $index + 1]);
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('hire_locations', function (Blueprint $table) {
            $table->dropColumn('day_number');
        });
    }
};
