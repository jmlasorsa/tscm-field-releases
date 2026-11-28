# TSCM Field on Fedora and other non-Debian Linux

The official Linux download is a `.deb`, which only Debian, Ubuntu and their
derivatives can install. This folder turns that same `.deb` into:

- an **`.rpm`** for Fedora, RHEL, Rocky, AlmaLinux and openSUSE
- a **portable `.tar.gz`** that runs on any x86_64 Linux without installing anything

The app inside is not changed. `repackage.sh` only rewraps the files from the
published `.deb`.

> **Source code:** the app's source code is private, so it cannot be built from
> source here. "Building" in this folder means repackaging the official release.

**Prebuilt files:** if the [latest release](https://github.com/jmlasorsa/tscm-field-releases/releases/latest)
lists `tscm-field-linux.rpm` or `tscm-field-linux-x86_64.tar.gz`, download that
file and skip to [Install](#install-the-rpm) or [Portable](#use-the-portable-targz).

## Requirements

- An **x86_64 (Intel/AMD) computer.** The app ships its own Java runtime and
  Bluetooth helper, and both are built for x86_64 only. ARM computers
  (Raspberry Pi, Ampere, Snapdragon laptops) are not supported.
- These tools:

  | Distro | Command |
  |---|---|
  | Fedora / RHEL / Rocky / Alma | `sudo dnf install binutils zstd curl rpm-build` |
  | openSUSE | `sudo zypper install binutils zstd curl rpm-build` |
  | Arch / Manjaro (portable only) | `sudo pacman -S binutils zstd curl` |

  `rpm-build` is only needed for the `.rpm`.

## Build

```sh
git clone https://github.com/jmlasorsa/tscm-field-releases.git
cd tscm-field-releases/linux
./repackage.sh all          # both the .rpm and the portable .tar.gz
./repackage.sh rpm          # only the .rpm
./repackage.sh portable     # only the .tar.gz
```

The script downloads the newest `tscm-field-linux.deb` from the releases page.
To use a `.deb` you have already downloaded, pass its path:

```sh
./repackage.sh rpm ~/Downloads/tscm-field-linux.deb
```

The output files go into the current folder. Set `OUT_DIR=/some/folder` to put
them somewhere else.

## Install the .rpm

```sh
sudo dnf install ./tscm-field-*.x86_64.rpm      # Fedora / RHEL / Rocky / Alma
sudo zypper install ./tscm-field-*.x86_64.rpm   # openSUSE
```

The app installs to `/opt/tscm-field` and appears in the application menu as
**TSCM Field**. To remove it: `sudo dnf remove tscm-field`.

## Use the portable .tar.gz

```sh
tar xzf tscm-field-*-linux-x86_64.tar.gz
cd tscm-field-*-linux-x86_64
./tscm-field                      # run it
./install-menu-entry.sh           # optional: add it to your app menu (no root)
./install-menu-entry.sh --uninstall
```

You can keep the folder anywhere, such as your home folder or a USB drive. If you
move it, run `./install-menu-entry.sh` again.

## Updates

The app's built-in updater downloads the `.deb`, which Fedora and other
non-Debian systems cannot install. To update:

1. Run `./repackage.sh` again. It always fetches the newest release.
2. Install the new `.rpm` with the same `dnf install` command. For the
   portable version, unpack the new `.tar.gz` and run `./install-menu-entry.sh`
   from it.

## Troubleshooting

- **`missing command: ...`**: install the package that the message names.
- **The app does not start on a server or minimal install**: it needs a graphical
  desktop (X11, or Wayland with XWayland) and the usual desktop libraries
  (ALSA, fontconfig, freetype, Mesa/libGL, libX11, libXext, libXi, libXrender,
  libXtst). The `.rpm` declares these, so `dnf` installs them automatically.
- **Serial or USB devices are not detected**: add yourself to the `dialout`
  group (`sudo usermod -aG dialout $USER`), then log out and back in.

## For the maintainers

The desktop app is built with Compose Multiplatform. That build can produce an
`.rpm` directly (`targetFormats(TargetFormat.Deb, TargetFormat.Rpm, ...)` in
`compose.desktop.application.nativeDistributions`). That would remove the need
for this script. Until then, `.github/workflows/linux-repackage.yml` runs
`repackage.sh` on each published release and attaches the `.rpm` and
`.tar.gz` to it.
