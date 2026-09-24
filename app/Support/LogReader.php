<?php

namespace App\Support;

use Illuminate\Support\Carbon;

/**
 * Reads Laravel's plain-text log files (storage/logs/*.log) into structured
 * entries for the admin Logs page. Handles both the "single" channel
 * (laravel.log) and "daily" rotation (laravel-2026-09-24.log).
 */
class LogReader
{
    /** PSR-3 levels, most to least severe. */
    public const LEVELS = ['emergency', 'alert', 'critical', 'error', 'warning', 'notice', 'info', 'debug'];

    /**
     * Only the tail of a log this large is parsed, so a production log that
     * has grown to hundreds of MB can't exhaust memory on a page view.
     */
    public const MAX_READ_BYTES = 5 * 1024 * 1024;

    /** "[2026-08-03 11:19:12] local.ERROR: message…" — the first line of every entry. */
    private const ENTRY_HEADER = '/^\[(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:?\d{2}|Z)?)\] ([\w-]+)\.(\w+): (.*)$/';

    /**
     * @param  string  $timezone  the app's timezone — log timestamps are written in it
     */
    public function __construct(
        private readonly string $directory,
        private readonly string $timezone = 'UTC',
    ) {}

    /**
     * Log files in the directory, most recently modified first, keyed by file
     * name. The keys double as the whitelist of files a request may open.
     *
     * @return array<string, array{name: string, path: string, size: int, modified: int}>
     */
    public function files(): array
    {
        $files = [];

        foreach (glob(rtrim($this->directory, '/').'/*.log') ?: [] as $path) {
            if (! is_file($path)) {
                continue;
            }

            $files[basename($path)] = [
                'name' => basename($path),
                'path' => $path,
                'size' => (int) filesize($path),
                'modified' => (int) filemtime($path),
            ];
        }

        uasort($files, fn (array $a, array $b) => [$b['modified'], $b['name']] <=> [$a['modified'], $a['name']]);

        return $files;
    }

    /**
     * @return array{entries: list<array<string, mixed>>, truncated: bool, size: int}
     */
    public function read(string $path): array
    {
        $size = (int) filesize($path);
        $truncated = $size > self::MAX_READ_BYTES;

        $handle = fopen($path, 'rb');
        if ($truncated) {
            fseek($handle, $size - self::MAX_READ_BYTES);
        }
        $contents = (string) stream_get_contents($handle);
        fclose($handle);

        return [
            'entries' => $this->parse(mb_scrub($contents)),
            'truncated' => $truncated,
            'size' => $size,
        ];
    }

    /**
     * Splits raw log text into entries, newest first. Anything before the
     * first entry header (e.g. the partial entry a tail read starts in) is
     * dropped.
     *
     * @return list<array{logged_at: Carbon, env: string, level: string, message: string, context: string, stack: list<string>}>
     */
    public function parse(string $contents): array
    {
        $entries = [];
        $current = null;

        foreach (preg_split('/\R/', $contents) as $line) {
            $header = $this->parseHeader($line);

            if ($header !== null) {
                if ($current !== null) {
                    $entries[] = $this->finish($current);
                }
                $current = $header;

                continue;
            }

            if ($current !== null) {
                $current['stack'][] = $line;
            }
        }

        if ($current !== null) {
            $entries[] = $this->finish($current);
        }

        return array_reverse($entries);
    }

    /**
     * Entries whose message, context or stack trace contain $search
     * (case-insensitive).
     *
     * @param  list<array<string, mixed>>  $entries
     * @return list<array<string, mixed>>
     */
    public function matching(array $entries, string $search): array
    {
        $needle = mb_strtolower(trim($search));

        if ($needle === '') {
            return $entries;
        }

        return array_values(array_filter($entries, fn (array $entry) => str_contains(
            mb_strtolower($entry['message']."\n".$entry['context']."\n".implode("\n", $entry['stack'])),
            $needle,
        )));
    }

    /** @return array<string, mixed>|null */
    private function parseHeader(string $line): ?array
    {
        if (! preg_match(self::ENTRY_HEADER, $line, $match)) {
            return null;
        }

        try {
            $loggedAt = Carbon::parse($match[1], $this->timezone);
        } catch (\InvalidArgumentException) {
            // Looks like a header but isn't a real date — treat it as a body line.
            return null;
        }

        // Monolog appends the context as JSON (or " [] []" when empty) to the
        // message; show them separately.
        $text = preg_replace('/ \[\] \[\]$/', '', $match[4]);
        $contextAt = strpos($text, ' {"');

        return [
            'logged_at' => $loggedAt,
            'env' => $match[2],
            'level' => strtolower($match[3]),
            'message' => $contextAt === false ? $text : substr($text, 0, $contextAt),
            'context' => $contextAt === false ? '' : substr($text, $contextAt + 1),
            'stack' => [],
        ];
    }

    /**
     * @param  array<string, mixed>  $entry
     * @return array<string, mixed>
     */
    private function finish(array $entry): array
    {
        while ($entry['stack'] !== [] && trim(end($entry['stack'])) === '') {
            array_pop($entry['stack']);
        }

        return $entry;
    }
}
