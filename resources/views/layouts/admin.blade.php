<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Dashboard') · {{ config('app.name', 'Admin') }}</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">

    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">

    <style>
        :root {
            --primary: #4f46e5;
            --primary-dark: #4338ca;
            --primary-light: #eef2ff;
            --text-dark: #1e293b;
            --text-muted: #64748b;
            --border-color: #e6e9f0;
            --bg: #f7f8fb;
            --sidebar-width: 228px;
        }

        * { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif; }

        body { background: var(--bg); color: var(--text-dark); font-size: .875rem; }

        a { text-decoration: none; }

        /* Layout */
        .app-shell { display: flex; min-height: 100vh; }

        .sidebar {
            width: var(--sidebar-width);
            flex-shrink: 0;
            background: #fff;
            border-right: 1px solid var(--border-color);
            position: sticky;
            top: 0;
            height: 100vh;
            overflow-y: auto;
        }

        .sidebar-brand {
            display: flex;
            align-items: center;
            gap: .55rem;
            padding: 1.1rem 1rem;
            font-weight: 800;
            font-size: .9rem;
            color: var(--text-dark);
        }

        .sidebar-brand-icon {
            width: 30px;
            height: 30px;
            border-radius: 8px;
            background: linear-gradient(135deg, var(--primary), #818cf8);
            color: #fff;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: .9rem;
            flex-shrink: 0;
        }

        .sidebar-section-label {
            font-size: .62rem;
            font-weight: 700;
            letter-spacing: .08em;
            text-transform: uppercase;
            color: #a3aab8;
            padding: 0 1rem;
            margin: .9rem 0 .35rem;
        }

        .sidebar-nav { padding: 0 .65rem; list-style: none; margin: 0; }

        .sidebar-nav .nav-link {
            display: flex;
            align-items: center;
            gap: .6rem;
            padding: .45rem .65rem;
            border-radius: .5rem;
            color: var(--text-muted);
            font-weight: 500;
            font-size: .8rem;
            margin-bottom: .1rem;
            transition: background .15s ease, color .15s ease;
        }

        .sidebar-nav .nav-link i { font-size: .95rem; width: 1.2rem; text-align: center; }

        .sidebar-nav .nav-link:hover { background: var(--bg); color: var(--text-dark); }

        .sidebar-nav .nav-link.active {
            background: var(--primary-light);
            color: var(--primary);
            font-weight: 600;
        }

        .main { flex: 1; min-width: 0; display: flex; flex-direction: column; }

        .topbar {
            height: 54px;
            flex-shrink: 0;
            background: #fff;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 1.25rem;
        }

        .topbar-search {
            position: relative;
            width: 240px;
        }

        .topbar-search i {
            position: absolute;
            left: .75rem;
            top: 50%;
            transform: translateY(-50%);
            color: #a3aab8;
            font-size: .8rem;
        }

        .topbar-search input {
            width: 100%;
            border: 1px solid var(--border-color);
            background: var(--bg);
            border-radius: .5rem;
            padding: .35rem .6rem .35rem 1.9rem;
            font-size: .8rem;
            outline: none;
        }

        .topbar-search input:focus { border-color: var(--primary); background: #fff; }

        .user-menu-btn {
            display: flex;
            align-items: center;
            gap: .5rem;
            border: none;
            background: transparent;
            padding: .3rem .45rem;
            border-radius: .5rem;
        }

        .user-menu-btn:hover { background: var(--bg); }

        .avatar-circle {
            border-radius: 50%;
            background: var(--primary-light);
            color: var(--primary);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 700;
            flex-shrink: 0;
        }

        .page-header {
            padding: 1.1rem 1.25rem 0;
            display: flex;
            align-items: flex-end;
            justify-content: space-between;
            gap: .75rem;
            flex-wrap: wrap;
        }

        .page-header h1 {
            font-size: 1.1rem;
            font-weight: 700;
            margin: 0 0 .15rem;
            color: var(--text-dark);
        }

        .page-header p {
            color: var(--text-muted);
            font-size: .78rem;
            margin: 0;
        }

        .content { padding: .85rem 1.25rem 1.5rem; }

        /* Cards */
        .card {
            border: 1px solid var(--border-color);
            border-radius: .7rem;
            box-shadow: 0 1px 2px rgba(16, 24, 40, .03);
        }

        .card-body { padding: 1rem; }
        .card-header { background: #fff; border-bottom: 1px solid var(--border-color); border-radius: .7rem .7rem 0 0 !important; padding: .65rem 1rem; }
        .card-footer { padding: .5rem 1rem; }

        /* Buttons */
        .btn { border-radius: .5rem; font-weight: 500; font-size: .8rem; padding: .4rem .8rem; }
        .btn-sm { font-size: .75rem; padding: .3rem .6rem; }
        .btn-primary { background: var(--primary); border-color: var(--primary); }
        .btn-primary:hover { background: var(--primary-dark); border-color: var(--primary-dark); }
        .btn-icon { width: 28px; height: 28px; padding: 0; display: inline-flex; align-items: center; justify-content: center; }

        /* Forms */
        .form-label { font-weight: 600; font-size: .78rem; color: var(--text-dark); margin-bottom: .3rem; }
        .form-control, .form-select {
            border-color: var(--border-color);
            border-radius: .5rem;
            padding: .4rem .65rem;
            font-size: .8rem;
        }
        .form-control:focus, .form-select:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 .2rem rgba(79, 70, 229, .12);
        }
        .form-text { font-size: .72rem; }

        /* Tables */
        .table { margin-bottom: 0; font-size: .8rem; }
        .table thead th {
            font-size: .65rem;
            text-transform: uppercase;
            letter-spacing: .05em;
            color: #a3aab8;
            font-weight: 700;
            border-bottom: 1px solid var(--border-color);
            padding: .55rem .85rem;
            background: #fbfbfd;
        }
        .table tbody td { padding: .5rem .85rem; vertical-align: middle; border-color: var(--border-color); font-size: .8rem; }
        .table tbody tr:hover { background: #fbfbfd; }

        /* Checkbox chips */
        .chip-check {
            border: 1px solid var(--border-color);
            border-radius: .5rem;
            padding: .35rem .6rem;
            display: flex;
            align-items: center;
            gap: .4rem;
            transition: border-color .15s ease, background .15s ease;
        }
        .chip-check:has(input:checked) { border-color: var(--primary); background: var(--primary-light); }
        .chip-check input { accent-color: var(--primary); }

        .stat-icon {
            width: 38px;
            height: 38px;
            border-radius: .6rem;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.05rem;
            flex-shrink: 0;
        }

        .badge { font-size: .68rem; font-weight: 600; }
        .dropdown-menu { font-size: .8rem; }
        .dropdown-item, .dropdown-item-text { padding: .35rem .85rem; }
        .alert { padding: .5rem .85rem; font-size: .8rem; border-radius: .5rem; }
        code { font-size: .78rem; }

        /* Modals */
        .modal-content { border: 1px solid var(--border-color); border-radius: .8rem; }
        .modal-header { padding: .85rem 1.1rem; border-bottom: 1px solid var(--border-color); }
        .modal-title { font-size: .95rem; font-weight: 700; color: var(--text-dark); }
        .modal-body { padding: 1.1rem; }
        .modal-footer { padding: .75rem 1.1rem; border-top: 1px solid var(--border-color); }
        .invalid-feedback { font-size: .72rem; }
        .is-invalid { border-color: #dc3545 !important; }
    </style>

    @stack('styles')
</head>
<body>
    <div class="app-shell">
        <aside class="sidebar">
            <a href="{{ route('admin.dashboard') }}" class="sidebar-brand">
                <span class="sidebar-brand-icon"><i class="bi bi-car-front-fill"></i></span>
                {{ config('app.name', 'Admin') }}
            </a>

            <div class="sidebar-section-label">Overview</div>
            <ul class="sidebar-nav">
                <li>
                    <a class="nav-link {{ request()->routeIs('admin.dashboard') ? 'active' : '' }}" href="{{ route('admin.dashboard') }}">
                        <i class="bi bi-grid-1x2"></i> Dashboard
                    </a>
                </li>
            </ul>

            @canany(['vehicles.view', 'drivers.view', 'locations.view', 'salary-advances.view'])
                <div class="sidebar-section-label">Fleet</div>
                <ul class="sidebar-nav">
                    @can('vehicles.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.vehicles.*') ? 'active' : '' }}" href="{{ route('admin.vehicles.index') }}">
                                <i class="bi bi-car-front"></i> Vehicles
                            </a>
                        </li>
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.repairs.*') ? 'active' : '' }}" href="{{ route('admin.repairs.index') }}">
                                <i class="bi bi-tools"></i> Repairs
                            </a>
                        </li>
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.leasing.*') ? 'active' : '' }}" href="{{ route('admin.leasing.index') }}">
                                <i class="bi bi-file-earmark-text"></i> Leasing
                            </a>
                        </li>
                    @endcan
                    @can('drivers.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.drivers.*') ? 'active' : '' }}" href="{{ route('admin.drivers.index') }}">
                                <i class="bi bi-person-badge"></i> Drivers
                            </a>
                        </li>
                    @endcan
                    @can('locations.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.locations.*') ? 'active' : '' }}" href="{{ route('admin.locations.index') }}">
                                <i class="bi bi-geo-alt"></i> Locations
                            </a>
                        </li>
                    @endcan
                    @can('salary-advances.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.salary-advances.*') ? 'active' : '' }}" href="{{ route('admin.salary-advances.index') }}">
                                <i class="bi bi-cash-coin"></i> Salary Advances
                                @php
                                    $pendingAdvanceCount = \App\Models\SalaryAdvanceRequest::where('status', 'pending')->count();
                                @endphp
                                @if ($pendingAdvanceCount > 0)
                                    <span class="badge rounded-pill bg-danger ms-1">{{ $pendingAdvanceCount }}</span>
                                @endif
                            </a>
                        </li>
                    @endcan
                </ul>
            @endcanany

            @canany(['packages.view', 'customers.view', 'hires.view'])
                <div class="sidebar-section-label">Offerings</div>
                <ul class="sidebar-nav">
                    @can('customers.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.customers.*') ? 'active' : '' }}" href="{{ route('admin.customers.index') }}">
                                <i class="bi bi-person-lines-fill"></i> Customers
                            </a>
                        </li>
                    @endcan
                    @can('packages.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.packages.*') ? 'active' : '' }}" href="{{ route('admin.packages.index') }}">
                                <i class="bi bi-box-seam"></i> Packages
                            </a>
                        </li>
                    @endcan
                    @can('hires.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.hires.*') ? 'active' : '' }}" href="{{ route('admin.hires.index') }}">
                                <i class="bi bi-journal-check"></i> Hires
                            </a>
                        </li>
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.expenses.*') ? 'active' : '' }}" href="{{ route('admin.expenses.index') }}">
                                <i class="bi bi-receipt"></i> Expenses
                            </a>
                        </li>
                    @endcan
                </ul>
            @endcanany

            @canany(['users.view', 'roles.view', 'permissions.view'])
                <div class="sidebar-section-label">Access Control</div>
                <ul class="sidebar-nav">
                    @can('users.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.users.*') ? 'active' : '' }}" href="{{ route('admin.users.index') }}">
                                <i class="bi bi-people"></i> Users
                            </a>
                        </li>
                    @endcan
                    @can('roles.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.roles.*') ? 'active' : '' }}" href="{{ route('admin.roles.index') }}">
                                <i class="bi bi-shield-check"></i> Roles
                            </a>
                        </li>
                    @endcan
                    @can('permissions.view')
                        <li>
                            <a class="nav-link {{ request()->routeIs('admin.permissions.*') ? 'active' : '' }}" href="{{ route('admin.permissions.index') }}">
                                <i class="bi bi-key"></i> Permissions
                            </a>
                        </li>
                    @endcan
                </ul>
            @endcanany
        </aside>

        <div class="main">
            <header class="topbar">
                <div class="topbar-search">
                    <i class="bi bi-search"></i>
                    <input type="search" placeholder="Search..." disabled>
                </div>

                <div class="dropdown">
                    <button class="user-menu-btn dropdown-toggle" type="button" data-bs-toggle="dropdown">
                        <x-avatar :name="auth()->user()->name" :size="28" />
                        <span class="d-none d-sm-flex flex-column text-start lh-sm">
                            <span class="fw-semibold" style="font-size: .78rem;">{{ auth()->user()->name }}</span>
                            <span class="text-muted" style="font-size: .68rem;">{{ auth()->user()->roles->first()->name ?? 'No role' }}</span>
                        </span>
                    </button>
                    <ul class="dropdown-menu dropdown-menu-end shadow-sm">
                        <li><span class="dropdown-item-text small text-muted">{{ auth()->user()->email }}</span></li>
                        <li><hr class="dropdown-divider"></li>
                        <li>
                            <form method="POST" action="{{ route('logout') }}">
                                @csrf
                                <button type="submit" class="dropdown-item text-danger">
                                    <i class="bi bi-box-arrow-right me-2"></i> Logout
                                </button>
                            </form>
                        </li>
                    </ul>
                </div>
            </header>

            <div class="page-header">
                <div>
                    <h1>@yield('title', 'Dashboard')</h1>
                    @hasSection('subtitle')
                        <p>@yield('subtitle')</p>
                    @endif
                </div>
                @hasSection('actions')
                    <div>@yield('actions')</div>
                @endif
            </div>

            <main class="content">
                @if (session('status'))
                    <div class="alert alert-success d-flex align-items-center gap-2">
                        <i class="bi bi-check-circle-fill"></i> {{ session('status') }}
                    </div>
                @endif

                @if (session('error'))
                    <div class="alert alert-danger d-flex align-items-center gap-2">
                        <i class="bi bi-exclamation-triangle-fill"></i> {{ session('error') }}
                    </div>
                @endif

                @if ($errors->any())
                    <div class="alert alert-danger">
                        <ul class="mb-0 ps-3">
                            @foreach ($errors->all() as $error)
                                <li>{{ $error }}</li>
                            @endforeach
                        </ul>
                    </div>
                @endif

                @yield('content')
            </main>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            var reopenId = @json($errors->any() ? old('form_id') : null);
            var targetId = reopenId ? 'modal-' + reopenId : null;

            if (! targetId && new URLSearchParams(window.location.search).get('new') === '1') {
                targetId = 'modal-create';
            }

            if (targetId) {
                var modalEl = document.getElementById(targetId);
                if (modalEl) {
                    new bootstrap.Modal(modalEl).show();
                }
            }
        });
    </script>
    @stack('scripts')
</body>
</html>
