#!/bin/sh
set -u
set -f

INTERFACE=ruconet
DENY="${EGRESS_DENY:-0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4}"

deny() {
    printf '%s\n' ${DENY} | paste -s -d , -
}

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
        iifname "${INTERFACE}" ip daddr { $(deny) } reject with icmpx type admin-prohibited
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
