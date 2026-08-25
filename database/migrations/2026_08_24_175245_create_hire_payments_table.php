<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * One row per "Claim Payment" action against a credit hire — either a
     * single full-value row (Mark Full Payment) or several partial rows
     * over time. A hire's paid/remaining amounts are always computed by
     * summing these (see Hire::getPaidAmountAttribute()), never stored
     * directly, so there's nothing to keep in sync.
     */
    public function up(): void
    {
        Schema::create('hire_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('hire_id')->constrained()->cascadeOnDelete();
            $table->decimal('amount', 10, 2);
            $table->date('paid_at');
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('hire_payments');
    }
};
