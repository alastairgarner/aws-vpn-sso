#!/usr/bin/env bash
# Drive the controller against tests/fake-openvpn. No root, no network.
set -euo pipefail
cd "$(dirname "$0")/.."
rt=$(mktemp -d)
trap 'kill $pid 2>/dev/null; rm -rf "$rt"' EXIT

RUNTIME_DIRECTORY=$rt AWS_VPN_PROFILE=tests/profile.ovpn AWS_VPN_OPENVPN=tests/fake-openvpn \
  AWS_VPN_SERVER_IP=192.0.2.10 AWS_VPN_DNS_DOMAINS="corp.example" \
  python3 -I bin/aws-vpn-sso 2>"$rt/log" & pid=$!
for _ in $(seq 50); do curl -s localhost:35001/status >/dev/null && break; sleep 0.1; done

check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; cat "$rt/log"; exit 1; fi; }
st() { curl -s localhost:35001/status | python3 -c 'import sys,json;print(json.load(sys.stdin)["state"])'; }

check "idle at start"            '[ "$(st)" = idle ]'
loc=$(curl -s -o /dev/null -w '%{redirect_url}' localhost:35001/)
check "GET / redirects to IdP"   '[ "$loc" = "https://idp.example/saml?SAMLRequest=xyz" ]'
check "awaiting_saml"            '[ "$(st)" = awaiting_saml ]'
check "conf stripped"            '! grep -qE "^(auth-federate|auth-user-pass|remote-random-hostname|auth-retry interact|remote cvpn)" $rt/vpn.conf'
check "inline <ca> kept"         'grep -q "^remote not-a-directive" $rt/vpn.conf'
check "redirect-gateway ignored" 'grep -q "pull-filter ignore \"redirect-gateway\"" $rt/vpn.conf'
check "phase1 creds removed"     '! ls $rt | grep -q phase1'
code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Origin: https://idp.example' \
  --data-urlencode 'SAMLResponse=FAKE-SAML+/=' localhost:35001/)
check "POST SAMLResponse -> 303" '[ "$code" = 303 ]'
sleep 0.5
check "connected"                '[ "$(st)" = connected ]'
check "same IP in phase 2"       'grep -q "remote 192.0.2.10 443" $rt/log'
check "phase2 creds removed"     '! ls $rt | grep -q phase2'
check "replayed SAML rejected"   '[ "$(curl -s -o /dev/null -w "%{http_code}" --data SAMLResponse=x localhost:35001/)" = 409 ]'
check "cross-origin disconnect blocked" \
  '[ "$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Origin: https://evil.example" localhost:35001/disconnect)" = 403 ]'
curl -s -o /dev/null -X POST localhost:35001/disconnect
sleep 0.5
check "idle after disconnect"    '[ "$(st)" = idle ]'
echo "all passed"
