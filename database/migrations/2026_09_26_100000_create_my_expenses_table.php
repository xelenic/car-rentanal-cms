<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The owner's own running costs (rent, utilities, marketing…) — deliberately
     * separate from hire_expenses, which are what drivers spend on the road and
     * already feed the driver salary calculation.
     */
    public function up(): void
    {
        Schema::create('my_expenses', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->string('category')->default('others');
            $table->decimal('amount', 12, 2);
            $table->date('expense_date')->index();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('my_expenses');
    }
};
