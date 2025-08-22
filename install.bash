#!/usr/bin/env bash

# Special thanks to ChatGPT

set -euo pipefail
#region --- utils ---
set_env_var() {
    local KEY="$1"
    local VALUE="$2"

    for ENV_FILE in "$ROOT_DIR/.env" "$ROOT_DIR/.env.example"; do
        if [[ -f "${ROOT_DIR}/${ENV_FILE}" ]]; then
            if grep -q "^${KEY}=" "$ENV_FILE"; then
                sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$ENV_FILE"
                ok "Modified ${KEY} in $(basename "$ENV_FILE")"
            else
                echo "" >> "$ENV_FILE"
                echo "${KEY}=${VALUE}" >> "$ENV_FILE"
                info "Added ${KEY}=${VALUE} to $(basename "$ENV_FILE")"
            fi
        fi
    done
}

run_in_root_dir(){
    local PREV_PWD
    PREV_PWD=$(pwd)
    cd "${ROOT_DIR}"

    "$@"

    cd "${PREV_PWD}"
}

composer_require() {
    run_in_root_dir composer require "$@" --no-interaction
}

composer_require_dev() {
    composer_require "$@" --dev
}


artisan() {
    run_in_root_dir php artisan "$@"    
}


composer_run() {
    run_in_root_dir composer "$@"
}
# endregion

# region --- colors ---
GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

