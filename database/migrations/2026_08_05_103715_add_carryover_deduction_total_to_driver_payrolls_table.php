<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('driver_payrolls', function (Blueprint $table) {
            $table->decimal('carryover_deduction_total', 12, 2)->default(0)->after('advance_deduction_total');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('driver_payrolls', function (Blueprint $table) {
            $table->dropColumn('carryover_deduction_total');
        });
    }
};
