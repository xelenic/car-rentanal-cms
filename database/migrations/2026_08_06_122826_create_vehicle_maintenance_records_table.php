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
        Schema::create('vehicle_maintenance_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vehicle_id')->constrained()->cascadeOnDelete();
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();
            // 'service' | 'repair' | 'parts' — deliberately NOT a hire expense
            // category: these aren't tied to a specific hire (the vehicle
            // may not even be on an active hire when serviced) and must
            // never factor into the driver's salary calculation.
            $table->string('type');
            $table->unsignedInteger('mileage')->nullable();
            $table->decimal('cost', 10, 2);
            $table->text('description')->nullable();
            $table->string('bill_path');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('vehicle_maintenance_records');
    }
};
