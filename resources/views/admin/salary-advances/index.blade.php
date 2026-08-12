@extends('layouts.admin')

@section('title', 'Salary Advances')
@section('subtitle', 'Review and manage driver salary advance requests.')

@section('content')
    <div class="card border-0">
        <div class="card-header">
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                <div class="position-relative" style="max-width: 280px; flex: 1 1 220px;">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search by driver name...">
                </div>

                <select name="status" class="form-select" style="max-width: 160px;" onchange="this.form.submit()">
                    <option value="all" {{ $status === 'all' ? 'selected' : '' }}>All statuses</option>
                    @foreach (\App\Models\SalaryAdvanceRequest::STATUSES as $value => $label)
                        <option value="{{ $value }}" {{ $status === $value ? 'selected' : '' }}>{{ $label }}</option>
                    @endforeach
                </select>

                @if ($pendingCount > 0)
                    <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis">{{ $pendingCount }} pending review</span>
                @endif
            </form>
        </div>

        <div class="table-responsive">
            <table class="table align-middle">
                <thead>
                    <tr>
                        <th>Driver</th>
                        <th>Amount</th>
                        <th>Reason</th>
                        <th>Requested</th>
                        <th>Status</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($requests as $advance)
                        <tr>
                            <td>
                                <div class="d-flex align-items-center gap-2">
                                    <x-avatar :name="$advance->driver->name" :size="30" />
                                    <div class="fw-semibold" style="font-size: .8rem;">{{ $advance->driver->name }}</div>
                                </div>
                            </td>
                            <td class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($advance->amount, 2) }}</td>
                            <td class="text-muted" style="max-width: 220px;">
                                <span class="d-inline-block text-truncate" style="max-width: 220px; font-size: .78rem;">{{ $advance->reason ?: '—' }}</span>
                            </td>
                            <td class="text-muted" style="font-size: .78rem;">{{ $advance->created_at?->format('M j, Y g:i A') }}</td>
                            <td>
                                @php
                                    $statusColor = match ($advance->status) {
                                        'approved' => 'success',
                                        'rejected' => 'danger',
                                        default => 'warning',
                                    };
                                @endphp
                                <span class="badge rounded-pill bg-{{ $statusColor }}-subtle text-{{ $statusColor }}-emphasis">{{ $advance->status_label }}</span>
                                @if ($advance->status !== 'pending')
                                    <div class="text-muted mt-1" style="font-size: .7rem;">
                                        by {{ $advance->reviewer?->name ?? '—' }} &middot; {{ $advance->reviewed_at?->format('M j, Y') }}
                                    </div>
                                    @if ($advance->admin_note)
                                        <div class="text-muted" style="font-size: .7rem;">&ldquo;{{ $advance->admin_note }}&rdquo;</div>
                                    @endif
                                @endif
                                @if ($advance->status === 'approved' && $advance->deductions->isNotEmpty())
                                    <button type="button" class="btn btn-link btn-sm p-0 d-block" style="font-size: .72rem;" data-bs-toggle="modal" data-bs-target="#modal-schedule-{{ $advance->id }}">
                                        {{ $advance->deduction_type_label }} ({{ $advance->deductions->count() }} mo)
                                    </button>
                                @endif
                            </td>
                            <td class="text-end">
                                @if ($advance->status === 'pending')
                                    @can('salary-advances.update')
                                        <div class="d-inline-flex gap-1">
                                            <button type="button" class="btn btn-sm btn-light border btn-icon text-success" data-bs-toggle="modal" data-bs-target="#modal-approve-{{ $advance->id }}">
                                                <i class="bi bi-check-lg"></i>
                                            </button>
                                            <button type="button" class="btn btn-sm btn-light border btn-icon text-danger" data-bs-toggle="modal" data-bs-target="#modal-reject-{{ $advance->id }}">
                                                <i class="bi bi-x-lg"></i>
                                            </button>
                                        </div>
                                    @endcan
                                @else
                                    <span class="text-muted small">&mdash;</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="text-center text-muted py-4">
                                <i class="bi bi-cash-coin fs-4 d-block mb-1"></i>
                                No salary advance requests found.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if ($requests->hasPages())
            <div class="card-footer bg-white">
                {{ $requests->links() }}
            </div>
        @endif
    </div>

    @can('salary-advances.update')
        @foreach ($requests as $advance)
            @if ($advance->status === 'pending')
                <x-modal id="modal-reject-{{ $advance->id }}" title="Reject Advance Request — {{ $advance->driver->name }}">
                    <form id="form-reject-{{ $advance->id }}" method="POST" action="{{ route('admin.salary-advances.update', $advance) }}">
                        @csrf
                        @method('PUT')
                        <input type="hidden" name="status" value="rejected">
                        <div class="mb-2">
                            <div class="text-muted small">Amount</div>
                            <div class="fw-semibold">Rs. {{ number_format($advance->amount, 2) }}</div>
                        </div>
                        <label for="reject-note-{{ $advance->id }}" class="form-label">Reason for rejection (optional)</label>
                        <textarea id="reject-note-{{ $advance->id }}" name="admin_note" class="form-control" rows="3" placeholder="Let the driver know why this was rejected..."></textarea>
                    </form>
                    <x-slot:footer>
                        <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" form="form-reject-{{ $advance->id }}" class="btn btn-danger">Reject Request</button>
                    </x-slot:footer>
                </x-modal>

                <x-modal id="modal-approve-{{ $advance->id }}" title="Approve Advance Request — {{ $advance->driver->name }}">
                    <form id="form-approve-{{ $advance->id }}" class="advance-approve-form" method="POST" action="{{ route('admin.salary-advances.update', $advance) }}" data-amount="{{ (float) $advance->amount }}">
                        @csrf
                        @method('PUT')
                        <input type="hidden" name="status" value="approved">

                        <div class="mb-3">
                            <div class="text-muted small">Requested amount</div>
                            <div class="fw-semibold fs-5">Rs. {{ number_format($advance->amount, 2) }}</div>
                        </div>

                        <label class="form-label">How should this be deducted?</label>

                        <div class="form-check mb-2">
                            <input class="form-check-input deduction-type-radio" type="radio" name="deduction_type" id="deduction-full-{{ $advance->id }}" value="full" checked>
                            <label class="form-check-label" for="deduction-full-{{ $advance->id }}">
                                Deduct fully from this month's salary
                            </label>
                        </div>

                        <div class="form-check mb-3">
                            <input class="form-check-input deduction-type-radio" type="radio" name="deduction_type" id="deduction-installments-{{ $advance->id }}" value="installments">
                            <label class="form-check-label" for="deduction-installments-{{ $advance->id }}">
                                Partially deduct — split across upcoming months (including this month)
                            </label>
                        </div>

                        <div class="installment-fields d-none border rounded p-3 mb-3" style="background: #f8f9fb;">
                            <div class="row g-2">
                                <div class="col-6">
                                    <label for="this-month-amount-{{ $advance->id }}" class="form-label small">This month's deduction</label>
                                    <input type="number" step="0.01" min="0" max="{{ (float) $advance->amount }}" name="this_month_amount" id="this-month-amount-{{ $advance->id }}" class="form-control this-month-amount-input" placeholder="0.00">
                                </div>
                                <div class="col-6">
                                    <label for="installment-months-{{ $advance->id }}" class="form-label small">Split remaining over (months)</label>
                                    <input type="number" step="1" min="1" max="60" name="installment_months" id="installment-months-{{ $advance->id }}" class="form-control installment-months-input" placeholder="e.g. 3">
                                </div>
                            </div>
                            <div class="installment-preview text-muted mt-2" style="font-size: .78rem;"></div>
                        </div>

                        <label for="approve-note-{{ $advance->id }}" class="form-label">Note (optional)</label>
                        <textarea id="approve-note-{{ $advance->id }}" name="admin_note" class="form-control" rows="2" placeholder="Optional note for the driver..."></textarea>
                    </form>
                    <x-slot:footer>
                        <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" form="form-approve-{{ $advance->id }}" class="btn btn-success">Approve Request</button>
                    </x-slot:footer>
                </x-modal>
            @endif
        @endforeach
    @endcan

    @foreach ($requests as $advance)
        @if ($advance->status === 'approved' && $advance->deductions->isNotEmpty())
            <x-modal id="modal-schedule-{{ $advance->id }}" title="Deduction Schedule — {{ $advance->driver->name }}">
                <div class="mb-2">
                    <div class="text-muted small">{{ $advance->deduction_type_label }}</div>
                    <div class="fw-semibold">Rs. {{ number_format($advance->amount, 2) }} total</div>
                </div>
                <table class="table table-sm mb-0">
                    <thead>
                        <tr>
                            <th>Month</th>
                            <th class="text-end">Amount</th>
                            <th>Salary Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        @php $now = now(); @endphp
                        @foreach ($advance->deductions as $deduction)
                            @php
                                $isPaid = $paidPeriods->contains("{$advance->driver_id}-{$deduction->year}-{$deduction->month}");
                                $isPastOrCurrent = $deduction->year < (int) $now->format('Y')
                                    || ($deduction->year === (int) $now->format('Y') && $deduction->month <= (int) $now->format('n'));
                            @endphp
                            <tr>
                                <td>{{ \Carbon\Carbon::createFromDate($deduction->year, $deduction->month, 1)->format('F Y') }}</td>
                                <td class="text-end">Rs. {{ number_format($deduction->amount, 2) }}</td>
                                <td>
                                    @if ($isPaid)
                                        <span class="badge rounded-pill bg-success-subtle text-success-emphasis">Paid</span>
                                    @elseif ($isPastOrCurrent)
                                        <span class="badge rounded-pill bg-warning-subtle text-warning-emphasis">Pending</span>
                                    @else
                                        <span class="badge rounded-pill bg-secondary-subtle text-secondary-emphasis">Upcoming</span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Close</button>
                </x-slot:footer>
            </x-modal>
        @endif
    @endforeach

    @push('scripts')
        <script>
            (function () {
                function toggleInstallmentFields(form) {
                    var installmentsSelected = form.querySelector('.deduction-type-radio[value="installments"]').checked;
                    var fields = form.querySelector('.installment-fields');
                    fields.classList.toggle('d-none', !installmentsSelected);
                }

                function updatePreview(form) {
                    var totalAmount = parseFloat(form.dataset.amount || '0');
                    var thisMonthInput = form.querySelector('.this-month-amount-input');
                    var monthsInput = form.querySelector('.installment-months-input');
                    var preview = form.querySelector('.installment-preview');
                    if (!thisMonthInput || !monthsInput || !preview) return;

                    var thisMonth = Math.min(Math.max(parseFloat(thisMonthInput.value) || 0, 0), totalAmount);
                    var months = Math.max(parseInt(monthsInput.value, 10) || 0, 0);
                    var remaining = Math.round((totalAmount - thisMonth) * 100) / 100;

                    if (remaining <= 0) {
                        preview.textContent = thisMonth > 0
                            ? 'This month\'s deduction covers the full amount — no upcoming months needed.'
                            : '';
                        return;
                    }

                    if (months <= 0) {
                        preview.textContent = 'Remaining balance: Rs. ' + remaining.toFixed(2) + '. Enter how many months to split it over.';
                        return;
                    }

                    var perMonth = Math.floor((remaining / months) * 100) / 100;
                    var last = Math.round((remaining - perMonth * (months - 1)) * 100) / 100;

                    var text = 'Remaining balance: Rs. ' + remaining.toFixed(2) + ' → ';
                    if (months === 1) {
                        text += 'Rs. ' + last.toFixed(2) + ' next month.';
                    } else if (perMonth === last) {
                        text += 'Rs. ' + perMonth.toFixed(2) + '/month for ' + months + ' upcoming months.';
                    } else {
                        text += 'Rs. ' + perMonth.toFixed(2) + '/month for ' + (months - 1) + ' months, then Rs. ' + last.toFixed(2) + ' in the final month.';
                    }
                    preview.textContent = text;
                }

                document.addEventListener('change', function (event) {
                    var form = event.target.closest('.advance-approve-form');
                    if (!form) return;
                    if (event.target.classList.contains('deduction-type-radio')) {
                        toggleInstallmentFields(form);
                        updatePreview(form);
                    }
                });

                document.addEventListener('input', function (event) {
                    var form = event.target.closest('.advance-approve-form');
                    if (!form) return;
                    if (event.target.classList.contains('this-month-amount-input') || event.target.classList.contains('installment-months-input')) {
                        updatePreview(form);
                    }
                });
            })();
        </script>
    @endpush
@endsection
