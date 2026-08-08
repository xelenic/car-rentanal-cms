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
        Schema::table('hires', function (Blueprint $table) {
            $table->dateTime('tracking_started_at')->nullable()->after('payment_type');
            $table->dateTime('tracking_stopped_at')->nullable()->after('tracking_started_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('hires', function (Blueprint $table) {
            $table->dropColumn(['tracking_started_at', 'tracking_stopped_at']);
        });
    }
};
