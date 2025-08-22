#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

declare -a services=("laravel-worker:laravel-worker_00" "laravel-cron" "apache")

for service in "${services[@]}"; do
    if ! supervisorctl status "$service" | grep -q "RUNNING"; then
        echo "[HEALTHCHECK] ❌ $service not running"
        exit 1
    fi
done

echo "[HEALTHCHECK] ✅ All services are running"
exit 0
