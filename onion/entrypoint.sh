#!/bin/sh
set -e

main() {
    mkdir -p /var/lib/tor
    chown -R debian-tor:debian-tor /var/lib/tor
    chmod 700 /var/lib/tor

    tor --verify-config -f /etc/tor.d/torrc

    exec tor -f /etc/tor.d/torrc
}

reload() {
    tor --verify-config -f /etc/tor.d/torrc
    kill -HUP 1
}

case "${1:-main}" in
    main)   main ;;
    reload) reload ;;
    *)      echo "Usage: $0 [main|reload]" >&2; exit 2 ;;
esac
