@extends('layouts.admin')

@section('title', 'Logs')
@section('subtitle', 'Application log entries from storage/logs, newest first.')

@php
    $levelStyles = [
        'emergency' => ['danger', 'bi-x-octagon-fill'],
        'alert' => ['danger', 'bi-exclamation-octagon-fill'],
        'critical' => ['danger', 'bi-exclamation-octagon'],
        'error' => ['danger', 'bi-x-circle'],
        'warning' => ['warning', 'bi-exclamation-triangle'],
        'notice' => ['info', 'bi-info-circle'],
        'info' => ['primary', 'bi-info-circle'],
        'debug' => ['secondary', 'bi-bug'],
    ];

    $formatBytes = function (int $bytes): string {
        if ($bytes >= 1048576) {
            return number_format($bytes / 1048576, 1).' MB';
        }

        return $bytes >= 1024 ? number_format($bytes / 1024, 1).' KB' : $bytes.' B';
    };

    // Filter links keep the chosen file and search text.
    $baseQuery = array_filter(['file' => $selectedFile['name'] ?? null, 'search' => $search]);
@endphp

@section('content')
    @if ($selectedFile === null)
        <div class="card border-0">
            <div class="card-body text-center text-muted py-5">
                <i class="bi bi-terminal fs-3 d-block mb-2"></i>
                No log files yet. Entries will appear here once the application logs something.
            </div>
        </div>
    @else
        <div class="d-flex flex-wrap gap-2 mb-2">
            <a href="{{ route('admin.logs.index', $baseQuery) }}"
                class="btn btn-sm rounded-pill {{ $level === '' ? 'btn-dark' : 'btn-light border' }}">
                All <span class="ms-1 fw-semibold">{{ number_format($totalMatching) }}</span>
            </a>
            @foreach ($levelCounts as $name => $count)
                @php [$color, $icon] = $levelStyles[$name] ?? ['secondary', 'bi-dot']; @endphp
                <a href="{{ route('admin.logs.index', $baseQuery + ['level' => $name]) }}"
                    class="btn btn-sm rounded-pill {{ $level === $name ? 'btn-'.$color : 'btn-light border' }}">
                    <i class="bi {{ $icon }} {{ $level === $name ? '' : 'text-'.$color }}"></i>
                    {{ ucfirst($name) }} <span class="ms-1 fw-semibold">{{ number_format($count) }}</span>
                </a>
            @endforeach
        </div>

        @if ($truncated)
            <div class="alert alert-warning py-2 mb-2" style="font-size: .8rem;">
                <i class="bi bi-exclamation-triangle me-1"></i>
                This file is {{ $formatBytes($selectedFile['size']) }} &mdash; only the latest {{ $formatBytes($maxReadBytes) }} is shown.
                Download the file to read the rest.
            </div>
        @endif

        <div class="card border-0">
            <div class="card-header">
                <form method="GET" class="d-flex flex-wrap align-items-center gap-2">
                    @if ($level !== '')
                        <input type="hidden" name="level" value="{{ $level }}">
                    @endif

                    <div class="position-relative" style="max-width: 280px; flex: 1 1 200px;">
                        <i class="bi bi-search position-absolute" style="left: .65rem; top: 50%; transform: translateY(-50%); color: #a3aab8; font-size: .8rem;"></i>
                        <input type="search" name="search" value="{{ $search }}" class="form-control" style="padding-left: 1.85rem;" placeholder="Search message or stack trace...">
                    </div>

                    @if (count($files) > 1)
                        <select name="file" class="form-select" style="max-width: 240px;" onchange="this.form.submit()">
                            @foreach ($files as $file)
                                <option value="{{ $file['name'] }}" {{ $selectedFile['name'] === $file['name'] ? 'selected' : '' }}>
                                    {{ $file['name'] }} ({{ $formatBytes($file['size']) }})
                                </option>
                            @endforeach
                        </select>
                    @else
                        <input type="hidden" name="file" value="{{ $selectedFile['name'] }}">
                        <span class="text-muted small"><i class="bi bi-file-earmark-text"></i> {{ $selectedFile['name'] }} &middot; {{ $formatBytes($selectedFile['size']) }}</span>
                    @endif

                    <button type="submit" class="btn btn-light border">Search</button>

                    @if ($search !== '' || $level !== '')
                        <a href="{{ route('admin.logs.index', ['file' => $selectedFile['name']]) }}" class="btn btn-light border">Clear</a>
                    @endif

                    <a href="{{ route('admin.logs.download', ['file' => $selectedFile['name']]) }}" class="btn btn-light border ms-auto">
                        <i class="bi bi-download"></i> Download
                    </a>
                </form>
            </div>

            @if ($logs->isEmpty())
                <div class="card-body text-center text-muted py-5">
                    <i class="bi bi-journal-text fs-3 d-block mb-2"></i>
                    @if ($search !== '' || $level !== '')
                        No log entries match these filters.
                    @else
                        This log file has no entries.
                    @endif
                </div>
            @else
                <div class="table-responsive">
                    <table class="table align-middle mb-0 log-table">
                        <thead>
                            <tr>
                                <th style="width: 160px;">Time</th>
                                <th class="d-none d-sm-table-cell" style="width: 110px;">Level</th>
                                <th>Message</th>
                                <th style="width: 44px;"></th>
                            </tr>
                        </thead>
                        @foreach ($logs as $entry)
                            @php
                                [$color, $icon] = $levelStyles[$entry['level']] ?? ['secondary', 'bi-dot'];
                                $detailId = 'log-detail-'.$loop->index;
                                $hasDetail = $entry['stack'] !== [] || $entry['context'] !== '' || mb_strlen($entry['message']) > 140;
                            @endphp
                            <tbody>
                                <tr class="log-row {{ $hasDetail ? 'log-row-toggle' : '' }}"
                                    @if ($hasDetail) data-bs-toggle="collapse" data-bs-target="#{{ $detailId }}" role="button" aria-expanded="false" aria-controls="{{ $detailId }}" @endif>
                                    <td class="text-nowrap">
                                        <div class="fw-semibold" style="font-size: .8rem;">{{ $entry['logged_at']->format('M j, Y') }}</div>
                                        <div class="text-muted" style="font-size: .72rem;">{{ $entry['logged_at']->format('H:i:s') }}</div>
                                    </td>
                                    <td class="d-none d-sm-table-cell">
                                        <span class="badge rounded-pill bg-{{ $color }}-subtle text-{{ $color }}-emphasis">
                                            <i class="bi {{ $icon }}"></i> {{ ucfirst($entry['level']) }}
                                        </span>
                                        <div class="text-muted" style="font-size: .68rem;">{{ $entry['env'] }}</div>
                                    </td>
                                    <td>
                                        {{-- Phones hide the Level column, so the badge moves in here. --}}
                                        <span class="badge rounded-pill bg-{{ $color }}-subtle text-{{ $color }}-emphasis d-sm-none mb-1">
                                            <i class="bi {{ $icon }}"></i> {{ ucfirst($entry['level']) }}
                                        </span>
                                        <div class="log-message">{{ $entry['message'] }}</div>
                                    </td>
                                    <td class="text-end text-muted">
                                        @if ($hasDetail)
                                            <i class="bi bi-chevron-down log-chevron"></i>
                                        @endif
                                    </td>
                                </tr>
                                @if ($hasDetail)
                                    <tr>
                                        <td colspan="4" class="p-0 border-0">
                                            <div class="collapse" id="{{ $detailId }}">
                                                <div class="log-detail">
                                                    <button type="button" class="btn btn-sm btn-light border log-copy" data-copy-target="#{{ $detailId }}-text">
                                                        <i class="bi bi-clipboard"></i> Copy
                                                    </button>
                                                    <div id="{{ $detailId }}-text">
                                                        <div class="log-line">{{ $entry['message'] }}</div>
                                                        @if ($entry['context'] !== '')
                                                            <div class="log-line log-context">{{ $entry['context'] }}</div>
                                                        @endif
                                                        @foreach ($entry['stack'] as $line)
                                                            <div class="log-line {{ str_contains($line, '/vendor/') ? 'log-vendor' : '' }}">{{ $line }}</div>
                                                        @endforeach
                                                    </div>
                                                </div>
                                            </div>
                                        </td>
                                    </tr>
                                @endif
                            </tbody>
                        @endforeach
                    </table>
                </div>

                <div class="card-footer bg-white">
                    @if ($logs->hasPages())
                        {{ $logs->links() }}
                    @else
                        {{-- The paginator renders its own "Showing x to y of z" text, but only when there are several pages. --}}
                        <span class="text-muted small">Showing {{ number_format($logs->total()) }} entr{{ $logs->total() === 1 ? 'y' : 'ies' }}</span>
                    @endif
                </div>
            @endif
        </div>
    @endif