info()  { echo -e "${CYAN}[INFO]${RESET} $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
# endregion

# region --- paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$SCRIPT_DIR/resources"
# endregion

# region --- requirements detection ---
info "Detecting artisan..."
if [[ ! -f "$ROOT_DIR/artisan" ]]; then
    error "No artisan found in $ROOT_DIR"
fi
ok 'artisan found'

info "Detecting composer..."
if ! command -v composer >/dev/null 2>&1; then
    error "No composer found"
fi
ok 'composer found'

info "Detecting .env..."
if [[ ! -f "$ROOT_DIR/.env" ]]; then
    error "No .env found in $ROOT_DIR"
fi
ok '.env found'

info "Detecting .env.example..."
if [[ ! -f "$ROOT_DIR/.env.example" ]]; then
    warn "No .env.example found in $ROOT_DIR"
else
    ok '.env.example found'
fi

info "Detecting jq..."
JQ_WAS_MISSING=false
if ! command -v jq >/dev/null 2>&1; then
    info "jq not found, installing it (will be removed after the script is done running)..."
    JQ_WAS_MISSING=true

    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sy jq --noconfirm
    else
        error "Unsupported package manager. Install jq manually and re-run this script."
    fi
    ok 'jq installed'
else
    ok 'jq found'
fi
# endregion

# region --- app name/slug ---
DEFAULT_APP_NAME=$(grep -E '^APP_NAME=' "$ROOT_DIR/.env" | cut -d= -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
read -rp "Specify the app name [${DEFAULT_APP_NAME:-Laravel}]: " APP_NAME
APP_NAME=${APP_NAME:-$DEFAULT_APP_NAME}
set_env_var APP_NAME "${APP_NAME}"

# generate slug
GENERATED_APP_SLUG=$(echo "$APP_NAME" | iconv -t ascii//TRANSLIT | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g;s/^_+|_+$//g')
read -rp "Specify the app slug (used as package name in compose.json and docker image name) [${GENERATED_APP_SLUG}]: " APP_SLUG
APP_SLUG=${APP_SLUG:-$GENERATED_APP_SLUG}

ok "APP_NAME = $APP_NAME"
ok "APP_SLUG = $APP_SLUG"
# endregion

# region --- vendor ---
read -rp "Specify the vendor name [${GENERATED_APP_SLUG}]: " VENDOR
ok "VENDOR = ${VENDOR:-$GENERATED_APP_SLUG}"
# endregion

# region --- scheduler timezone ---
read -rp "Specify app timezone [UTC]\n(this won't modify the app.timezone config, that should stay UTC, but will set a SCHEDULER_TIMEZONE env var to ensure that the scheduled commands are run at the right time): " SCHEDULER_TIMEZONE
set_env_var SCHEDULER_TIMEZONE "${SCHEDULER_TIMEZONE}"
APP_CONFIG="${ROOT_DIR}/config/app.php"
sed -i "/'timezone' => 'UTC',\n/a \    'scheduler_timezone' => env('SCHEDULER_TIMEZONE', 'UTC'),\n" "$APP_CONFIG"
# endregion

# region --- PHP version ---
read -rp "Specify the php version you wish to use: " PHP_VERSION
ok "PHP version: $PHP_VERSION"

if [[ -f "$ROOT_DIR/composer.json" ]]; then
    REQUIRED_PHP=$(jq -r '.require.php // empty' "$ROOT_DIR/composer.json")

    if [[ -n "$REQUIRED_PHP" ]]; then
        # Remove leading ^ or >= or ~ constraints
        REQUIRED_PHP_CLEAN=$(echo "$REQUIRED_PHP" | sed -E 's/^[^0-9]*//;s/[^0-9.].*//')

        # Compare versions: if PHP_VERSION < REQUIRED_PHP_CLEAN, warn and exit
        if [[ "$(printf '%s\n' "$PHP_VERSION" "$REQUIRED_PHP_CLEAN" | sort -V | head -n1)" != "$REQUIRED_PHP_CLEAN" ]]; then
            error "The PHP version you specified ($PHP_VERSION) is lower than the one required in composer.json ($REQUIRED_PHP)."
        else
            ok "PHP version is compatible with composer.json requirement ($REQUIRED_PHP)."
        fi
    else
        warn "No PHP requirement found in composer.json."
    fi
else
    warn "composer.json not found in project root, skipping PHP version check."
fi
# endregion

# region --- Node version ---
read -rp "Specify the node version you wish to use: " NODE_VERSION
ok "Node version: $NODE_VERSION"
# endregion

# region --- DB setup ---
DB_CONNECTION=$(grep -E '^DB_CONNECTION=' "$ROOT_DIR/.env" | cut -d= -f2- | tr -d ' ')
if [[ -z "$DB_CONNECTION" ]]; then
    error "DB_CONNECTION not found in .env"
fi
ok "Found DB: $DB_CONNECTION"

case "$DB_CONNECTION" in
    mysql)
        PHP_PDO_EXT="pdo_mysql"
        APT_DB_PACKAGES="default-mysql-client"
        DOCKERCOMPOSE_DB=$'image: mysql:8.0\nrestart: unless-stopped\nenvironment:\n    MYSQL_DATABASE: "${DB_DATABASE}"\n    MYSQL_USER: "${DB_USERNAME}"\n    MYSQL_PASSWORD: "${DB_PASSWORD}"\n    MYSQL_ROOT_PASSWORD: "${DB_PASSWORD}"\nvolumes:\n    - mysql_data:/var/lib/mysql\nports:\n    - "${FORWARD_DB_PORT:-3306}:3306"\nnetworks:\n    - '${APP_SLUG}'\nhealthcheck:\n    test: ["CMD", "mysqladmin" ,"ping", "-h", "localhost"]\n    retries: 3\n    timeout: 5s'
        ;;
    pgsql|postgres|postgresql)
        PHP_PDO_EXT="pdo_pgsql"
        APT_DB_PACKAGES="postgresql-client"
        DOCKERCOMPOSE_DB=$'image: postgres:17\nrestart: unless-stopped\nenvironment:\n    PGPASSWORD: "${DB_PASSWORD}"\n    POSTGRES_DB: "${DB_DATABASE}"\n    POSTGRES_USER: "${DB_USERNAME}"\n    POSTGRES_PASSWORD: "${DB_PASSWORD}"\nvolumes:\n    - pgsql_data:/var/lib/postgresql/data\nports:\n    - "${FORWARD_DB_PORT:-5432}:5432"\nnetworks:\n    - '${APP_SLUG}'\nhealthcheck:\n    test: [ "CMD", "pg_isready", "-q", "-d", "${DB_DATABASE}", "-U", "${DB_USERNAME}" ]\n    retries: 3\n    timeout: 5s'
        ;;
    sqlite)
        PHP_PDO_EXT="pdo_sqlite"
        APT_DB_PACKAGES="sqlite3"
        DOCKERCOMPOSE_DB="# SQLite runs as a local file, no docker service required"
        ;;
    sqlsrv|mssql)
        PHP_PDO_EXT="pdo_sqlsrv"
        APT_DB_PACKAGES="unixodbc-dev"
        DOCKERCOMPOSE_DB=$'image: mcr.microsoft.com/mssql/server:2022-latest\nrestart: unless-stopped\nenvironment:\n    ACCEPT_EULA: "Y"\n    SA_PASSWORD: "${DB_PASSWORD}"\n    MSSQL_PID: "Express"\nvolumes:\n    - mssql_data:/var/opt/mssql\nports:\n    - "${FORWARD_DB_PORT:-1433}:1433"\nnetworks:\n    - '${APP_SLUG}'\nhealthcheck:\n    test: [ "CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "${DB_PASSWORD}", "-Q", "SELECT 1" ]\n    retries: 3\n    timeout: 5s'
        ;;
    *)
        warn "Unknown DB '$DB_CONNECTION'. You'll need to manually update docker-compose.local.yml with DB service definition."
        DOCKERCOMPOSE_DB="# Unknown database type, please configure manually"
        ;;
