#!/usr/bin/env bash
# Installs the software this desktop needs, on Fedora (dnf), Arch (pacman)
# or Debian/Ubuntu (apt), including on a minimal install with nothing but a
# TTY: audio, bluetooth, fonts, icons and a password prompt agent come with
# it, and the audio and bluetooth services are started. Run it before
# install.sh, which only places the config files.
#
# Every name is checked against the package manager before installing, so a
# name that doesn't exist on your distro is reported instead of failing the
# whole install. Where the bar (sfwbar) isn't packaged, it comes from the AUR
# on Arch (with yay/paru if installed, otherwise built with makepkg) and is
# built from source on Debian and Ubuntu.
#
# Usage: ./install-packages.sh                  # check names, then install
#        ./install-packages.sh --dry-run        # only show what would happen
#        ./install-packages.sh --yes            # don't ask to confirm
#        ./install-packages.sh --skip vlc,libreoffice
#                                               # leave these package names out
set -euo pipefail
cd "$(dirname "$0")"

dry_run=0
yes=0
skip=","
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry_run=1 ;;
    -y|--yes)  yes=1 ;;
    --skip)    skip+="${2:?--skip needs a list of package names},"; shift ;;
    --skip=*)  skip+="${1#--skip=}," ;;
    -h|--help) sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    *)         echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
  shift
done

if command -v dnf >/dev/null; then pm=dnf
elif command -v pacman >/dev/null; then pm=pacman
elif command -v apt-get >/dev/null; then pm=apt
else
  echo "No supported package manager found (dnf, pacman or apt)." >&2
  exit 1
fi

# Root can install directly; anyone else needs sudo. A minimal install often
# has only root, or a user without sudo.
if [ "$(id -u)" -eq 0 ]; then
  sudo=""
  as_root=1
else
  sudo=sudo
  as_root=0
  if [ $dry_run -eq 0 ] && ! command -v sudo >/dev/null; then
    cat >&2 <<EOF
sudo isn't installed, so this script can't install packages as $(id -un).
Either run it as root (then run install.sh as $(id -un)), or as root set up
sudo for $(id -un) and log in again:
  Arch:          pacman -S sudo && usermod -aG wheel $(id -un) &&
                 echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
  Debian/Ubuntu: apt-get install sudo && usermod -aG sudo $(id -un)
  Fedora:        usermod -aG wheel $(id -un)
EOF
    exit 1
  fi
fi

aur_helper=""
if [ "$pm" = pacman ]; then
  for h in yay paru; do command -v "$h" >/dev/null && { aur_helper=$h; break; }; done
fi

# sfwbar version to build from source where it isn't packaged. The config in
# this repo was written against it (see sfwbar.config).
sfwbar_tag=v1.0_beta16.1

# What it's for | dnf name | pacman name | apt name
# "a/b" means try a, then b. "-" means skip on that distro.
packages='
compositor         | labwc                    | labwc              | labwc
login screen entry | labwc-session            | -                  | -
graphics drivers   | mesa-dri-drivers         | mesa               | libgl1-mesa-dri
bar                | sfwbar                   | sfwbar             | sfwbar
launcher           | fuzzel                   | fuzzel             | fuzzel
terminal           | alacritty                | alacritty          | alacritty
wallpaper          | swaybg                   | swaybg             | swaybg
lock screen        | gtklock                  | gtklock            | gtklock
screenshots        | grim                     | grim               | grim
screenshot region  | slurp                    | slurp              | slurp
screenshot to clip | wl-clipboard             | wl-clipboard       | wl-clipboard
display scaling    | wlr-randr                | wlr-randr          | wlr-randr
display settings   | wdisplays                | wdisplays          | wdisplays
brightness keys    | brightnessctl            | brightnessctl      | brightnessctl
X11 app support    | xorg-x11-server-Xwayland | xorg-xwayland      | xwayland
session bus        | -                        | -                  | dbus-user-session
password prompts   | mate-polkit              | mate-polkit        | mate-polkit
audio server       | pipewire                 | pipewire           | pipewire
audio session      | wireplumber              | wireplumber        | wireplumber
audio for apps     | pipewire-pulseaudio      | pipewire-pulse     | pipewire-pulse
bluetooth service  | bluez                    | bluez              | bluez
interface font     | dejavu-sans-fonts        | ttf-dejavu         | fonts-dejavu-core
terminal font      | jetbrains-mono-fonts-all | ttf-jetbrains-mono | fonts-jetbrains-mono
icons              | adwaita-icon-theme       | adwaita-icon-theme | adwaita-icon-theme
icons (red)        | gnome-colors-icon-theme  | gnome-colors-icon-theme | gnome-wine-icon-theme
browser            | firefox                  | firefox            | firefox/firefox-esr
browser (Spotify)  | chromium                 | chromium           | chromium/chromium-browser
files              | nautilus                 | nautilus           | nautilus
text editor        | mousepad                 | mousepad           | mousepad
calculator         | galculator               | galculator         | galculator
volume control     | pavucontrol              | pavucontrol        | pavucontrol
bluetooth          | blueman                  | blueman            | blueman
office             | libreoffice              | libreoffice-fresh  | libreoffice
media player       | vlc                      | vlc                | vlc
clock              | gnome-clocks             | gnome-clocks       | gnome-clocks
system info        | fastfetch                | fastfetch          | fastfetch
notifications      | mako                     | mako               | mako-notifier/mako
GTK4 theme script  | python3-gobject          | python-gobject     | python3-gi
dark mode for GTK4 | xdg-desktop-portal-gtk   | xdg-desktop-portal-gtk | xdg-desktop-portal-gtk
'

