<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Money the owner receives that isn't a hire — rent from a property,
     * interest, selling an old vehicle… Kept apart from hires (whose earnings
     * come from the hires themselves) and from my_expenses; My Profit adds
     * these to the month's profit from hires and takes the expenses off.
     */
    public function up(): void
    {
        Schema::create('other_incomes', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->decimal('amount', 12, 2);
            $table->date('income_date')->index();
            $table->text('notes')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('other_incomes');
    }
};