esac

ok "PHP PDO ext: $PHP_PDO_EXT"
ok "apt packages for DB: $APT_DB_PACKAGES"
# endregion

# region --- update package.json ---
if [[ -f "$ROOT_DIR/package.json" ]]; then
    if jq -e '.scripts.watch' "$ROOT_DIR/package.json" > /dev/null; then
        info "package.json already has a watch script, skipping."
    else
        tmpfile=$(mktemp)
        jq '.scripts.watch = "vite build --watch"' "$ROOT_DIR/package.json" > "$tmpfile" && mv "$tmpfile" "$ROOT_DIR/package.json"
        ok "Added watch script to package.json"
    fi
else
    warn "package.json not found, skipping watch script setup."
fi
# endregion

# region --- update composer.json ---
info "Updating composer.json..."
if [[ -f "$ROOT_DIR/composer.json" ]]; then
    # name 
    sed -i "s|\"name\": \".*\"|\"name\": \"${VENDOR,,}/${APP_SLUG}\"|" "$ROOT_DIR/composer.json"
    ok "composer.json name updated to ${VENDOR,,}/${APP_SLUG}"

    read -rp "Do you want to add an author to composer.json? (y/N): " ADD_AUTHOR
    ADD_AUTHOR=${ADD_AUTHOR,,}  # lowercase

    # author
    AUTHOR_JSON=""
    AUTHOR_EMAIL=""

    if [[ "$ADD_AUTHOR" == "y" ]]; then
        read -rp "Author name: " AUTHOR_NAME
        read -rp "Author email: " AUTHOR_EMAIL
        read -rp "Author website: " AUTHOR_HOMEPAGE

        AUTHOR_FIELDS=()
        [[ -n "$AUTHOR_NAME" ]] && AUTHOR_FIELDS+=("\"name\": \"$AUTHOR_NAME\"")
        [[ -n "$AUTHOR_EMAIL" ]] && AUTHOR_FIELDS+=("\"email\": \"$AUTHOR_EMAIL\"")
        [[ -n "$AUTHOR_HOMEPAGE" ]] && AUTHOR_FIELDS+=("\"homepage\": \"$AUTHOR_HOMEPAGE\"")
        AUTHOR_FIELDS+=("\"role\": \"Developer\"")

        AUTHOR_JSON="\"authors\": [ { $(IFS=,; echo "${AUTHOR_FIELDS[*]}") } ],"
    fi

    # support
    read -rp "Do you want to add a support email? (y/N): " ADD_SUPPORT
    ADD_SUPPORT=${ADD_SUPPORT,,}
    SUPPORT_JSON=""

    if [[ "$ADD_SUPPORT" == "y" ]]; then
        DEFAULT_SUPPORT_EMAIL=$AUTHOR_EMAIL
        read -rp "Support email [${DEFAULT_SUPPORT_EMAIL}]: " SUPPORT_EMAIL
        SUPPORT_EMAIL=${SUPPORT_EMAIL:-$DEFAULT_SUPPORT_EMAIL}

        if [[ -n "$SUPPORT_EMAIL" ]]; then
            SUPPORT_JSON="\"support\": { \"email\": \"$SUPPORT_EMAIL\" },"
        fi
    fi

    # build combined JSON block
    EXTRA_JSON="${AUTHOR_JSON}${SUPPORT_JSON}"

    if [[ -n "$EXTRA_JSON" ]]; then        
        sed -i "0,/\"name\":/s|\"name\":.*|&\n    ${EXTRA_JSON}|" "$ROOT_DIR/composer.json"
        ok "composer.json updated with authors and/or support"
    else
        info "No authors or support info added"
    fi

    # scripts
    TMP_COMPOSER=$(mktemp)
    if jq -e '.scripts' "$ROOT_DIR/composer.json" > /dev/null 2>&1; then
        jq '.scripts["dry-pint"] = ["./vendor/bin/pint --test"] |
            .scripts["pint"] = ["./vendor/bin/pint"]' \
            "$ROOT_DIR/composer.json" > "$TMP_COMPOSER"
    else
        jq '. + {scripts: {"dry-pint": ["./vendor/bin/pint --test"], "pint": ["./vendor/bin/pint"]}}' \
            "$ROOT_DIR/composer.json" > "$TMP_COMPOSER"
    fi
    mv "$TMP_COMPOSER" "$ROOT_DIR/composer.json"
    ok "Added pint scripts to composer.json"

