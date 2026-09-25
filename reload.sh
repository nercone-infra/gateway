#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

sudo git pull

docker compose exec proxy /usr/local/bin/entrypoint.sh reload

docker compose exec onion /usr/local/bin/entrypoint.sh reload
