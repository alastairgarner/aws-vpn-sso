# aws-vpn-sso

Headless AWS Client VPN (SAML/SSO) for the home server. You sign in from the laptop browser, and an SSH forward of `localhost:35001` carries the response back to the server.

Unofficial: AWS supports SAML only with its own client. The protocol is the one documented by [samm-git/aws-vpn-client](https://github.com/aws-vpn-client/aws-vpn-client) (MIT), and our patch is ported to OpenVPN 2.7.

## Pieces

| Path | What |
|---|---|
| `openvpn/openvpn-2.7.9-aws.patch` | Bigger buffers plus u32 length prefixes in key-method-2, for the CRV1 SAML password |
| `openvpn/build.sh` | Rebuilds Fedora's own openvpn SRPM with the patch in a throwaway `fedora:<host>` podman container, producing `dist/openvpn-aws` (built without PKCS#11, so it needs no extra host packages) |
| `bin/aws-vpn-sso` | Controller (Python stdlib) listening on `127.0.0.1:35001`. Handles both phases of the SAML login and supervises openvpn |
| `libexec/dns-updown` | Split DNS through systemd-resolved. Never sets a default DNS route |
| `systemd/aws-vpn-sso.service` | Runs the controller as root with `CAP_NET_ADMIN` only |
| `laptop/homevpn.sh` | Laptop `homevpn` function: a 2-min SSH forward, then opens the page |

## Install (server)

```sh
./openvpn/build.sh
./install.sh
sudo install -m0600 ~/work.ovpn /etc/aws-vpn-sso/profile.ovpn
sudoedit /etc/aws-vpn-sso/config.env      # set AWS_VPN_DNS_DOMAINS
sudo systemctl enable --now aws-vpn-sso
journalctl -u aws-vpn-sso -f
```

## Use (laptop)

```sh
source laptop/homevpn.sh   # in ~/.zshrc
homevpn                    # sign in via SSO; page shows "connected"
```

When connected, `http://localhost:35001` (with the forward open) shows the status page and a Disconnect button. You also need to sign in again after a reboot or a tunnel drop, because SAML assertions are single-use.

## Behaviour

- **Routing:** a pushed `redirect-gateway` is ignored by default, so only the subnets work pushes go through the VPN, and Tailscale and LAN are untouched. Set `AWS_VPN_ALLOW_FULL_TUNNEL=yes` to send all traffic through work.
- **DNS:** work DNS answers only for `AWS_VPN_DNS_DOMAINS` and any pushed domains. Often none are needed: internal ALBs and Atlas PrivateLink hostnames usually resolve to private IPs in public DNS already, and the pushed routes carry them.
- **Sign-in again** after: the endpoint's max session duration (AWS default 24h; IT can set 8/10/12/24h), a server reboot or service restart, or more than 20s without contact with the server (`ping-restart 20`). SAML assertions are single-use, so there is no silent reconnect.
- **Security:** the `:35001` endpoint is loopback only. It rejects a SAML POST unless a login is pending, and rejects a cross-origin disconnect.

## Test

`tests/e2e.sh` runs the controller against a stub openvpn. It needs no root and no network.

## Licence

The scripts are MIT. `openvpn/*.patch` modifies OpenVPN and is GPL-2.0, like OpenVPN itself. The protocol work comes from [samm-git/aws-vpn-client](https://github.com/samm-git/aws-vpn-client) (MIT).

## Upgrading openvpn

When Fedora bumps openvpn, add `openvpn/openvpn-<ver>-aws.patch` and run `OPENVPN_VERSION=<ver> ./openvpn/build.sh`.
