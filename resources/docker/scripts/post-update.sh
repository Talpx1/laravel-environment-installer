#!/bin/bash

#see https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425?permalink_comment_id=3935570
set -euo pipefail
IFS=$'\n\t'

{
    echo "Start post-update script"

    cd /var/www/html || {
    echo "[FATAL] Failed to cd into /var/www/html"
    exit 1
    }

    echo "Running migrations"
    if php artisan migrate --force; then
    echo "Migrations + seed completed"
    else
    echo "[FATAL] php artisan migrate --force failed"
    exit 1
    fi

    echo "Interrupting schedule"
    if php artisan schedule:interrupt; then
    echo "Schedule Interrupted"
    else
    echo "[WARN] php artisan schedule:interrupt failed (non-blocking)"
    fi

    echo "Reading supervisor config"
    if supervisorctl reread; then
    echo "Read supervisor config"
    else
    echo "[WARN] supervisorctl reread failed (non-blocking)"
    fi

    echo "Updating supervisor config"
    if supervisorctl update; then
    echo "Updated supervisor config"
    else
    echo "[WARN] supervisorctl update failed (non-blocking)"
    fi

    echo "Restarting worker"
    if supervisorctl start laravel-worker:*; then
    echo "Restarted worker"
    else
    echo "[WARN] supervisorctl start laravel-worker:* failed (non-blocking)"
    fi

    echo "Restarting cron"
    if supervisorctl start laravel-cron; then
    echo "Restarted cron"
    else
    echo "[WARN] supervisorctl start laravel-cron failed (non-blocking)"
    fi

    echo "Restarting apache"
    if supervisorctl start apache; then
    echo "Restarted apache"
    else
    echo "[FATAL] supervisorctl start apache failed"
    exit 1
    fi

    echo "Restarting Laravel queues"
    if php artisan queue:restart; then
    echo "Queues restarted"
    else
    echo "[WARN] php artisan queue:restart failed (non-blocking)"
    fi

    echo "Optimizing app"
    if php artisan optimize && chown -R www-data:www-data storage bootstrap/cache; then
    echo "App optimized"
    else
    echo "[FATAL] php artisan optimize && chown -R www-data:www-data storage bootstrap/cache failed"
    exit 1
    fi

    echo "Post-update completed successfully"
} >> "/var/www/html/storage/logs/post-update-$(date +"%F-%H_%M_%S").log" 2>&1
exit 0
