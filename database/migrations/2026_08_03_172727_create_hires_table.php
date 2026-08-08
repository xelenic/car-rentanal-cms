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
        Schema::create('hires', function (Blueprint $table) {
            $table->id();
            $table->string('tour_type');
            $table->foreignId('package_id')->nullable()->constrained()->restrictOnDelete();
            $table->dateTime('start_time')->nullable();
            $table->dateTime('end_time')->nullable();
            $table->decimal('hire_full_value', 10, 2);
            $table->decimal('our_hire_value', 10, 2);
            $table->string('owner_name')->nullable();
            $table->string('owner_contact_number')->nullable();
            $table->foreignId('driver_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('vehicle_id')->nullable()->constrained()->nullOnDelete();
            $table->text('description')->nullable();
            $table->string('payment_type');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('hires');
    }
};
