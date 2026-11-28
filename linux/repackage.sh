#!/usr/bin/env bash
# Repackage the official TSCM Field Linux .deb for non-Debian distributions.
#
# Builds, from the published tscm-field-linux.deb:
#   rpm       tscm-field-<version>-1.x86_64.rpm      (Fedora, RHEL, Rocky, Alma, openSUSE)
#   portable  tscm-field-<version>-linux-x86_64.tar.gz  (any x86_64 distro, no root needed)
#
# Usage:
#   ./repackage.sh [rpm|portable|all] [path/to/tscm-field-linux.deb]
#
# With no .deb path the newest release is downloaded from GitHub.
# Needs: bash, ar (binutils), tar, zstd, curl; rpmbuild (rpm-build) for the rpm target.
# The app files are not changed; only the packaging around them is.

set -euo pipefail

target="${1:-all}"
deb="${2:-}"
release_url="https://github.com/jmlasorsa/tscm-field-releases/releases/latest/download/tscm-field-linux.deb"
out_dir="${OUT_DIR:-$PWD}"

case "$target" in rpm|portable|all) ;; *)
  echo "usage: $0 [rpm|portable|all] [tscm-field-linux.deb]" >&2; exit 2 ;;
esac

need() { command -v "$1" >/dev/null || { echo "missing command: $1 ($2)" >&2; exit 1; }; }
need ar "install binutils"
need tar "install tar"
need zstd "install zstd"
[ "$target" = portable ] || need rpmbuild "install rpm-build, or run: $0 portable"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [ -z "$deb" ]; then
  need curl "install curl"
  echo "Downloading $release_url"
  curl -fL --retry 3 -o "$work/tscm-field-linux.deb" "$release_url"
  deb="$work/tscm-field-linux.deb"
fi
deb="$(realpath "$deb")"

mkdir -p "$work/deb" "$work/control" "$work/root"
(cd "$work/deb" && ar x "$deb")
tar -xf "$work"/deb/control.tar.* -C "$work/control"
tar -xf "$work"/deb/data.tar.* -C "$work/root"

field() { sed -n "s/^$1: *//p" "$work/control/control" | head -n1; }
version="$(field Version)"
arch="$(field Architecture)"
[ -n "$version" ] || { echo "could not read the version from $deb" >&2; exit 1; }
[ "$arch" = amd64 ] || { echo "unexpected .deb architecture: $arch" >&2; exit 1; }
[ -x "$work/root/opt/tscm-field/bin/TSCM Field" ] || { echo "unexpected .deb layout" >&2; exit 1; }
echo "TSCM Field $version ($arch)"

build_rpm() {
  local top="$work/rpmbuild"
  mkdir -p "$top"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  tar -C "$work/root" -cf "$top/SOURCES/tscm-field-root.tar" opt

  cat > "$top/SPECS/tscm-field.spec" <<EOF
# The payload is the prebuilt jpackage bundle from the official .deb.
%global debug_package %{nil}
%global __os_install_post %{nil}
%global _build_id_links none
%global __brp_check_rpaths %{nil}

Name:           tscm-field
Version:        $version
Release:        1
Summary:        TSCM Field Operator desktop app
License:        Proprietary
Vendor:         LaSorsa and Associates
URL:            https://github.com/jmlasorsa/tscm-field-releases
Source0:        tscm-field-root.tar
ExclusiveArch:  x86_64
AutoReqProv:    no
Requires:       xdg-utils
Requires:       libasound.so.2()(64bit)
Requires:       libfontconfig.so.1()(64bit)
Requires:       libfreetype.so.6()(64bit)
Requires:       libGL.so.1()(64bit)
Requires:       libX11.so.6()(64bit)
Requires:       libXext.so.6()(64bit)
Requires:       libXi.so.6()(64bit)
Requires:       libXrender.so.1()(64bit)
Requires:       libXtst.so.6()(64bit)
Requires:       libz.so.1()(64bit)

%description
TSCM Field Operator desktop app, repackaged unchanged from the
official tscm-field-linux.deb ($version).

%prep

%build

%install
mkdir -p %{buildroot}
tar -xf %{SOURCE0} -C %{buildroot}

%post
xdg-desktop-menu install /opt/tscm-field/lib/tscm-field-TSCM_Field.desktop >/dev/null 2>&1 || :

%preun
if [ \$1 -eq 0 ]; then
  xdg-desktop-menu uninstall /opt/tscm-field/lib/tscm-field-TSCM_Field.desktop >/dev/null 2>&1 || :
fi

%files
/opt/tscm-field
EOF

  rpmbuild --define "_topdir $top" --target x86_64 -bb "$top/SPECS/tscm-field.spec" >"$work/rpmbuild.log" 2>&1 \
    || { cat "$work/rpmbuild.log" >&2; exit 1; }
  local rpm
  rpm="$(find "$top/RPMS" -name '*.rpm' | head -n1)"
  cp "$rpm" "$out_dir/"
  echo "Built $out_dir/$(basename "$rpm")"
}

build_portable() {
  local name="tscm-field-$version-linux-x86_64"
  local dir="$work/$name"
  mkdir -p "$dir"
  cp -a "$work/root/opt/tscm-field/." "$dir/"

  cat > "$dir/tscm-field" <<'EOF'
#!/bin/sh
# Start TSCM Field from wherever this folder was unpacked.
here="$(dirname "$(readlink -f "$0")")"
exec "$here/bin/TSCM Field" "$@"
EOF

  cat > "$dir/install-menu-entry.sh" <<'EOF'
#!/bin/sh
# Add TSCM Field to your application menu (current user only, no root).
# Run it again after moving this folder; remove with --uninstall.
set -e
here="$(dirname "$(readlink -f "$0")")"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
entry="$apps/tscm-field.desktop"
if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$entry"
  echo "Removed $entry"
  exit 0
fi
mkdir -p "$apps"
cat > "$entry" <<DESKTOP
[Desktop Entry]
Name=TSCM Field
Comment=TSCM Field Operator desktop app
Exec="$here/tscm-field"
Icon=$here/lib/TSCM_Field.png
Terminal=false
Type=Application
Categories=Utility;
DESKTOP
echo "Added $entry"
EOF

  chmod 755 "$dir/tscm-field" "$dir/install-menu-entry.sh"
  tar -C "$work" -czf "$out_dir/$name.tar.gz" "$name"
  echo "Built $out_dir/$name.tar.gz"
}

case "$target" in
  rpm) build_rpm ;;
  portable) build_portable ;;
  all) build_rpm; build_portable ;;
esac
