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
        Schema::table('vehicles', function (Blueprint $table) {
            // A hex color (e.g. "#2a78d6") for this vehicle's card accent on
            // the Dashboard — left null, Vehicle::displayColor falls back to
            // one of a fixed palette, cycled by id, so every vehicle still
            // reads as a distinct color before anyone picks one by hand.
            $table->string('color', 7)->nullable()->after('condition');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('vehicles', function (Blueprint $table) {
            $table->dropColumn('color');
        });
    }
};