# What building sfwbar from source needs (only installed if it's built).
sfwbar_build_deps_dnf="gcc meson ninja-build pkgconf-pkg-config curl tar
  gtk3-devel gtk-layer-shell-devel json-c-devel wayland-devel wayland-protocols-devel"
sfwbar_build_deps_apt="build-essential meson ninja-build pkg-config curl ca-certificates
  libgtk-3-dev libgtk-layer-shell-dev libjson-c-dev libwayland-dev wayland-protocols"

case $pm in dnf) col=2 ;; pacman) col=3 ;; apt) col=4 ;; esac
# --yes: the package manager's own "don't ask" flag.
confirm=""
if [ $yes -eq 1 ]; then
  case $pm in dnf|apt) confirm=-y ;; pacman) confirm=--noconfirm ;; esac
fi

available() {
  case $pm in
    dnf)    dnf -q info "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
    # Must have an installable version: apt-cache show also succeeds for a
    # name that is only referenced (Debian's "firefox" is firefox-esr).
    apt)    c=$(apt-cache policy "$1" 2>/dev/null | sed -n 's/^ *Candidate: //p')
            [ -n "$c" ] && [ "$c" != "(none)" ] ;;
  esac
}
in_aur() {
  if [ -n "$aur_helper" ]; then
    "$aur_helper" -Si "$1" >/dev/null 2>&1
  else
    curl -fsS "https://aur.archlinux.org/rpc/v5/info?arg[]=$1" 2>/dev/null | grep -q '"resultcount":1'
  fi
}

echo "Package manager: $pm${aur_helper:+ (AUR via $aur_helper)}"
[ $as_root -eq 1 ] && echo "Running as root: afterwards, run install.sh as your normal user."

# Refresh the package lists first: on a fresh install they can be missing,
# which would make every name look unavailable.
if [ $dry_run -eq 0 ]; then
  echo
  echo "Refreshing package lists..."
  case $pm in
    apt)    $sudo apt-get update -qq ;;
    pacman) $sudo pacman -Sy ;;
    dnf)    $sudo dnf -q makecache ;;
  esac
fi

repo_pkgs=()
aur_pkgs=()
src_pkgs=()
missing=()
report=()   # one "status|what|name" line per package, printed after checking

rows=()
while IFS= read -r line; do
  [[ $line == *'|'* ]] && rows+=("$line")
done <<< "$packages"

# On a terminal, show a single progress line that updates in place; in a log
# or pipe, just say what's happening.
tty=0; [ -t 1 ] && tty=1
echo
echo "Checking ${#rows[@]} package names (the first check can be slow while"
echo "the package lists are loaded)..."

i=0
for line in "${rows[@]}"; do
  i=$((i + 1))
  IFS='|' read -r -a row <<< "$line"
  what=$(echo "${row[0]}" | xargs)
  names=$(echo "${row[$((col - 1))]}" | xargs)
  [ "$names" = "-" ] && continue
  IFS=/ read -r -a candidates <<< "$names"
  skipped=0
  for name in "${candidates[@]}"; do
    [[ $skip == *",$name,"* ]] && skipped=1
  done
  if [ $skipped -eq 1 ]; then
    report+=("skip|$what|$names (--skip)")
    continue
  fi
  [ $tty -eq 1 ] && printf '\r\033[K  %d/%d  %s' "$i" "${#rows[@]}" "${names%%/*}"
  found=""
  for name in "${candidates[@]}"; do
    if available "$name"; then found=$name; repo_pkgs+=("$name"); report+=("ok|$what|$name"); break; fi
  done
  if [ -z "$found" ] && [ "$pm" = pacman ]; then
    for name in "${candidates[@]}"; do
      if in_aur "$name"; then
        if [ $as_root -eq 1 ] && [ -z "$aur_helper" ]; then
          break   # makepkg refuses to run as root; reported as missing below
        fi
        found=$name; aur_pkgs+=("$name"); report+=("AUR|$what|$name"); break
      fi
    done
  fi
  if [ -z "$found" ] && [ "$names" = sfwbar ] && [ "$pm" != pacman ]; then
    found=sfwbar; src_pkgs+=(sfwbar); report+=("src|$what|sfwbar $sfwbar_tag (built from source)")
  fi
  if [ -z "$found" ]; then
    missing+=("$what ($names)")
    report+=("--|$what|$names (not found)")
  fi