else
    warn "composer.json not found in project root"
fi
# endregion

# region --- setup AppServiceProvider ---
APP_SERVICE_PROVIDER="$ROOT_DIR/app/Providers/AppServiceProvider.php"
if [[ -f "$APP_SERVICE_PROVIDER" ]]; then    
    sed -i "/public function boot(): void\n    {/a \        \Illuminate\Support\Facades\Vite::useAggressivePrefetching();\n        \Illuminate\Support\Facades\Date::use(\Carbon\CarbonImmutable::class);\n        \Illuminate\Database\Eloquent\Model::shouldBeStrict();\n        \Illuminate\Database\Eloquent\Model::unguard();\n        \Illuminate\Database\Eloquent\Model::automaticallyEagerLoadRelationships();\n        \Illuminate\Support\Facades\URL::forceHttps(\$this->app->environment(['staging','production']));\n        \Illuminate\Support\Facades\DB::prohibitDestructiveCommands(\$this->app->environment('production'));\n        \Illuminate\Support\Facades\Http::preventStrayRequests(\$this->app->runningUnitTests());" "$APP_SERVICE_PROVIDER"
    ok "Added recommended setup to AppServiceProvider boot()"
else
    warn "AppServiceProvider.php not found, skipping boot() setup."
fi
# endregion

# region --- composer dependencies ---

ROUTES_CONSOLE_FILE="$ROOT_DIR/routes/console.php"

# region filament
read -rp "Do you want to use filament? (y/N): " USE_FILAMENT
if [[ "$USE_FILAMENT" == "y" ]]; then
    composer_require filament/filament
    artisan filament:install --panels
    ok "installed filament"
fi
# endregion

# region rector
read -rp "Do you want to use rector? (y/N): " USE_RECTOR
if [[ "$USE_RECTOR" == "y" ]]; then
    composer_require_dev rector/rector driftingly/rector-laravel

    TMP_COMPOSER=$(mktemp)
    if jq -e '.scripts' "$ROOT_DIR/composer.json" > /dev/null 2>&1; then
        jq '.scripts["dry-rector"] = ["./vendor/bin/rector --dry-run"] |
            .scripts["rector"] = ["./vendor/bin/rector"]' \
            "$ROOT_DIR/composer.json" > "$TMP_COMPOSER"
    else
        jq '. + {scripts: {"dry-rector": ["./vendor/bin/rector --dry-run"], "rector": ["./vendor/bin/rector"]}}' \
            "$ROOT_DIR/composer.json" > "$TMP_COMPOSER"
    fi
    mv "$TMP_COMPOSER" "$ROOT_DIR/composer.json"
    ok "Added rector scripts to composer.json"

    ok "installed rector"
else
    rm "$RESOURCES_DIR/rector.php"
fi
# endregion

# region php stan
read -rp "Do you want to use phpstan (larastan)? (y/N): " USE_PHPSTAN
if [[ "$USE_PHPSTAN" == "y" ]]; then
    composer_run config --no-plugins allow-plugins.phpstan/extension-installer true
    composer_require_dev larastan/larastan phpstan/extension-installer phpstan/phpstan-deprecation-rules
    ok "installed php stan"
else
    rm "$RESOURCES_DIR/phpstan.neon"
fi
# endregion

