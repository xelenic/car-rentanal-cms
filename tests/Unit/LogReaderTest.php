<?php

use App\Support\LogReader;

function sampleLog(): string
{
    return implode("\n", [
        '[2026-08-03 11:19:12] local.ERROR: Route [x] not defined. {"userId":1,"exception":"[object] (Boom(code: 0))',
        '[stacktrace]',
        '#0 /app/vendor/laravel/framework/src/Foo.php(59): Bar->baz()',
        '#1 /app/app/Http/Controllers/HomeController.php(12): Foo->run()',
        '"} ',
        '',
        '[2026-08-04 06:51:34] production.INFO: User signed in [] []',
        '[2026-08-04 07:00:00] local.WARNING: Disk almost full {"free_mb":12}',
        '',
    ]);
}

test('it parses entries newest first with level, env, message and context', function () {
    $entries = (new LogReader(sys_get_temp_dir()))->parse(sampleLog());

    expect($entries)->toHaveCount(3);
    expect(array_column($entries, 'level'))->toBe(['warning', 'info', 'error']);

    [$warning, $info, $error] = $entries;

    expect($warning['message'])->toBe('Disk almost full')
        ->and($warning['context'])->toBe('{"free_mb":12}')
        ->and($info['message'])->toBe('User signed in')
        ->and($info['context'])->toBe('')
        ->and($info['env'])->toBe('production')
        ->and($info['logged_at']->format('Y-m-d H:i:s'))->toBe('2026-08-04 06:51:34')
        ->and($error['message'])->toBe('Route [x] not defined.')
        ->and($error['context'])->toStartWith('{"userId":1');
});

test('it keeps stack trace lines with the entry they belong to', function () {
    $error = (new LogReader(sys_get_temp_dir()))->parse(sampleLog())[2];

    expect($error['stack'])->toHaveCount(4)
        ->and($error['stack'][0])->toBe('[stacktrace]')
        ->and($error['stack'][2])->toContain('HomeController.php');
});

test('text before the first entry header is ignored', function () {
    $entries = (new LogReader(sys_get_temp_dir()))->parse("tail of a cut-off entry\n#3 leftover frame\n".sampleLog());

    expect($entries)->toHaveCount(3);
});

test('search matches message, context and stack trace case-insensitively', function () {
    $reader = new LogReader(sys_get_temp_dir());
    $entries = $reader->parse(sampleLog());

    expect($reader->matching($entries, ''))->toHaveCount(3)
        ->and($reader->matching($entries, 'DISK'))->toHaveCount(1)
        ->and($reader->matching($entries, 'homecontroller'))->toHaveCount(1)
        ->and($reader->matching($entries, 'free_mb'))->toHaveCount(1)
        ->and($reader->matching($entries, 'nothing like this'))->toBe([]);
});

test('files() lists only .log files and read() tails a file larger than the limit', function () {
    $dir = sys_get_temp_dir().'/logreader-'.uniqid();
    mkdir($dir);

    $bigLine = '[2026-08-04 07:00:00] local.INFO: '.str_repeat('x', 1000)."\n";
    file_put_contents($dir.'/laravel.log', str_repeat($bigLine, (int) (LogReader::MAX_READ_BYTES / strlen($bigLine)) + 50));
    file_put_contents($dir.'/notes.txt', 'not a log');

    $reader = new LogReader($dir);

    expect(array_keys($reader->files()))->toBe(['laravel.log']);

    $result = $reader->read($dir.'/laravel.log');
    expect($result['truncated'])->toBeTrue()
        ->and($result['entries'])->not->toBeEmpty()
        ->and($result['entries'][0]['message'])->toStartWith('xxxx');

    unlink($dir.'/laravel.log');
    unlink($dir.'/notes.txt');
    rmdir($dir);
});
