#!/usr/bin/env bash
# Brings this desktop up to date with the GitHub repo: gets the latest
# version, then installs it over your config files, replacing any that
# differ (install.sh --force). Files you'd changed are kept as <file>.bak
# beside the new version; ~/.config/labwc/autostart.local isn't in the repo,
# so it's never touched.
#
# Works on Fedora, Arch, CachyOS, Debian and Ubuntu. Uses git when this is a
# git clone, otherwise downloads the repo with curl or wget (a copy from a
# .zip, or a system without git).
#
# Usage: ./update.sh               # everything
#        ./update.sh labwc bash    # only these (same names as install.sh)
#        ./update.sh --verbose     # also show what happened to every file
#
# The whole script is one block so bash reads it all before running: the
# update may replace this file while it runs.
{
set -euo pipefail
cd "$(dirname "$0")"

github=https://github.com/Sevvy77/LabwcDotfiles
branch=main

for a in "$@"; do
  case $a in
    -h|--help) sed -n '2,/^# The whole/{/^# The whole/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
  esac
done

if [ -d .git ] && command -v git >/dev/null; then
  echo "Getting the latest version with git:"
  # --ff-only never merges or discards anything in this clone: if you've
  # committed here yourself, it stops instead.
  if ! git pull --ff-only 2>&1 | sed 's/^/  /'; then
    echo >&2
    echo "Couldn't update $PWD from GitHub (see above). If you've changed" >&2
    echo "files in the repo itself, commit, stash or discard them first." >&2
    exit 1
  fi
else
  echo "Downloading the latest version from $github:"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  url=$github/archive/refs/heads/$branch.tar.gz
  if command -v curl >/dev/null; then
    curl -fsSL "$url" -o "$tmp/repo.tar.gz"
  elif command -v wget >/dev/null; then
    wget -qO "$tmp/repo.tar.gz" "$url"
  else
    echo "Needs git, curl or wget to download the repo; none is installed." >&2
    exit 1
  fi
  tar -xzf "$tmp/repo.tar.gz" -C "$tmp" --strip-components=1
  rm "$tmp/repo.tar.gz"
  cp -a "$tmp/." .
  echo "  updated $PWD"
fi
echo

exec ./install.sh --force "$@"
}