# region safe php
read -rp "Do you want to use safe php (thecodingmachine/safe)? (y/N): " USE_SAFEPHP
if [[ "$USE_SAFEPHP" == "y" ]]; then
    composer_require thecodingmachine/safe 

    if [[ "$USE_PHPSTAN" == "y" ]]; then
        composer_require_dev thecodingmachine/phpstan-safe-rule 
    fi

    ok "installed safe php"
fi
# endregion

# region telescope
read -rp "Do you want to use telescope? (y/N): " USE_TELESCOPE
if [[ "$USE_TELESCOPE" == "y" ]]; then
    composer_require_dev laravel/telescope 
    artisan telescope:install

    PROVIDERS_FILE="$ROOT_DIR/bootstrap/providers.php"
    if [[ -f "$PROVIDERS_FILE" ]]; then
        sed -i '/TelescopeServiceProvider/d' "$PROVIDERS_FILE"
        ok "Removed TelescopeServiceProvider from bootstrap/providers.php"
    fi
        
    if [[ -f "$APP_SERVICE_PROVIDER" ]] && ! grep -q "TelescopeServiceProvider" "$APP_SERVICE_PROVIDER"; then
        sed -i "/public function register(): void\n    {/a \        if (\$this->app->environment('local')) {\n            \$this->app->register(\Laravel\Telescope\TelescopeServiceProvider::class);\n            \$this->app->register(TelescopeServiceProvider::class);\n        }" "$APP_SERVICE_PROVIDER"
        ok "Registered Telescope in AppServiceProvider register()"
    fi

    jq '.extra.laravel["dont-discover"] += ["laravel/telescope"]' "$ROOT_DIR/composer.json" > "$ROOT_DIR/composer.tmp.json" && mv "$ROOT_DIR/composer.tmp.json" "$ROOT_DIR/composer.json"

    set_env_var TELESCOPE_ENABLED true

    ok "installed telescope"
else
    sed -i '/telescope:prune/d' "${RESOURCES_DIR}/routes/console.php"
fi
# endregion

# region activity log
read -rp "Do you want to use activity log (spatie/laravel-activitylog)? (y/N): " USE_ACTIVITYLOG
if [[ "$USE_ACTIVITYLOG" == "y" ]]; then
    composer_require spatie/laravel-activitylog 
    artisan vendor:publish --provider="Spatie\Activitylog\ActivitylogServiceProvider" --tag="activitylog-migrations"
    artisan vendor:publish --provider="Spatie\Activitylog\ActivitylogServiceProvider" --tag="activitylog-config"

    set_env_var ACTIVITYLOG_ENABLED true

    ok "installed activity log"
else
    sed -i '/activitylog:clean/d' "${RESOURCES_DIR}/routes/console.php"
    rm "${RESOURCES_DIR}/app/models/Concerns/LogsAllDirtyChanges.php"
fi
# endregion