@endsection

@push('styles')
    <style>
        .log-table tbody { border-top: 1px solid var(--border-color); }
        .log-table tbody:first-of-type { border-top: 0; }
        .log-row-toggle { cursor: pointer; }
        .log-row-toggle:hover > td { background: var(--bg); }
        .log-row-toggle[aria-expanded="true"] .log-chevron { transform: rotate(180deg); }
        .log-chevron { display: inline-block; font-size: .75rem; transition: transform .15s ease; }
        .log-message {
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
            overflow-wrap: anywhere;
        }
        .log-detail {
            position: relative;
            margin: 0 .75rem .75rem;
            padding: .75rem 1rem;
            background: #0f172a;
            color: #e2e8f0;
            border-radius: .5rem;
            max-height: 420px;
            overflow: auto;
            font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
            font-size: .72rem;
        }
        .log-line { white-space: pre-wrap; overflow-wrap: anywhere; min-height: 1em; }
        .log-context { color: #93c5fd; }
        .log-vendor { color: #64748b; }
        .log-copy { position: sticky; top: 0; float: right; margin: -.25rem -.5rem 0 .5rem; font-size: .7rem; }
    </style>
@endpush

@push('scripts')
    <script>
        document.querySelectorAll('.log-copy').forEach((button) => {
            button.addEventListener('click', async () => {
                const text = document.querySelector(button.dataset.copyTarget)?.innerText ?? '';
                try {
                    await navigator.clipboard.writeText(text);
                    button.innerHTML = '<i class="bi bi-check2"></i> Copied';
                } catch (e) {
                    button.innerHTML = '<i class="bi bi-x"></i> Copy failed';
                }
                setTimeout(() => { button.innerHTML = '<i class="bi bi-clipboard"></i> Copy'; }, 1500);
            });
        });
    </script>
@endpush
