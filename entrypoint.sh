#! /usr/bin/env bash
set -e

/uwsgi-nginx-entrypoint.sh

mkdir -p /data/cache

# Get the listen port for Nginx, default to 80
USE_LISTEN_PORT=${LISTEN_PORT:-80}
USE_CACHE_VALID_200=${CACHE_VALID_200:-'600s'}

if [ -f /app/nginx.conf ]; then
    cp /app/nginx.conf /etc/nginx/nginx.conf
else
    # https://stackoverflow.com/questions/46966466/cant-get-nginx-to-cache-uwsgi-result
    content_server='uwsgi_cache_path /data/cache levels=1:2 keys_zone=my_cache:10m max_size=20g inactive=120m use_temp_path=off;'
    content_server=$content_server'server {\n'
    content_server=$content_server"    listen ${USE_LISTEN_PORT};\n"
    content_server=$content_server'    location / {\n'
    content_server=$content_server'        try_files $uri @app;\n'
    content_server=$content_server'    }\n'
    content_server=$content_server'    location @app {\n'
    content_server=$content_server'        include uwsgi_params;\n'
    content_server=$content_server'        uwsgi_pass unix:///tmp/uwsgi.sock;\n'
    content_server=$content_server'        uwsgi_buffer_size 256k;\n'
    content_server=$content_server'        uwsgi_buffers 32 512k;\n'
    content_server=$content_server'        uwsgi_busy_buffers_size 512k;\n'
    content_server=$content_server'        uwsgi_cache my_cache;\n'
    content_server=$content_server'        uwsgi_cache_bypass 0;\n'
    content_server=$content_server'        uwsgi_cache_use_stale error timeout updating http_500;\n'
    content_server=$content_server"        uwsgi_cache_valid 200 ${USE_CACHE_VALID_200};\n"
    content_server=$content_server'        uwsgi_cache_key $scheme$host$request_uri;\n'
    content_server=$content_server'    }\n'
    content_server=$content_server'}\n'
    # Save generated server /etc/nginx/conf.d/nginx.conf
    printf "$content_server" > /etc/nginx/conf.d/nginx.conf
fi

exec "$@"
