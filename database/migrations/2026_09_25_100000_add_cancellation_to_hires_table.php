<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A driver can cancel a hire (status "cancelled"): when, and why if they
     * said. The status itself is the existing free-text `status` column.
     */
    public function up(): void
    {
        Schema::table('hires', function (Blueprint $table) {
            $table->dateTime('cancelled_at')->nullable()->after('tracking_stopped_at');
            $table->text('cancel_reason')->nullable()->after('cancelled_at');
        });
    }

    public function down(): void
    {
        Schema::table('hires', function (Blueprint $table) {
            $table->dropColumn(['cancelled_at', 'cancel_reason']);
        });
    }
};
