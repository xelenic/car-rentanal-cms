<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['arrears_loan_id', 'driver_id', 'year', 'month', 'amount'])]
class DriverArrearsLoanDeduction extends Model
{
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
        ];
    }

    public function arrearsLoan(): BelongsTo
    {
        return $this->belongsTo(DriverArrearsLoan::class, 'arrears_loan_id');
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }
}
