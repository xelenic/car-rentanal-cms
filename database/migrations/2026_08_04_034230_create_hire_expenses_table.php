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
        Schema::create('hire_expenses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('hire_id')->constrained()->cascadeOnDelete();
            $table->string('category')->default('fuel');
            $table->decimal('amount', 10, 2);
            $table->string('receipt_path')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('hire_expenses');
    }
};
