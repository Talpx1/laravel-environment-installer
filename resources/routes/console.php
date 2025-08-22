<?php

declare(strict_types=1);

Illuminate\Support\Facades\Schedule::timezone(config()->string('app.scheduler_timezone'))->group(function (\Illuminate\Console\Scheduling\Schedule $schedule) {
    $schedule->command('backup:clean')->dailyAt('01:00');
    $schedule->command('backup:run')->dailyAt('22:00');
    $schedule->command('backup:monitor')->dailyAt('03:00');

    $schedule->command('telescope:prune')->dailyAt('23:00');
    $schedule->command('activitylog:clean --days=30')->dailyAt('00:00');
});
