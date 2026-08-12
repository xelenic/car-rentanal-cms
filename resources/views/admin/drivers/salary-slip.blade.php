<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Salary Slip — {{ $driver->name }} — {{ $periodLabel }}</title>
    <style>
        @page { margin: 28px 34px; }
        body { font-family: 'Helvetica', Arial, sans-serif; color: #1f2430; font-size: 12px; }
        .header { width: 100%; border-bottom: 2px solid #0f172a; padding-bottom: 10px; margin-bottom: 16px; }
        .header td { vertical-align: top; }
        .company { font-size: 18px; font-weight: bold; color: #0f172a; }
        .subtitle { font-size: 11px; color: #64748b; margin-top: 2px; }
        .slip-title { font-size: 13px; font-weight: bold; text-align: right; color: #0f172a; }
        .status-badge {
            display: inline-block; margin-top: 4px; padding: 2px 10px; border-radius: 10px;
            font-size: 10px; font-weight: bold; text-transform: uppercase;
        }
        .status-paid { background: #dcfce7; color: #15803d; }
        .status-finalized { background: #fef3c7; color: #b45309; }

        .info-table { width: 100%; margin-bottom: 16px; }
        .info-table td { padding: 3px 0; font-size: 11.5px; }
        .info-label { color: #64748b; width: 110px; }
        .info-value { font-weight: bold; color: #0f172a; }

        .section-title {
            font-size: 11px; font-weight: bold; text-transform: uppercase; letter-spacing: .04em;
            color: #0f172a; background: #f1f5f9; padding: 5px 8px; margin-top: 14px; margin-bottom: 0;
        }
        table.rows { width: 100%; border-collapse: collapse; }
        table.rows td { padding: 6px 8px; font-size: 11.5px; border-bottom: 1px solid #e5e7eb; }
        table.rows td.amount { text-align: right; }
        .muted { color: #64748b; }
        .negative { color: #b91c1c; }
        .positive { color: #15803d; }

        .total-row td { border-top: 2px solid #0f172a; border-bottom: none; padding-top: 10px; font-size: 14px; font-weight: bold; }
        .total-row .amount.negative { color: #b91c1c; }
        .total-row .amount.positive { color: #15803d; }

        .note { font-size: 10.5px; color: #64748b; padding: 6px 8px; }

        .footer { margin-top: 26px; font-size: 10.5px; color: #64748b; }
        .footer table { width: 100%; }
        .footer td { padding: 2px 0; }
        .generated { margin-top: 20px; font-size: 9.5px; color: #94a3b8; text-align: center; }
    </style>
</head>
<body>
    <table class="header">
        <tr>
            <td>
                <div class="company">Car Rental CMS</div>
                <div class="subtitle">Driver Salary Slip</div>
            </td>
            <td style="text-align: right;">
                <div class="slip-title">{{ $periodLabel }}</div>
                <div style="text-align: right;">
                    <span class="status-badge {{ $payroll->status === 'paid' ? 'status-paid' : 'status-finalized' }}">
                        {{ $payroll->status_label }}
                    </span>
                </div>
            </td>
        </tr>
    </table>

    <table class="info-table">
        <tr>
            <td class="info-label">Driver</td>
            <td class="info-value">{{ $driver->name }}</td>
            <td class="info-label">License</td>
            <td class="info-value">{{ $driver->license }}</td>
        </tr>
        <tr>
            <td class="info-label">Email</td>
            <td class="info-value">{{ $driver->email }}</td>
            <td class="info-label">Contact</td>
            <td class="info-value">{{ $driver->contact_number }}</td>
        </tr>
        <tr>
            <td class="info-label">Hires this month</td>
            <td class="info-value">{{ $payroll->hire_count }}</td>
            <td class="info-label">Our Hire Value</td>
            <td class="info-value">Rs. {{ number_format($payroll->our_hire_value_total, 2) }}</td>
        </tr>
    </table>

    <div class="section-title">Earnings</div>
    <table class="rows">
        <tr>
            <td>Total Expenses (Fuel, Highway, Foods, Room, Parking)</td>
            <td class="amount negative">-Rs. {{ number_format($payroll->expenses_total, 2) }}</td>
        </tr>
        <tr>
            <td>20% Driver Salary</td>
            <td class="amount">Rs. {{ number_format($payroll->salary, 2) }}</td>
        </tr>
    </table>

    <div class="section-title">Deductions</div>
    <table class="rows">
        <tr>
            <td>Salary Advance Deduction</td>
            <td class="amount negative">-Rs. {{ number_format($payroll->advance_deduction_total, 2) }}</td>
        </tr>
        @if ((float) $payroll->carryover_deduction_total > 0)
            <tr>
                <td>Carried Over from Previous Month</td>
                <td class="amount negative">-Rs. {{ number_format($payroll->carryover_deduction_total, 2) }}</td>
            </tr>
        @endif
        @if ((float) $payroll->arrears_deduction_total > 0)
            <tr>
                <td>Arrears Loan Deduction</td>
                <td class="amount negative">-Rs. {{ number_format($payroll->arrears_deduction_total, 2) }}</td>
            </tr>
        @endif
        @if ((float) $payroll->deposit_balance > 0)
            <tr>
                <td>Deposit Balance</td>
                <td class="amount negative">-Rs. {{ number_format($payroll->deposit_balance, 2) }}</td>
            </tr>
        @endif
        @if ((float) $payroll->arrears_loan_offset > 0)
            <tr>
                <td>Converted to Arrears Loan (Full Amount)</td>
                <td class="amount positive">+Rs. {{ number_format($payroll->arrears_loan_offset, 2) }}</td>
            </tr>
        @endif
        @if ((float) $payroll->manual_adjustment !== 0.0)
            <tr>
                <td>
                    Manual Adjustment
                    @if ($payroll->adjustment_note)
                        <span class="muted">&mdash; {{ $payroll->adjustment_note }}</span>
                    @endif
                </td>
                <td class="amount {{ (float) $payroll->manual_adjustment < 0 ? 'negative' : 'positive' }}">
                    {{ (float) $payroll->manual_adjustment < 0 ? '-' : '+' }}Rs. {{ number_format(abs($payroll->manual_adjustment), 2) }}
                </td>
            </tr>
        @endif
        <tr class="total-row">
            <td>Final Amount</td>
            <td class="amount {{ (float) $payroll->final_amount < 0 ? 'negative' : 'positive' }}">
                {{ (float) $payroll->final_amount < 0 ? '-' : '' }}Rs. {{ number_format(abs($payroll->final_amount), 2) }}
            </td>
        </tr>
    </table>

    <div class="footer">
        <table>
            <tr>
                <td>Finalized by {{ $payroll->finalizedBy?->name ?? '—' }}</td>
                <td style="text-align: right;">{{ $payroll->finalized_at?->format('M j, Y g:i A') ?? '—' }}</td>
            </tr>
            @if ($payroll->status === 'paid')
                <tr>
                    <td>Paid by {{ $payroll->paidBy?->name ?? '—' }}</td>
                    <td style="text-align: right;">{{ $payroll->paid_at?->format('M j, Y g:i A') ?? '—' }}</td>
                </tr>
            @endif
        </table>
    </div>

    <div class="generated">This is a system-generated salary slip &middot; Printed on {{ now()->format('M j, Y g:i A') }}</div>
</body>
</html>
