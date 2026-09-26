<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    /** The categories My Expenses started with — now just the first rows of an editable list. */
    private const DEFAULTS = [
        'rent' => 'Rent',
        'utilities' => 'Utilities',
        'office' => 'Office & Supplies',
        'marketing' => 'Marketing',
        'insurance' => 'Insurance',
        'taxes' => 'Taxes & Licences',
        'fuel' => 'Fuel',
        'personal' => 'Personal',
        'others' => 'Others',
    ];

    /**
     * An expense keeps pointing at its category by `key`, a stable slug that never
     * changes (renaming a category only changes `name`) — so existing expenses
     * need no rewriting, and any key already in use that isn't one of the
     * defaults gets a category of its own rather than being orphaned.
     */
    public function up(): void
    {
        Schema::create('my_expense_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('key')->unique();
            $table->timestamps();
        });

        $now = now();
        $known = self::DEFAULTS;

        if (Schema::hasTable('my_expenses')) {
            foreach (DB::table('my_expenses')->distinct()->pluck('category') as $key) {
                $known[$key] ??= Str::headline($key);
            }
        }

        foreach ($known as $key => $name) {
            DB::table('my_expense_categories')->insert([
                'key' => $key, 'name' => $name, 'created_at' => $now, 'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('my_expense_categories');
    }
};
