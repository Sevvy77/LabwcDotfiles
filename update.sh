#!/usr/bin/env bash
# Brings this desktop up to date with the GitHub repo: gets the latest
# version, installs any software it now needs (install-packages.sh, which
# uses sudo and skips what's already installed), then installs it over your
# config files, replacing any that differ (install.sh --force). Files you'd
# changed are kept as <file>.bak beside the new version, except
# ~/.config/labwc/autostart: once you've edited it, it's left alone and the
# repo's version goes beside it as autostart.new. autostart.local isn't in the
# repo, so it's never touched.
#
# Works on Fedora, Arch, CachyOS, Debian and Ubuntu. Uses git when this is a
# git clone, otherwise downloads the repo with curl or wget (a copy from a
# .zip, or a system without git).
#
# Usage: ./update.sh               # everything
#        ./update.sh labwc bash    # only these (same names as install.sh)
#        ./update.sh --verbose     # also show what happened to every file
#        ./update.sh --no-packages # config files only, no install-packages.sh
#        ./update.sh --yes         # don't ask to confirm package installs
# Naming config groups (as in the second line) also skips the packages.
#
# The whole script is one block so bash reads it all before running: the
# update may replace this file while it runs.
{
set -euo pipefail
cd "$(dirname "$0")"

github=https://github.com/Sevvy77/LabwcDotfiles
branch=main

packages=1
pkg_args=()
install_args=()
for a in "$@"; do
  case $a in
    -h|--help) sed -n '2,/^# The whole/{/^# The whole/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    --no-packages) packages=0 ;;
    -y|--yes) pkg_args+=("$a") ;;
    -*) install_args+=("$a") ;;
    *) install_args+=("$a"); packages=0 ;;
  esac
done

# After pulling, a changed update.sh restarts itself so the new version
# does the rest; this marks the restarted run so it doesn't pull again.
if [ -n "${CRIMSON_UPDATE_PULLED:-}" ]; then
  skip_pull=1
else
  skip_pull=0
  before=$(sha256sum update.sh | cut -d' ' -f1)
fi

if [ $skip_pull -eq 0 ]; then
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
    rm -rf "$tmp"
    echo "  updated $PWD"
  fi
  echo

  if [ "$(sha256sum update.sh | cut -d' ' -f1)" != "$before" ]; then
    echo "update.sh itself changed; continuing with the new version."
    echo
    CRIMSON_UPDATE_PULLED=1 exec ./update.sh "$@"
  fi
fi

if [ $packages -eq 1 ]; then
  echo "Installing any software the repo now needs (install-packages.sh):"
  if ! ./install-packages.sh ${pkg_args[@]+"${pkg_args[@]}"}; then
    echo >&2
    echo "install-packages.sh didn't finish (see above); installing the config" >&2
    echo "files anyway. Re-run ./update.sh (or ./install-packages.sh) to retry." >&2
  fi
  echo
fi

exec ./install.sh --force ${install_args[@]+"${install_args[@]}"}
}
