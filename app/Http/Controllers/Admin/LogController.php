<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Support\LogReader;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Routing\Controllers\Middleware;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class LogController extends Controller implements HasMiddleware
{
    private const PER_PAGE = 25;

    public static function middleware(): array
    {
        return [
            new Middleware('permission:logs.view'),
        ];
    }

    public function index(Request $request): View
    {
        $reader = new LogReader(storage_path('logs'), config('app.timezone'));
        $files = $reader->files();

        // Only names that actually exist in storage/logs are honoured, so the
        // "file" parameter can never point anywhere else.
        $selectedFile = $files[$request->string('file')->toString()] ?? (reset($files) ?: null);

        $search = trim($request->string('search')->toString());
        $level = $request->string('level')->toString();
        $level = in_array($level, LogReader::LEVELS, true) ? $level : '';

        $entries = [];
        $truncated = false;

        if ($selectedFile !== null) {
            ['entries' => $entries, 'truncated' => $truncated] = $reader->read($selectedFile['path']);
        }

        $matching = $reader->matching($entries, $search);

        $counts = array_count_values(array_column($matching, 'level'));
        $levelCounts = [];
        foreach (LogReader::LEVELS as $name) {
            if (isset($counts[$name])) {
                $levelCounts[$name] = $counts[$name];
            }
        }
        foreach ($counts as $name => $count) {
            $levelCounts[$name] ??= $count;
        }

        $filtered = $level === ''
            ? $matching
            : array_values(array_filter($matching, fn (array $entry) => $entry['level'] === $level));

        $page = LengthAwarePaginator::resolveCurrentPage();
        $logs = (new LengthAwarePaginator(
            array_slice($filtered, ($page - 1) * self::PER_PAGE, self::PER_PAGE),
            count($filtered),
            self::PER_PAGE,
            $page,
            ['path' => $request->url()],
        ))->withQueryString();

        return view('admin.logs.index', [
            'logs' => $logs,
            'files' => $files,
            'selectedFile' => $selectedFile,
            'truncated' => $truncated,
            'maxReadBytes' => LogReader::MAX_READ_BYTES,
            'search' => $search,
            'level' => $level,
            'levelCounts' => $levelCounts,
            'totalMatching' => count($matching),
        ]);
    }

    public function download(Request $request): BinaryFileResponse
    {
        $files = (new LogReader(storage_path('logs'), config('app.timezone')))->files();
        $file = $files[$request->string('file')->toString()] ?? null;

        abort_if($file === null, 404);

        return response()->download($file['path'], $file['name'], ['Content-Type' => 'text/plain; charset=UTF-8']);
    }
}
