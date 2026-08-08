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
        Schema::table('hires', function (Blueprint $table) {
            $table->dropColumn(['owner_name', 'owner_contact_number']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('hires', function (Blueprint $table) {
            $table->string('owner_name')->nullable()->after('our_hire_value');
            $table->string('owner_contact_number')->nullable()->after('owner_name');
        });
    }
};
