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
        Schema::create('vehicle_leasings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vehicle_id')->constrained()->cascadeOnDelete();
            // 'leasing' (finance company holds ownership until fully paid)
            // or 'loan' (vehicle owned outright, borrowed against it).
            $table->string('type')->default('leasing');
            $table->string('company');
            $table->string('agreement_number')->nullable();
            $table->decimal('loan_amount', 12, 2);
            $table->decimal('monthly_installment', 12, 2);
            $table->decimal('interest_rate', 5, 2)->nullable();
            $table->decimal('balance_remaining', 12, 2);
            $table->date('start_date');
            $table->unsignedInteger('term_months')->nullable();
            $table->date('end_date')->nullable();
            $table->string('status')->default('active');
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('vehicle_leasings');
    }
};
