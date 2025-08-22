#!/usr/bin/env bash

# Special thanks to ChatGPT for this script

set -euo pipefail

# --- Colors ---
GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

info()  { echo -e "${CYAN}[INFO]${RESET} $*"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$SCRIPT_DIR/resources"

# --- detect DB_CONNECTION ---
info "Reading your .env..."
if [[ ! -f "$ROOT_DIR/.env" ]]; then
    error "No .env found in $ROOT_DIR"
fi

DB_CONNECTION=$(grep -E '^DB_CONNECTION=' "$ROOT_DIR/.env" | cut -d= -f2- | tr -d ' ')
if [[ -z "$DB_CONNECTION" ]]; then
    error "DB_CONNECTION not found in .env"
fi
ok "Found DB: $DB_CONNECTION"

# --- PDO ext and apt packages map ---
case "$DB_CONNECTION" in
    mysql)
        PHP_PDO_EXT="pdo_mysql"
        APT_DB_PACKAGES="default-mysql-client"
        ;;
    pgsql|postgres|postgresql)
        PHP_PDO_EXT="pdo_pgsql"
        APT_DB_PACKAGES="postgresql-client"
        ;;
    sqlite)
        PHP_PDO_EXT="pdo_sqlite"
        APT_DB_PACKAGES="sqlite3"
        ;;
    sqlsrv|mssql)
        PHP_PDO_EXT="pdo_sqlsrv"
        APT_DB_PACKAGES="unixodbc-dev"
        ;;
    *)
        warn "Unknown DB '$DB_CONNECTION'. You'll need to MANUALLY specify the PHP PDO extension and the client apt packages in the Dockerfile."
        ;;
esac
ok "PHP PDO ext: $PHP_PDO_EXT"
ok "apt packages for DB: $APT_DB_PACKAGES"

# --- PHP version ---
read -rp "Specify the php version you wish to use: " PHP_VERSION
ok "PHP version: $PHP_VERSION"

# --- app name ---
APP_NAME=$(grep -E '^APP_NAME=' "$ROOT_DIR/.env" | cut -d= -f2- | tr -d ' ' || true)
if [[ -z "$APP_NAME" ]]; then
    read -rp "Specify the app name: " APP_NAME
fi
APP_SLUG=$(echo "$APP_NAME" | iconv -t ascii//TRANSLIT | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g;s/^_+|_+$//g')
ok "APP_NAME = $APP_NAME"

# --- vendor ---
read -rp "Specify the vendor name: " VENDOR
ok "VENDOR = $VENDOR"

# --- image name ---
read -rp "Specify the name for the Docker imahe: " IMAGE_NAME
ok "IMAGE_NAME = $IMAGE_NAME"

# --- placeholders replacement ---
info "Setting up the environment with the specified settings..."
TMP_DIR=$(mktemp -d)
cp -r "$RESOURCES_DIR/"* "$TMP_DIR/"

PLACEHOLDERS=(PHP_PDO_EXT APT_DB_PACKAGES PHP_VERSION APP_NAME APP_SLUG VENDOR IMAGE_NAME)
for VAR in "${PLACEHOLDERS[@]}"; do
    VALUE="${!VAR}"
    find "$TMP_DIR" -type f -exec sed -i "s|%$VAR%|$VALUE|g" {} +
done
ok "Settings applied"

# --- composer dependencies ---
info "installing laragear/preload via composer..."
cd "$ROOT_DIR"
if command -v composer >/dev/null 2>&1; then
    composer require laragear/preload --no-interaction
    php artisan preload:stub
    ok "laragear/preload installed"
else
    warn "Composer not found! Skipped installation of laragear/preload, do it manually."
fi
cd "$SCRIPT_DIR"

# --- .env files ---
info "Setting up the .env files..."
cat "$RESOURCES_DIR/.env.example" >> "$ROOT_DIR/.env"
if [[ -f "$RESOURCES_DIR/.env.example" ]]; then
    cat "$RESOURCES_DIR/.env.example" >> "$ROOT_DIR/.env.example"
    ok "New env vars have been added to your .env.example"
else
    warn ".env.example not found"
fi
ok "New env vars have been added to your .env"
rm -f "$RESOURCES_DIR/.env.example"

# --- copy resources in project ---
info "Installing the environment..."
rsync -av --ignore-existing "$TMP_DIR/" "$ROOT_DIR/" > /dev/null
echo -e "\n${GREEN}✔ Install completed with success!${RESET}"

# --- cleanup ---
info "Cleanup..."
rm -rf "$TMP_DIR"

read -n 1 -s -r -p "Press any button to cleanup delete this script and its temp files..."
echo
rm -rf "$SCRIPT_DIR"