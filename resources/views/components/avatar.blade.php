@props(['name', 'size' => 40])

@php
    $initials = collect(preg_split('/\s+/', trim($name)))
        ->filter()
        ->map(fn ($word) => mb_strtoupper(mb_substr($word, 0, 1)))
        ->take(2)
        ->join('');
@endphp

<div {{ $attributes->merge(['class' => 'avatar-circle']) }} style="width: {{ $size }}px; height: {{ $size }}px; font-size: {{ round($size * 0.4) }}px;">
    {{ $initials ?: '?' }}
</div>
