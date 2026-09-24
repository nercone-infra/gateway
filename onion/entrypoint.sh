#!/bin/sh
set -e

mkdir -p /var/lib/tor
chown -R debian-tor:debian-tor /var/lib/tor
chmod 700 /var/lib/tor

tor --verify-config -f /etc/tor.d/torrc

exec tor -f /etc/tor.d/torrc
