@extends('layouts.admin')

@section('title', 'My Expenses')
@section('subtitle', 'Your own running costs — and what is left of the month\'s profit once they are paid.')

@section('actions')
    <div class="d-flex flex-wrap gap-2 justify-content-end">
        @canany(['my-expenses.create', 'my-expenses.update', 'my-expenses.delete'])
            <button type="button" class="btn btn-light border" data-bs-toggle="modal" data-bs-target="#modal-categories" id="manage-categories">
                <i class="bi bi-tags me-1"></i> Categories
            </button>
        @endcanany
        @can('my-expenses.create')
            <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#modal-create">
                <i class="bi bi-plus-lg me-1"></i> Add Expense
            </button>
        @endcan
    </div>
@endsection

@php
    $money = fn (float $value) => ($value < 0 ? '-' : '').'Rs. '.number_format(abs($value), 2);
    $isFiltered = $selectedCategory || $search;
    $isCurrentPeriod = $selectedYear === (int) now()->format('Y') && $selectedMonth === (int) now()->format('n');
@endphp

@section('content')
    <div class="row row-cols-1 row-cols-md-3 g-2 mb-2" id="my-expenses-cards">
        <div class="col">
            <div class="card border-0 h-100" id="card-total-expenses">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdeee7; color: #c95a26;">
                        <i class="bi bi-wallet2"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Total My Expenses &middot; {{ $periodLabel }}</div>
                        <div class="fs-5 fw-bold">{{ $money($total) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">{{ number_format($recordCount) }} record{{ $recordCount === 1 ? '' : 's' }}</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0 h-100" id="card-profit-before">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #eaf2fc; color: #2a78d6;">
                        <i class="bi bi-graph-up"></i>
                    </div>
                    <div>
                        <div class="text-muted small">Profit Before My Expenses</div>
                        <div class="fs-5 fw-bold {{ $profitBeforeExpenses < 0 ? 'text-danger' : '' }}">{{ $money($profitBeforeExpenses) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">Same as the dashboard's Total Profit</div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-0 h-100 profit-card-clickable" id="card-my-profit" role="button" tabindex="0"
                data-bs-toggle="modal" data-bs-target="#modal-my-profit-breakdown">
                <div class="card-body d-flex align-items-center gap-2">
                    <div class="stat-icon" style="background: #fdf4ff; color: #a21caf;">
                        <i class="bi bi-piggy-bank"></i>
                    </div>
                    <div>
                        <div class="text-muted small">My Profit &middot; {{ $periodLabel }}
                            <i class="bi bi-info-circle ms-1" title="Click for the full calculation"></i>
                        </div>
                        <div class="fs-5 fw-bold {{ $myProfit < 0 ? 'text-danger' : 'text-success' }}">{{ $money($myProfit) }}</div>
                        <div class="text-muted" style="font-size: .7rem;">After all costs and my expenses</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    @push('styles')
        <style>
            .profit-card-clickable { cursor: pointer; transition: box-shadow .15s ease, transform .15s ease; }
            .profit-card-clickable:hover { box-shadow: 0 4px 14px rgba(0,0,0,.08); transform: translateY(-1px); }
        </style>
    @endpush

    <div class="card border-0 mb-2">
        <div class="card-header">
            <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                <div class="position-relative" style="max-width: 240px; flex: 1 1 190px;">
                    <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                    <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search expense or notes...">
                </div>

                <select name="category" class="form-select" style="max-width: 170px;" onchange="this.form.submit()">
                    <option value="">All Categories</option>
                    @foreach ($categories as $key => $label)
                        <option value="{{ $key }}" {{ $selectedCategory === $key ? 'selected' : '' }}>{{ $label }}</option>
                    @endforeach
                </select>

                <select name="year" class="form-select" style="max-width: 110px;" onchange="this.form.submit()">
                    @foreach ($availableYears as $year)
                        <option value="{{ $year }}" {{ $selectedYear === $year ? 'selected' : '' }}>{{ $year }}</option>
                    @endforeach
                </select>

                <select name="month" class="form-select" style="max-width: 140px;" onchange="this.form.submit()">
                    @foreach (range(1, 12) as $month)
                        <option value="{{ $month }}" {{ $selectedMonth === $month ? 'selected' : '' }}>{{ \Carbon\Carbon::create()->month($month)->format('F') }}</option>
                    @endforeach
                </select>

                @if ($isFiltered || ! $isCurrentPeriod)
                    <a href="{{ route('admin.my-expenses.index') }}" class="btn btn-light border">{{ $isFiltered ? 'Clear' : 'This month' }}</a>
                @endif
            </form>
        </div>
    </div>

    @if ($byCategory->isNotEmpty())
        <div class="row row-cols-2 row-cols-md-3 row-cols-xl-5 g-2 mb-2" id="my-expenses-by-category">
            @foreach ($byCategory as $category => $amount)
                <div class="col">
                    <div class="card border-0">
                        <div class="card-body py-2 px-3">
                            <div class="text-muted" style="font-size: .68rem;">{{ $categories[$category] ?? ucfirst($category) }}</div>
                            <div class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($amount, 2) }}</div>
                        </div>
                    </div>
                </div>
            @endforeach
        </div>
    @endif

    <div class="card border-0">
        <div class="table-responsive">
            <table class="table align-middle mb-0" id="my-expenses-table">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Expense</th>
                        <th>Category</th>
                        <th class="text-end">Amount</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($expenses as $expense)
                        <tr>
                            <td class="text-muted text-nowrap">{{ $expense->expense_date->format('M j, Y') }}</td>
                            <td>
                                <div class="fw-semibold" style="font-size: .8rem;">{{ $expense->title }}</div>
                                @if ($expense->notes)
                                    <div class="text-muted text-truncate" style="font-size: .72rem; max-width: 320px;" title="{{ $expense->notes }}">{{ $expense->notes }}</div>
                                @endif
                            </td>
                            <td><span class="badge text-bg-light border">{{ $expense->category_label }}</span></td>
                            <td class="text-end fw-semibold text-nowrap">Rs. {{ number_format($expense->amount, 2) }}</td>
                            <td class="text-end">
                                <div class="d-inline-flex gap-1">
                                    @can('my-expenses.update')
                                        <button type="button" class="btn btn-sm btn-light border btn-icon" data-bs-toggle="modal" data-bs-target="#modal-edit-{{ $expense->id }}">
                                            <i class="bi bi-pencil"></i>
                                        </button>
                                    @endcan
                                    @can('my-expenses.delete')
                                        <form method="POST" action="{{ route('admin.my-expenses.destroy', $expense) }}" onsubmit="return confirm('Delete this expense?');">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit" class="btn btn-sm btn-light border btn-icon text-danger">
                                                <i class="bi bi-trash"></i>
                                            </button>
                                        </form>
                                    @endcan
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="text-center text-muted py-4">
                                <i class="bi bi-wallet2 fs-4 d-block mb-1"></i>
                                {{ $isFiltered ? 'No expenses match your search.' : 'No expenses recorded for '.$periodLabel.'.' }}
                            </td>
                        </tr>
                    @endforelse
                </tbody>
                @if ($isFiltered && $expenses->total() > 0)
                    <tfoot>
                        <tr>
                            <td colspan="3" class="text-muted text-end">Total of the {{ number_format($expenses->total()) }} shown</td>
                            <td class="text-end fw-bold text-nowrap" id="filtered-total">Rs. {{ number_format($filteredTotal, 2) }}</td>
                            <td></td>
                        </tr>
                    </tfoot>
                @endif
            </table>
        </div>

        @if ($expenses->hasPages())
            <div class="card-footer bg-white">
                {{ $expenses->links() }}
            </div>
        @endif
    </div>

    @can('my-expenses.create')
        <x-modal id="modal-create" title="Add Expense">
            <form id="form-create-expense" method="POST" action="{{ route('admin.my-expenses.store') }}">
                @csrf
                @include('admin.my-expenses._form', ['expense' => null, 'idPrefix' => 'create'])
            </form>
            <x-slot:footer>
                <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="form-create-expense" class="btn btn-primary">Add Expense</button>
            </x-slot:footer>
        </x-modal>
    @endcan

    @can('my-expenses.update')
        @foreach ($expenses as $expense)
            <x-modal id="modal-edit-{{ $expense->id }}" title="Edit Expense">
                <form id="form-edit-expense-{{ $expense->id }}" method="POST" action="{{ route('admin.my-expenses.update', $expense) }}">
                    @csrf
                    @method('PUT')
                    @include('admin.my-expenses._form', ['expense' => $expense, 'idPrefix' => 'edit-'.$expense->id])
                </form>
                <x-slot:footer>
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" form="form-edit-expense-{{ $expense->id }}" class="btn btn-primary">Update Expense</button>
                </x-slot:footer>
            </x-modal>
        @endforeach
    @endcan

    @canany(['my-expenses.create', 'my-expenses.update', 'my-expenses.delete'])
        <x-modal id="modal-categories" title="Expense Categories">
            @php $categoryFormFailed = old('form_id') === 'categories' && $errors->has('name'); @endphp

            @if ($categoryFormFailed)
                <div class="alert alert-danger py-2" id="category-error">{{ $errors->first('name') }}</div>
            @endif

            {{-- What just happened to a category, shown here since the page behind the manager can't be seen. --}}
            @if (session('reopen_modal') === 'categories')
                @if (session('status'))
                    <div class="alert alert-success py-2" id="category-status">{{ session('status') }}</div>
                @endif
                @if (session('error'))
                    <div class="alert alert-danger py-2" id="category-status">{{ session('error') }}</div>
                @endif
            @endif

            @can('my-expenses.create')
                <form method="POST" action="{{ route('admin.my-expense-categories.store') }}" class="d-flex gap-2 mb-3" id="form-add-category">
                    @csrf
                    <input type="hidden" name="form_id" value="categories">
                    <input type="text" name="name" class="form-control" placeholder="New category, e.g. Bank charges"
                        maxlength="{{ \App\Models\MyExpenseCategory::NAME_MAX }}" required>
                    <button type="submit" class="btn btn-primary text-nowrap"><i class="bi bi-plus-lg me-1"></i> Add</button>
                </form>
            @endcan

            <div class="list-group" id="category-list">
                @foreach ($categoryList as $category)
                    <div class="list-group-item d-flex align-items-center gap-2" data-category-key="{{ $category->key }}">
                        @can('my-expenses.update')
                            <form method="POST" action="{{ route('admin.my-expense-categories.update', $category) }}" class="d-flex gap-2 flex-grow-1">
                                @csrf
                                @method('PUT')
                                <input type="hidden" name="form_id" value="categories">
                                <input type="text" name="name" value="{{ $category->name }}" class="form-control form-control-sm"
                                    maxlength="{{ \App\Models\MyExpenseCategory::NAME_MAX }}" required aria-label="Category name">
                                <button type="submit" class="btn btn-sm btn-light border btn-icon" title="Save name"><i class="bi bi-check-lg"></i></button>
                            </form>
                        @else
                            <span class="flex-grow-1">{{ $category->name }}</span>
                        @endcan

                        <span class="badge text-bg-light border text-nowrap" title="Expenses filed under this category, all months">
                            {{ $category->expenses_count }} {{ \Illuminate\Support\Str::plural('expense', $category->expenses_count) }}
                        </span>

                        @can('my-expenses.delete')
                            @if ($category->expenses_count > 0)
                                <button type="button" class="btn btn-sm btn-light border btn-icon" disabled
                                    title="In use — move or delete its expenses first"><i class="bi bi-trash text-muted"></i></button>
                            @else
                                <form method="POST" action="{{ route('admin.my-expense-categories.destroy', $category) }}"
                                    onsubmit="return confirm('Delete the category &quot;{{ $category->name }}&quot;?');">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="btn btn-sm btn-light border btn-icon text-danger" title="Delete category"><i class="bi bi-trash"></i></button>
                                </form>
                            @endif
                        @endcan
                    </div>
                @endforeach
            </div>
            <div class="form-text mt-2">Renaming a category renames it on every expense filed under it. A category can only be deleted once nothing is filed under it.</div>
        </x-modal>
    @endcanany

    <x-modal id="modal-my-profit-breakdown" title="My Profit — Full Calculation ({{ $periodLabel }})">
        <div class="d-flex flex-column gap-2" id="my-profit-breakdown">
            <div class="d-flex align-items-center justify-content-between">
                <span style="font-size: .85rem;">Total Our Hire Value</span>
                <span class="fw-semibold" style="font-size: .85rem;">Rs. {{ number_format($profitBreakdown['our_hire_value_total'], 2) }}</span>
            </div>
            <div class="d-flex align-items-center justify-content-between">
                <span style="font-size: .85rem;">Less: Drivers' Hire Expenses</span>
                <span class="text-danger" style="font-size: .85rem;">-Rs. {{ number_format($profitBreakdown['expenses_total'], 2) }}</span>
            </div>
            <div class="d-flex align-items-center justify-content-between">
                <span style="font-size: .85rem;">Less: Driver Salary ({{ $profitBreakdown['salary_percentage'] }}%)</span>
                <span class="text-danger" style="font-size: .85rem;">-Rs. {{ number_format($profitBreakdown['salary_total'], 2) }}</span>
            </div>
            <div class="d-flex align-items-center justify-content-between">
                <span style="font-size: .85rem;">Less: Leasing Installments</span>
                <span class="text-danger" style="font-size: .85rem;">-Rs. {{ number_format($profitBreakdown['leasing_installment_total'], 2) }}</span>
            </div>
            <div class="d-flex align-items-center justify-content-between">
                <span style="font-size: .85rem;">Less: Vehicle Repair Cost</span>
                <span class="text-danger" style="font-size: .85rem;">-Rs. {{ number_format($profitBreakdown['repair_cost_total'], 2) }}</span>
            </div>

            <div class="d-flex align-items-center justify-content-between border-top pt-2">
                <span class="fw-semibold" style="font-size: .85rem;">Profit Before My Expenses</span>
                <span class="fw-semibold {{ $profitBeforeExpenses < 0 ? 'text-danger' : '' }}" style="font-size: .85rem;">{{ $money($profitBeforeExpenses) }}</span>
            </div>

            <div class="border-top pt-2">
                <div class="text-muted mb-1" style="font-size: .78rem;">Less: My Expenses</div>
                @forelse ($byCategory as $category => $amount)
                    <div class="d-flex align-items-center justify-content-between ps-2 mb-1">
                        <span class="text-muted" style="font-size: .8rem;">{{ $categories[$category] ?? ucfirst($category) }}</span>
                        <span class="text-danger" style="font-size: .8rem;">-Rs. {{ number_format($amount, 2) }}</span>
                    </div>
                @empty
                    <div class="ps-2 text-muted" style="font-size: .8rem;">None recorded for {{ $periodLabel }}.</div>
                @endforelse
                <div class="d-flex align-items-center justify-content-between ps-2">
                    <span class="text-muted fw-semibold" style="font-size: .8rem;">Total My Expenses</span>
                    <span class="text-danger fw-semibold" style="font-size: .8rem;">-Rs. {{ number_format($total, 2) }}</span>
                </div>
            </div>

            <div class="d-flex align-items-center justify-content-between border-top pt-2 mt-1">
                <span class="fw-bold">My Profit</span>
                <span class="fw-bold {{ $myProfit < 0 ? 'text-danger' : 'text-success' }}" style="font-size: 1.1rem;">{{ $money($myProfit) }}</span>
            </div>

            <div class="text-muted mt-2" style="font-size: .72rem;">
                Profit Before My Expenses ({{ $money($profitBeforeExpenses) }})
                − My Expenses (Rs. {{ number_format($total, 2) }})
                = {{ $money($myProfit) }}.
            </div>
        </div>
    </x-modal>
@endsection

@push('scripts')
    <script>
        // "＋ Add new category…" reveals a name box under the category dropdown.
        document.addEventListener('change', function (event) {
            var select = event.target.closest('select[data-category-select]');
            if (! select) return;

            var prefix = select.dataset.categorySelect;
            var wrap = document.getElementById(prefix + '-new-category-wrap');
            var input = document.getElementById(prefix + '-new-category');
            var adding = select.value === @json(\App\Models\MyExpenseCategory::NEW_OPTION);

            wrap.style.display = adding ? '' : 'none';
            input.required = adding;
            if (adding) input.focus();
        });
    </script>
@endpush
