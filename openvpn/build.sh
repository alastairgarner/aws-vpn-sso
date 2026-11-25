#!/usr/bin/env bash
# Build AWS-patched OpenVPN from Fedora's own source RPM inside a throwaway
# container matching the host release. Output: ./dist/openvpn-aws
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
fedora="$(rpm -E %fedora)"
ver="${OPENVPN_VERSION:-2.7.9}"
patch="openvpn-${ver}-aws.patch"
out="$here/../dist"

[[ -f "$here/$patch" ]] || { echo "no $patch for openvpn $ver" >&2; exit 1; }
mkdir -p "$out"

podman run --rm \
  -v "$here/$patch:/src/aws.patch:ro,Z" \
  -v "$out:/out:Z" \
  -e VER="$ver" \
  "registry.fedoraproject.org/fedora:${fedora}" bash -euo pipefail -c '
    dnf -q -y install rpm-build "dnf-command(builddep)" "dnf-command(download)" >/dev/null
    cd /tmp
    dnf -q -y download --source "openvpn-${VER}" >/dev/null
    dnf -q -y builddep ./openvpn-*.src.rpm >/dev/null
    rpm -i ./openvpn-*.src.rpm
    spec=~/rpmbuild/SPECS/openvpn.spec
    cp /src/aws.patch ~/rpmbuild/SOURCES/
    # Append as last patch; %autosetup -p1 applies it after Fedora patches.
    sed -i "0,/^Patch50:/s//Patch900:          aws.patch\n&/" "$spec"
    rpmbuild -bc --nocheck --without pkcs11 "$spec" >/tmp/build.log 2>&1 || { tail -50 /tmp/build.log; exit 1; }
    bin=$(echo ~/rpmbuild/BUILD/openvpn-*/openvpn-*/src/openvpn/openvpn ~/rpmbuild/BUILD/openvpn-*/src/openvpn/openvpn 2>/dev/null | tr " " "\n" | grep -m1 -v "\*")
    "$bin" --version | head -1
    install -m 0755 "$bin" /out/openvpn-aws
  '
echo "built: $out/openvpn-aws"
