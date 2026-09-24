#!/bin/sh
set -u

INTERFACE=ruconet

prefix() {
    ip -4 route show dev "${INTERFACE}" proto kernel scope link 2> /dev/null | awk '{ print $1; exit }'
}

digest() {
    { prefix; ip -4 route show default; } 2> /dev/null | sha256sum
}

apply() {
    PREFIX=$(prefix)
    if [ -z "${PREFIX}" ]; then
        echo "egress: no ${INTERFACE} interface" >&2
        return 1
    fi
    EXTERNAL=$(ip -4 route show default | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
    if [ -z "${EXTERNAL}" ]; then
        echo "egress: no default route" >&2
        return 1
    fi
    nft -f - <<RULES || return 1
table inet egress
delete table inet egress
table inet egress {
    chain clamp {
        type filter hook forward priority mangle; policy accept;
        tcp flags & (syn | rst) == syn tcp option maxseg size set rt mtu
    }

    chain forward {
        type filter hook forward priority filter; policy drop;
        ct state established,related accept
        ct state invalid drop
        iifname "${INTERFACE}" oifname "${EXTERNAL}" ip saddr ${PREFIX} accept
    }

    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        oifname "${EXTERNAL}" ip saddr ${PREFIX} masquerade
    }
}
RULES
    echo "egress: ${PREFIX} via ${EXTERNAL}" >&2
}

trap 'exit 0' TERM INT

APPLIED=
while true; do
    DIGEST=$(digest)
    if [ "${DIGEST}" != "${APPLIED}" ] || ! nft list table inet egress > /dev/null 2>&1; then
        apply && APPLIED="${DIGEST}"
    fi
    sleep 30 & wait $!
done
