<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Login · {{ config('app.name', 'Admin') }}</title>

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
        }

        * { font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif; }

        body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background:
                radial-gradient(circle at 15% 20%, rgba(79,70,229,.08), transparent 40%),
                radial-gradient(circle at 85% 80%, rgba(129,140,248,.10), transparent 40%),
                #f7f8fb;
            padding: 1.5rem;
        }

        .login-card {
            max-width: 340px;
            width: 100%;
            background: #fff;
            border: 1px solid var(--border-color);
            border-radius: .85rem;
            box-shadow: 0 20px 40px -20px rgba(30, 41, 59, .15);
            padding: 1.65rem 1.5rem;
        }

        .brand-icon {
            width: 42px;
            height: 42px;
            border-radius: 11px;
            background: linear-gradient(135deg, var(--primary), #818cf8);
            color: #fff;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.2rem;
            margin: 0 auto .85rem;
        }

        h1 { font-size: 1.05rem; font-weight: 800; color: var(--text-dark); }
        .subtitle { color: var(--text-muted); font-size: .78rem; }

        .form-label { font-weight: 600; font-size: .78rem; color: var(--text-dark); }

        .input-group-text {
            background: #fff;
            border-color: var(--border-color);
            color: #a3aab8;
            font-size: .8rem;
        }

        .form-control {
            border-color: var(--border-color);
            border-radius: .5rem;
            padding: .45rem .7rem;
            font-size: .8rem;
        }
        .form-control:focus {
            border-color: var(--primary);
            box-shadow: 0 0 0 .2rem rgba(79, 70, 229, .12);
        }
        .input-group .form-control { border-radius: 0 .5rem .5rem 0; }
        .input-group .input-group-text { border-radius: .5rem 0 0 .5rem; }

        .btn-primary {
            background: var(--primary);
            border-color: var(--primary);
            border-radius: .5rem;
            font-weight: 600;
            font-size: .82rem;
            padding: .5rem;
        }
        .btn-primary:hover { background: var(--primary-dark); border-color: var(--primary-dark); }
        .form-check-label { font-size: .78rem; }
        .alert { font-size: .78rem; }
    </style>
</head>
<body>
    <div class="login-card">
        <div class="brand-icon"><i class="bi bi-car-front-fill"></i></div>
        <h1 class="text-center mb-1">{{ config('app.name', 'Admin') }}</h1>
        <p class="subtitle text-center mb-3">Sign in to manage your dashboard</p>

        @if (session('error'))
            <div class="alert alert-danger py-2 small">{{ session('error') }}</div>
        @endif

        @if ($errors->any())
            <div class="alert alert-danger py-2 small mb-3">
                <ul class="mb-0 ps-3">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        <form method="POST" action="{{ route('login') }}">
            @csrf

            <div class="mb-3">
                <label for="email" class="form-label">Email</label>
                <div class="input-group">
                    <span class="input-group-text"><i class="bi bi-envelope"></i></span>
                    <input id="email" type="email" name="email" value="{{ old('email') }}" class="form-control" placeholder="you@example.com" required autofocus>
                </div>
            </div>

            <div class="mb-3">
                <label for="password" class="form-label">Password</label>
                <div class="input-group">
                    <span class="input-group-text"><i class="bi bi-lock"></i></span>
                    <input id="password" type="password" name="password" class="form-control" placeholder="••••••••" required>
                </div>
            </div>

            <div class="mb-3 form-check">
                <input type="checkbox" name="remember" id="remember" class="form-check-input">
                <label for="remember" class="form-check-label text-muted">Remember me</label>
            </div>

            <button type="submit" class="btn btn-primary w-100">
                Sign in <i class="bi bi-arrow-right ms-1"></i>
            </button>
        </form>
    </div>
</body>
</html>
