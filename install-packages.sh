#!/usr/bin/env bash
# Installs the software this desktop needs, on Fedora (dnf), Arch (pacman,
# plus an AUR helper if one is installed) or Debian/Ubuntu (apt).
# Run it before install.sh, which only places the config files.
#
# Every name is checked against the package manager before installing, so a
# name that doesn't exist on your distro is reported instead of failing the
# whole install.
#
# Usage: ./install-packages.sh            # resolve names, then install
#        ./install-packages.sh --dry-run  # only show what would be installed
set -euo pipefail

dry_run=0
[ "${1:-}" = "--dry-run" ] && dry_run=1

if command -v dnf >/dev/null; then pm=dnf
elif command -v pacman >/dev/null; then pm=pacman
elif command -v apt-get >/dev/null; then pm=apt
else
  echo "No supported package manager found (dnf, pacman or apt)." >&2
  exit 1
fi

aur_helper=""
if [ "$pm" = pacman ]; then
  for h in yay paru; do command -v "$h" >/dev/null && { aur_helper=$h; break; }; done
fi

# What it's for | dnf name | pacman name | apt name
# "a/b" means try a, then b. "-" means skip on that distro.
packages='
compositor         | labwc                    | labwc              | labwc
bar                | sfwbar                   | sfwbar             | sfwbar
launcher           | fuzzel                   | fuzzel             | fuzzel
terminal           | alacritty                | alacritty          | alacritty
wallpaper          | swaybg                   | swaybg             | swaybg
lock screen        | swaylock                 | swaylock           | swaylock
screenshots        | grim                     | grim               | grim
screenshot region  | slurp                    | slurp              | slurp
display scaling    | wlr-randr                | wlr-randr          | wlr-randr
brightness keys    | brightnessctl            | brightnessctl      | brightnessctl
X11 app support    | xorg-x11-server-Xwayland | xorg-xwayland      | xwayland
browser            | firefox                  | firefox            | firefox/firefox-esr
browser (Spotify)  | chromium                 | chromium           | chromium
files              | nautilus                 | nautilus           | nautilus
text editor        | mousepad                 | mousepad           | mousepad
calculator         | galculator               | galculator         | galculator
volume control     | pavucontrol              | pavucontrol        | pavucontrol
bluetooth          | blueman                  | blueman            | blueman
office             | libreoffice              | libreoffice-fresh  | libreoffice
media player       | vlc                      | vlc                | vlc
clock              | gnome-clocks             | gnome-clocks       | gnome-clocks
terminal font      | jetbrains-mono-fonts-all | ttf-jetbrains-mono | fonts-jetbrains-mono
system info        | fastfetch                | fastfetch          | fastfetch
notifications      | mako                     | mako               | mako-notifier/mako
dotfile installer  | stow                     | stow               | stow
GTK4 theme script  | python3-gobject          | python-gobject     | python3-gi
'

case $pm in dnf) col=2 ;; pacman) col=3 ;; apt) col=4 ;; esac

if [ "$pm" = apt ] && [ $dry_run -eq 0 ]; then
  sudo apt-get update
fi

available() {
  case $pm in
    dnf)    dnf -q info "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
    apt)    apt-cache show "$1" >/dev/null 2>&1 ;;
  esac
}

repo_pkgs=()
aur_pkgs=()
missing=()
report=()   # one "status|what|name" line per package, printed after checking

rows=()
while IFS= read -r line; do
  [[ $line == *'|'* ]] && rows+=("$line")
done <<< "$packages"

# On a terminal, show a single progress line that updates in place; in a log
# or pipe, just say what's happening.
tty=0; [ -t 1 ] && tty=1
echo "Package manager: $pm${aur_helper:+ (AUR via $aur_helper)}"
echo "Checking ${#rows[@]} package names (the first check can be slow while"
echo "the package lists are loaded)..."

i=0
for line in "${rows[@]}"; do
  i=$((i + 1))
  IFS='|' read -r -a row <<< "$line"
  what=$(echo "${row[0]}" | xargs)
  names=$(echo "${row[$((col - 1))]}" | xargs)
  [ "$names" = "-" ] && continue
  [ $tty -eq 1 ] && printf '\r\033[K  %d/%d  %s' "$i" "${#rows[@]}" "${names%%/*}"
  found=""
  IFS=/ read -r -a candidates <<< "$names"
  for name in "${candidates[@]}"; do
    if available "$name"; then found=$name; repo_pkgs+=("$name"); report+=("ok|$what|$name"); break; fi
  done
  if [ -z "$found" ] && [ -n "$aur_helper" ]; then
    for name in "${candidates[@]}"; do
      if "$aur_helper" -Si "$name" >/dev/null 2>&1; then found=$name; aur_pkgs+=("$name"); report+=("AUR|$what|$name"); break; fi
    done
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
[ ${#missing[@]} -gt 0 ] && summary+=", ${#missing[@]} not found"
echo "$summary."
if [ ${#missing[@]} -gt 0 ]; then
  echo "Install the ones marked -- yourself."
  if [ "$pm" = pacman ] && [ -z "$aur_helper" ]; then
    echo "(Arch: some of these are in the AUR; install yay or paru and re-run.)"
  fi
fi

[ $dry_run -eq 1 ] && { echo "Dry run: nothing installed."; exit 0; }

echo
echo "Installing (${pm} will ask to confirm)..."

if [ ${#repo_pkgs[@]} -gt 0 ]; then
  case $pm in
    dnf)    sudo dnf install "${repo_pkgs[@]}" ;;
    pacman) sudo pacman -S --needed "${repo_pkgs[@]}" ;;
    apt)    sudo apt-get install "${repo_pkgs[@]}" ;;
  esac
fi
if [ ${#aur_pkgs[@]} -gt 0 ]; then
  "$aur_helper" -S --needed "${aur_pkgs[@]}"
fi

echo
echo "Done. Next: ./install.sh"
