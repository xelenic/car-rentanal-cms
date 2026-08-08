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
            $table->decimal('deposit_balance', 12, 2)->default(0)->after('arrears_deduction_total');
            $table->decimal('arrears_loan_offset', 12, 2)->default(0)->after('deposit_balance');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('driver_payrolls', function (Blueprint $table) {
            $table->dropColumn(['deposit_balance', 'arrears_loan_offset']);
        });
    }
};
