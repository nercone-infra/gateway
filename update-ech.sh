#!/usr/bin/env bash
set -e

PUBLIC_NAME="${1:-ech.nerc1.dev}"
MAX_NAME_LEN="${2:-40}"

cd "$(dirname "$0")"

ECH_DIR="$(pwd)/data/ech"
PEM_FILE="${ECH_DIR}/${PUBLIC_NAME}.pem"

echo "Outer SNI: ${PUBLIC_NAME}"
echo "Padding: ${MAX_NAME_LEN}"

echo
echo "> Generate ECH Key"

mkdir -p "${ECH_DIR}"
docker compose run --rm --no-deps -v "${ECH_DIR}:/ech" proxy sh -c "openssl ech -public_name '${PUBLIC_NAME}' -max_name_len '${MAX_NAME_LEN}' -out '/ech/${PUBLIC_NAME}.pem' && chmod 600 '/ech/${PUBLIC_NAME}.pem'"
echo "ECH key generated: ${PEM_FILE}"

echo
echo "> Generate HTTPS Record Examples"

ECHCONFIG=$(sudo awk '/-----BEGIN ECHCONFIG-----/{found=1; next} /-----END ECHCONFIG-----/{found=0} found' "${PEM_FILE}" | tr -d '\n')
for DOMAIN in \
    "nercone.dev." \
    "diamondgotcat.net." \
    "d-g-c.net." \
    "nerc1.dev."
do
    printf "%-28s HTTPS 1 . ech=%s\n" "${DOMAIN}" "${ECHCONFIG}"
done

echo
echo "> Reload Nginx"

docker compose exec proxy /usr/local/bin/entrypoint.sh reload