# region backup
read -rp "Do you want to use backup (spatie/laravel-backup)? (y/N): " USE_BACKUP
if [[ "$USE_BACKUP" == "y" ]]; then
    composer_require spatie/laravel-backup 
    artisan vendor:publish --provider="Spatie\Backup\BackupServiceProvider" --tag="backup-config"

    set_env_var BACKUP_DISK_DRIVER "local"
    set_env_var BACKUP_DISK_ROOT "laravel-backup"
    set_env_var BACKUP_NOTIFICATION_EMAIL ""

    # patch database.php for pgsql
    DB_CONFIG="$ROOT_DIR/config/database.php"
    if [[ "$DB_CONNECTION" == "pgsql" && -f "$DB_CONFIG" ]]; then
        if ! grep -q "'dump'" "$DB_CONFIG"; then
            sed -i "/'pgsql' => \[/a \ \ \ \ 'dump' => [ 'add_extra_option' => '--format=c', ]," "$DB_CONFIG"
            ok "Added pgsql dump config to database.php"
        fi
    fi

    # patch backup.php
    BACKUP_CONFIG="$ROOT_DIR/config/backup.php"
    if [[ -f "$BACKUP_CONFIG" ]]; then
        sed -i "s|'database_dump_file_timestamp_format' => .*|'database_dump_file_timestamp_format' => 'd-m-Y_h-i-s',|" "$BACKUP_CONFIG"
        if [[ "$DB_CONNECTION" == "pgsql" ]]; then
            sed -i "s|'database_dump_file_extension' => .*|'database_dump_file_extension' => 'backup',|" "$BACKUP_CONFIG"
        fi
        sed -i "s|'disks' => .*|'disks' => ['backups'],|" "$BACKUP_CONFIG"
        sed -i "s|'to' => .*|'to' => env('BACKUP_NOTIFICATION_EMAIL'),|" "$BACKUP_CONFIG"
        ok "Patched backup.php configuration"
    fi

    read -rp "Do you want to use slack notifications for backups? (y/N): " USE_SLACK_BACKUP
    if [[ "$USE_SLACK_BACKUP" == "y" ]]; then
        composer_require laravel/slack-notification-channel 
        if [[ -f "$BACKUP_CONFIG" ]]; then
            # ensure 'notifications' array includes slack
            if grep -q "'notifications'" "$BACKUP_CONFIG"; then
                sed -i "s/\['mail'\]/\['mail', 'slack'\]/" "$BACKUP_CONFIG"
            fi

            # ensure slack config block exists
            if ! grep -q "'slack'" "$BACKUP_CONFIG"; then
                sed -i "/'notifications' => \[/a \ \ \ \ \ \ 'slack' => [\n            'webhook_url' => env('BACKUP_SLACK_WEBHOOK'),\n            'channel' => env('BACKUP_SLACK_CHANNEL'),\n        ]," "$BACKUP_CONFIG"
                ok "Added slack notification config to backup.php"
            else
                # patch existing slack block
                sed -i "s|'webhook_url' => .*|'webhook_url' => env('BACKUP_SLACK_WEBHOOK'),|" "$BACKUP_CONFIG"
                sed -i "s|'channel' => .*|'channel' => env('BACKUP_SLACK_CHANNEL'),|" "$BACKUP_CONFIG"
                ok "Updated slack config in backup.php"
            fi
        fi

        set_env_var BACKUP_SLACK_WEBHOOK ""
        set_env_var BACKUP_SLACK_CHANNEL ""
    fi

    ok "installed backup"
else
   sed -i '/backup:clean/d' "${RESOURCES_DIR}/routes/console.php"
   sed -i '/backup:run/d' "${RESOURCES_DIR}/routes/console.php"
   sed -i '/backup:monitor/d' "${RESOURCES_DIR}/routes/console.php"        
fi
# endregion

# region opcahe preload
read -rp "Do you want to use opcache preload (laragear/preload)? (y/N): " USE_PRELOAD
if [[ "$USE_PRELOAD" == "y" ]]; then
    composer_require laragear/preload 
    artisan preload:stub

    set_env_var PRELOAD_ENABLE "false"
    set_env_var PHP_OPCACHE_ENABLED "0                   # 1=enabled 0=disabled"
    set_env_var PHP_OPCACHE_CLI_ENABLED "0               # 1=enabled 0=disabled"
    set_env_var PHP_OPCACHE_MEMORY_CONSUMPTION "128      # 128-512 MB"
    set_env_var PHP_OPCACHE_MAX_ACCELERATED_FILES "10000 # 10000-50000"
    set_env_var PHP_OPCACHE_MAX_WASTED_PERCENTAGE "15    # 5-10"
    set_env_var PHP_OPCACHE_VALIDATE_TIMESTAMPS "1       # 1=enabled 0=disabled"
    set_env_var PHP_OPCACHE_JIT_BUFFER_SIZE "0           # 0=disabled"
    set_env_var PHP_OPCACHE_JIT_MODE "disable"
    set_env_var PHP_OPCACHE_REVALIDATE_FREQ "0           # time in sec to check check for cached-file changes"

    DOCKERFILE_PRELOAD_SETUP=$'# Setup opcache after running composer, so there are no issues with preload.php not being available\nCOPY ./docker/configs/opcache.ini /usr/local/etc/php/conf.d/opcache.ini'

    ok "installed preload"    
else
    DOCKERFILE_PRELOAD_SETUP=''
    rm "$RESOURCES_DIR/docker/opcache.ini"
fi
# endregion

# region other dependencies
COMPOSER_DEPENDENCIES=(lorisleiva/laravel-actions staudenmeir/belongs-to-through staudenmeir/eloquent-has-many-deep)
for DEPENDENCY in "${COMPOSER_DEPENDENCIES[@]}"; do
    composer_require "${DEPENDENCY}" 
    ok "${DEPENDENCY} installed"
