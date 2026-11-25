# Source from ~/.zshrc:  source ~/path/to/homevpn.sh
# Opens a 2-minute SSH forward of :35001 to the home server, then the login page.
# Nothing stays bound to :35001, so the laptop's own AWS VPN Client keeps working.
HOMEVPN_HOST="${HOMEVPN_HOST:-homeserver}"

homevpn() {
  ssh -f -o ExitOnForwardFailure=yes -L 35001:localhost:35001 "$HOMEVPN_HOST" sleep 120 \
    && open "http://localhost:35001/${1:-}"
}
# homevpn          -> connect (or status if already up)
# homevpn connect  -> force a fresh login