done
[ $tty -eq 1 ] && printf '\r\033[K'

echo
for r in "${report[@]}"; do
  IFS='|' read -r status what name <<< "$r"
  printf '  %-4s %-20s %s\n' "$status" "$what" "$name"
done
echo
summary="${#repo_pkgs[@]} from the repos"
[ ${#aur_pkgs[@]} -gt 0 ] && summary+=", ${#aur_pkgs[@]} from the AUR"
[ ${#src_pkgs[@]} -gt 0 ] && summary+=", ${#src_pkgs[@]} built from source"
[ ${#missing[@]} -gt 0 ] && summary+=", ${#missing[@]} not found"
echo "$summary."
if [ ${#missing[@]} -gt 0 ]; then
  echo "Install the ones marked -- yourself."
  if [ "$pm" = pacman ] && [ $as_root -eq 1 ]; then
    echo "(AUR packages can't be built as root; re-run this as your normal user.)"
  fi
fi

if [ $dry_run -eq 1 ]; then
  [ "$pm" = pacman ] && [ -z "$(ls -A /var/lib/pacman/sync 2>/dev/null)" ] &&
    echo "(pacman has no package lists yet, so everything shows as not found; a real run refreshes them first.)"
  echo "Dry run: nothing installed."
  exit 0
fi

echo
echo "Installing${confirm:+ (not asking to confirm)}..."
if [ ${#repo_pkgs[@]} -gt 0 ]; then
  case $pm in
    dnf)    $sudo dnf install $confirm "${repo_pkgs[@]}" ;;
    # -Su as well: installing without upgrading after -Sy leaves a partial
    # upgrade, which Arch doesn't support.
    pacman) $sudo pacman -Su --needed $confirm "${repo_pkgs[@]}" ;;
    apt)    $sudo apt-get install $confirm "${repo_pkgs[@]}" ;;
  esac
fi

build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/labwc-dotfiles"

for p in "${aur_pkgs[@]}"; do
  echo
  if [ -n "$aur_helper" ]; then
    echo "Installing $p from the AUR with $aur_helper..."
    "$aur_helper" -S --needed $confirm "$p"
  else
    echo "Building $p from the AUR with makepkg..."
    $sudo pacman -S --needed $confirm base-devel git
    rm -rf "$build_dir/aur/$p"
    git clone -q "https://aur.archlinux.org/$p.git" "$build_dir/aur/$p"
    # AUR packages often only list x86_64; they build fine elsewhere.
    ignorearch=""; [ "$(uname -m)" != x86_64 ] && ignorearch=--ignorearch
    (cd "$build_dir/aur/$p" && makepkg -si --needed $confirm $ignorearch)
  fi
done

if [ ${#src_pkgs[@]} -gt 0 ]; then
  echo
  echo "Building sfwbar $sfwbar_tag from source (it isn't packaged here)..."
  case $pm in
    dnf) $sudo dnf install $confirm $sfwbar_build_deps_dnf ;;
    apt) $sudo apt-get install $confirm $sfwbar_build_deps_apt ;;
  esac
  src="$build_dir/sfwbar-$sfwbar_tag"
  rm -rf "$src" && mkdir -p "$src"
  curl -fsSL "https://github.com/LBCrion/sfwbar/archive/refs/tags/$sfwbar_tag.tar.gz" |
    tar -xz -C "$src" --strip-components=1
  # Only the core: the config uses no optional modules (see sfwbar.config).
  meson setup "$src/build" "$src" --prefix=/usr/local --buildtype=release \
    -Dauto_features=disabled
  ninja -C "$src/build"
  $sudo ninja -C "$src/build" install
  $sudo ldconfig
  echo "sfwbar installed to /usr/local."
fi

echo
echo "Starting services..."
if [ -d /run/systemd/system ]; then
  if systemctl cat bluetooth.service >/dev/null 2>&1; then
    $sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 &&
      echo "  bluetooth      enabled" || echo "  bluetooth      couldn't enable bluetooth.service"
  fi
  # PipeWire runs per user. Most distros enable it for everyone already;
  # this makes sure, and starts it now.
  if [ $as_root -eq 0 ]; then
    if systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1; then
      echo "  audio          enabled (PipeWire)"
    else
      echo "  audio          couldn't enable the PipeWire user services; they may"
      echo "                 still start at login (check: systemctl --user status pipewire)"
    fi
  else
    echo "  audio          not set up as root; PipeWire starts when your user logs in"
  fi
else
  echo "  systemd isn't running, so nothing was enabled. Enable bluetooth.service,"
  echo "  and pipewire, pipewire-pulse and wireplumber for your user, yourself."
fi

echo
echo "Done. Next: ./install.sh$([ $as_root -eq 1 ] && echo " (as your normal user)")"
