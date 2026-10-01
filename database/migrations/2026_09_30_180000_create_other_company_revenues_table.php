<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Revenue from bookings made through other rental companies — a manual
     * ledger (no link to our own Hire records, since these trips aren't
     * booked through this system). Lives on the My Expenses & Income page as
     * its own tab; the credited amount adds to My Profit the same way Other
     * Income does.
     */
    public function up(): void
    {
        Schema::create('other_company_revenues', function (Blueprint $table) {
            $table->id();
            $table->string('hire');
            $table->string('booking_number');
            $table->string('vehicle');
            $table->decimal('full_amount', 12, 2);
            $table->decimal('credited_amount', 12, 2);
            $table->decimal('balance', 12, 2);
            $table->decimal('vehicle_amount', 12, 2);
            $table->date('revenue_date')->index();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('other_company_revenues');
    }
};
