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
        Schema::create('driver_payrolls', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained()->cascadeOnDelete();
            $table->unsignedSmallInteger('year');
            $table->unsignedTinyInteger('month');

            $table->unsignedInteger('hire_count')->default(0);
            $table->decimal('our_hire_value_total', 12, 2)->default(0);
            $table->decimal('expenses_total', 12, 2)->default(0);
            $table->decimal('salary', 12, 2)->default(0);
            $table->decimal('advance_deduction_total', 12, 2)->default(0);
            $table->decimal('net_before_adjustment', 12, 2)->default(0);
            $table->decimal('manual_adjustment', 12, 2)->default(0);
            $table->string('adjustment_note')->nullable();
            $table->decimal('final_amount', 12, 2)->default(0);

            $table->string('status')->default('finalized');
            $table->foreignId('finalized_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('finalized_at')->nullable();
            $table->foreignId('paid_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('paid_at')->nullable();

            $table->timestamps();

            $table->unique(['driver_id', 'year', 'month']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('driver_payrolls');
    }
};
