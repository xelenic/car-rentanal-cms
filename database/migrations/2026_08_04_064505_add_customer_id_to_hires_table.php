<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('hires', function (Blueprint $table) {
            $table->foreignId('customer_id')->nullable()->after('our_hire_value')
                ->constrained('customers')->nullOnDelete();
        });

        // Backfill: turn each hire's free-text owner name/contact into a real
        // Customer record (reusing one already created for a matching name+phone).
        $hires = DB::table('hires')->whereNotNull('owner_name')->get();

        foreach ($hires as $hire) {
            $name = trim((string) $hire->owner_name) ?: 'Unknown Customer';
            $phone = trim((string) $hire->owner_contact_number) ?: '—';

            $customer = DB::table('customers')
                ->where('name', $name)
                ->where('phone', $phone)
                ->first();

            $customerId = $customer?->id ?? DB::table('customers')->insertGetId([
                'name' => $name,
                'phone' => $phone,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('hires')->where('id', $hire->id)->update(['customer_id' => $customerId]);
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('hires', function (Blueprint $table) {
            $table->dropConstrainedForeignId('customer_id');
        });
    }
};
