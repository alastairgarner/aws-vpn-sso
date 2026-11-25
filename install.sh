#!/usr/bin/env bash
# Install onto this host. Run ./openvpn/build.sh first.
set -euo pipefail
cd "$(dirname "$0")"
[[ -x dist/openvpn-aws ]] || { echo "run ./openvpn/build.sh first" >&2; exit 1; }

sudo install -Dm0755 dist/openvpn-aws     /usr/local/libexec/aws-vpn-sso/openvpn-aws
sudo install -Dm0755 libexec/dns-updown   /usr/local/libexec/aws-vpn-sso/dns-updown
sudo install -Dm0755 bin/aws-vpn-sso      /usr/local/bin/aws-vpn-sso
sudo install -Dm0644 systemd/aws-vpn-sso.service /etc/systemd/system/aws-vpn-sso.service
sudo install -dm0700 /etc/aws-vpn-sso
sudo test -e /etc/aws-vpn-sso/config.env || sudo install -m0600 config.env.example /etc/aws-vpn-sso/config.env
sudo restorecon -R /usr/local/libexec/aws-vpn-sso /usr/local/bin/aws-vpn-sso /etc/aws-vpn-sso 2>/dev/null || true
sudo systemctl daemon-reload

if sudo test -e /etc/aws-vpn-sso/profile.ovpn; then
  sudo systemctl enable --now aws-vpn-sso.service
  sudo systemctl restart aws-vpn-sso.service
  echo "running: journalctl -u aws-vpn-sso -f"
else
  echo "next: sudo install -m0600 <work>.ovpn /etc/aws-vpn-sso/profile.ovpn && sudo systemctl enable --now aws-vpn-sso"
fi
