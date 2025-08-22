# Laravel Environment Installer

This installer aims to provide a plug-and-play Docker-based Laravel environment that works both for dev and production.

# Requirements

- A [Laravel installation](https://laravel.com/docs/installation)
- [Docker](https://www.docker.com/)

## Installation

First, after installing Laravel, setup your `.env` file.

Then run the following command in the root folder of your Laravel project.

```bash
mkdir -p laravel-environment-installer && \
curl -sL https://github.com/Talpx1/laravel-environment-installer/archive/refs/heads/main.tar.gz | \
tar xz --strip=1 -C laravel-environment-installer && \
bash ./laravel-environment-installer/install.bash
```

## What is provided
### !!! TO-DO !!!
- devcontainer with Laravel and [Filament](https://filamentphp.com/) extensions preconfigured
- [GitHub action](https://github.com/features/actions) for image build and push to [DockerHub](https://hub.docker.com/)
- Docker image with:

  - [PHP](https://www.php.net/)
  - Webserver ([apache](https://httpd.apache.org/))
  - [Supervisord](https://supervisord.org/)
  - Cron for [Laravel scheduler](https://laravel.com/docs/12.x/scheduling#running-the-scheduler)
  - Workers for [Laravel queues](https://laravel.com/docs/queues#supervisor-configuration)
  - [Logrotate](https://linux.die.net/man/8/logrotate) for log management
  - [Opcache](https://www.php.net/manual/it/book.opcache.php)
  - [Vite](https://vite.dev/) watcher to detect file changes (since no dev server will be running)
  - Healtcheck script
  - Post update script for [Watchtower](https://containrrr.dev/watchtower/) lifecycle hook (run migrations, optimize, ...)

- dockerignore
- env vars configuration
- docker-compose for dev (see below for a production version you can use on your server)

# Deployment

in your project repo, you should setup the following secrets, to allow your ci action to push on DockerHub:

- DOCKERHUB_USERNAME
- DOCKERHUB_TOKEN
- DOCKERHUB_REPO_NAME

You will also need a docker-compose on the server to serve your app.  
An example of server-side docker-compose is provided below:

```yaml
services:
  app:
    image: <your_dockerhub_user>/<your_dockerhub_repo>:<tag>
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "com.centurylinklabs.watchtower.scope=<your_app_slug>"
      - "com.centurylinklabs.watchtower.lifecycle.post-update='/post-update.sh'"
      - "com.centurylinklabs.watchtower.lifecycle.post-update-timeout=0"
    ports:
      - "${APP_PORT:-80}:80"
      - "${VITE_PORT:-5173}:${VITE_PORT:-5173}"
    volumes:
      - ".env:/var/www/html/.env"
    networks:
      - <your_app_slug>
    restart: unless-stopped
    depends_on:
      - mariadb
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
  mariadb:
    image: "mariadb:10"
    ports:
      - "${FORWARD_DB_PORT:-3306}:3306"
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: "${DB_PASSWORD}"
      MYSQL_ROOT_HOST: "%"
      MYSQL_DATABASE: "${DB_DATABASE}"
      MYSQL_USER: "${DB_USERNAME}"
      MYSQL_PASSWORD: "${DB_PASSWORD}"
      MYSQL_ALLOW_EMPTY_PASSWORD: "yes"
    volumes:
      - "<your_app_slug>_mariadb:/var/lib/mysql"
    networks:
      - <your_app_slug>
    healthcheck:
      test:
        - CMD
        - mysqladmin
        - ping
        - "-p${DB_PASSWORD}"
      retries: 3
      timeout: 5s
  meilisearch:
    image: "getmeili/meilisearch:latest"
    ports:
      - "${FORWARD_MEILISEARCH_PORT:-7700}:7700"
    restart: unless-stopped
    environment:
      MEILI_NO_ANALYTICS: "${MEILISEARCH_NO_ANALYTICS:-false}"
    volumes:
      - "<your_app_slug>_meilisearch:/meili_data"
    networks:
      - <your_app_slug>
    healthcheck:
      test:
        - CMD
        - wget
        - "--no-verbose"
        - "--spider"
        - "http://localhost:7700/health"
      retries: 3
      timeout: 5s
  watchtower:
    image: containrrr/watchtower
    labels:
      - "com.centurylinklabs.watchtower.scope=<your_app_slug>"
    restart: always
    container_name: <your_app_slug>_watchtower
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_LABEL_ENABLE=true
      - WATCHTOWER_LIFECYCLE_HOOKS=true
      - TZ=Europe/Rome
      - REPO_USER=<your_dockerhub_user>
      - REPO_PASS=<your_dockerhub_token>
    command: --interval 30 --scope <your_app_slug>
    networks:
      - <your_app_slug>
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
networks:
  <your_app_slug>:
    driver: bridge
volumes:
  <your_app_slug>_mariadb:
    driver: local
  <your_app_slug>_meilisearch:
    driver: local
```

note that a .env file must be placed in the same directory, on the server, of the given docker-compose.

# Logs

The logs will be placed in `/var/www/html/storage/logs` and will be auto-rotated.