done
# endregion

# endregion

# region --- pint config ---
read -rp "Do you want to use custom pint config? (y/N): " USE_CUSTOM_PINT_CONFIG
if [[ "${USE_CUSTOM_PINT_CONFIG}" != "y" ]]; then
    rm "${RESOURCES_DIR}/pint.json"
fi
# endregion

# region --- phpunit config ---
read -rp "Do you want to use custom phpunit config? (y/N): " USE_CUSTOM_PHPUNIT_CONFIG
if [[ "${USE_CUSTOM_PHPUNIT_CONFIG}" == "y" ]]; then
    rm "${ROOT_DIR}/phpunit.xml"
else
    rm "${RESOURCES_DIR}/phpunit.xml"
fi
# endregion

# region --- jobs after commit ---
read -rp "Do you want to enforce jobs dispathcing after db commits? (y/N): " USE_JOBS_AFTER_COMMIT
if [[ "${USE_JOBS_AFTER_COMMIT}" != "y" ]]; then
    QUEUE_CONFIG="${ROOT_DIR}/config/queue.php"
    if [[ -f "${QUEUE_CONFIG}" ]]; then
        info "Enabling after_commit => true for all queue connections..."

        # Replace any existing after_commit line
        sed -i "s/'after_commit' *=> *false/'after_commit' => true/g" "${QUEUE_CONFIG}"

        # If after_commit is missing in a connection, add it after 'queue' => line
        grep -A 10 "'queue'" "${QUEUE_CONFIG}" | grep -q "after_commit" || \
        sed -i "/'queue' *=>/a \ \ \ \ \ \ 'after_commit' => true," "${QUEUE_CONFIG}"

        ok "All queue connections now have after_commit => true"
    else
        warn "queue.php not found, skipping after_commit patch"
    fi
fi
# endregion

# region --- placeholders replacement ---
info "Setting up the environment with the specified settings..."
TMP_DIR=$(mktemp -d)

shopt -s dotglob 
cp -r "$RESOURCES_DIR/"* "$TMP_DIR/"
shopt -u dotglob

# Find all placeholders like %VAR%
PLACEHOLDERS=$(grep -rho "%[A-Z0-9_]\+%" "$TMP_DIR" | sort -u | tr -d '%')

for VAR in $PLACEHOLDERS; do
    if [[ -n "${!VAR-}" ]]; then
        VALUE="${!VAR}"
        find "$TMP_DIR" -type f -exec sed -i "s|%$VAR%|$VALUE|g" {} +
    else
        warn "No value found for placeholder $VAR, leaving as is. This should not happen, please report issue on GitHub!"
    fi
done
ok "Settings applied"
# endregion

# region --- .env files setup ---
info "Setting up .env..."

set_env_var COMPOSE_PROJECT_NAME "$APP_SLUG"

set_env_var APP_URL "http://localhost"

set_env_var DB_HOST db

set_env_var MAIL_MAILER smtp

set_env_var MAIL_HOST mailpit

set_env_var MAIL_PORT 1025
# endregion

# region --- copy resources in project ---
info "Installing the environment..."
find "${RESOURCES_DIR}" -type d -empty -delete
rsync -av --ignore-existing "${TMP_DIR}/" "${ROOT_DIR}/" > /dev/null
echo -e "\n${GREEN}✔ Install completed with success!${RESET}"
# endregion

# region --- update/lint/format/refator/... ---
composer_run update

if [[ "${USE_RECTOR}" == "y" ]]; then
    composer_run rector
fi

composer_run pint
# endregion

# region --- cleanup ---
info "Cleanup..."
rm -rf "${TMP_DIR}"

if [ "${JQ_WAS_MISSING}" = true ]; then
    info "removing jq..."

    if command -v apt-get &> /dev/null; then
        sudo apt-get remove -y jq
    elif command -v yum &> /dev/null; then
        sudo yum remove -y jq
    elif command -v pacman &> /dev/null; then
        sudo pacman -R jq --noconfirm
    else
        warn "Unsupported package manager. Remove jq manually."        
    fi
    ok "jq removed"
fi

read -n 1 -s -r -p "Press any button to cleanup delete this script and its temp files..."
echo
rm -rf "${SCRIPT_DIR}"
# endregion