#!/bin/sh
# My IP & Geo - public IPv4 address and its location.
# ipwho.is first; ipapi.co when it is unreachable or out of quota; Cloudflare's trace page
# as the last resort (address and country code only).
#   publicip.sh [run-id]   prints "__SRC__ <provider>" and the provider's answer, "__SRC__ none" when all fail

get() { curl -4 -fsS --max-time 8 "$1" 2>/dev/null; }

out=$(get 'https://ipwho.is/?lang=en')
if printf '%s' "$out" | grep -Eq '"success" *: *true'; then
    echo "__SRC__ ipwho.is"; printf '%s\n' "$out"; exit 0
fi
out=$(get 'https://ipapi.co/json/')
if printf '%s' "$out" | grep -Eq '"ip" *:' && ! printf '%s' "$out" | grep -Eq '"error" *: *true'; then
    echo "__SRC__ ipapi.co"; printf '%s\n' "$out"; exit 0
fi
out=$(get 'https://www.cloudflare.com/cdn-cgi/trace')
if printf '%s' "$out" | grep -q '^ip='; then
    echo "__SRC__ cloudflare"; printf '%s\n' "$out"; exit 0
fi
echo "__SRC__ none"
