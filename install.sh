#!/usr/bin/env bash
# Installs this repo's packages into $HOME with GNU Stow, then does the parts
# of the Crimson Dark theme that can't be symlinked:
#   - spotify-web.desktop needs an absolute path (.desktop Exec lines are not
#     variable-expanded by spec, so it can't just be "$HOME") and the local
#     name of Chromium's command
#   - galculator display colours (galculator rewrites its config on exit,
#     which would replace a stowed symlink)
#   - Mousepad's editor colour scheme (lives in GSettings, not a file)
#   - Firefox userChrome/userContent (the profile directory name is random)
#
# Usage: ./install.sh              # everything
#        ./install.sh labwc bash   # only these (stow packages and/or the
#                                  # extras: galculator mousepad firefox)
#        ./install.sh --verbose    # also show every file stow links
set -euo pipefail
cd "$(dirname "$0")"

# spotify-web.desktop is generated from the repo copy: __HOME__ becomes the
# home path and __CHROMIUM__ the Chromium command, which is chromium-browser
# on Fedora and chromium on Arch and Debian.
spotify_src=applications/.local/share/applications/spotify-web.desktop
spotify_dst="$HOME/.local/share/applications/spotify-web.desktop"
chromium_cmds=(chromium-browser chromium)
render_spotify() {
  sed -e "s|__HOME__|$HOME|g" -e "s|__CHROMIUM__|$1|g" "$spotify_src"
}

stow_all=(labwc sfwbar fuzzel alacritty themes applications bash gtk4 gtksourceview dbus)
extras_all=(galculator mousepad firefox)

verbose=0
targets=()
for a in "$@"; do
  case $a in
    -v|--verbose) verbose=1 ;;
    *)            targets+=("$a") ;;
  esac
done
if [ ${#targets[@]} -eq 0 ]; then
  targets=("${stow_all[@]}" "${extras_all[@]}")
fi

stow_pkgs=()
extras=()
skipped=()
relinked_spotify=0
for t in "${targets[@]}"; do
  case " ${extras_all[*]} " in
    *" $t "*) extras+=("$t") ;;
    *)        stow_pkgs+=("$t") ;;
  esac
done

if [ ${#stow_pkgs[@]} -gt 0 ]; then
  if ! command -v stow >/dev/null; then
    echo "GNU Stow is required (dnf install stow / apt install stow)." >&2
    exit 1
  fi
  # A previous run replaced spotify-web.desktop's symlink with a generated
  # copy (see below). Remove it if it's still exactly that, with either
  # Chromium command, so stow can re-link; a hand-edited copy is left alone
  # and stow reports the conflict.
  if [[ " ${stow_pkgs[*]} " == *" applications "* ]] &&
     [ -f "$spotify_dst" ] && [ ! -L "$spotify_dst" ]; then
    for c in "${chromium_cmds[@]}"; do
      if [ "$(render_spotify "$c")" = "$(<"$spotify_dst")" ]; then
        rm "$spotify_dst"
        relinked_spotify=1
        break
      fi
    done
  fi

  # --no-folding: create real directories and link individual files. With
  # folding, a missing ~/.local/share/applications would become a symlink to
  # the repo, and anything written there later (desktop database caches, the
  # spotify-web fix-up below) would land inside the repo.
  #
  # One package at a time: stow aborts every package in a call if any one of
  # them conflicts, and on an existing account something (usually .bashrc)
  # almost always does.
  echo "Linking config files into $HOME:"
  # A new account's ~/.bashrc is just the distro's stock copy from /etc/skel.
  # Move it to ~/.bashrc.skel, which this repo's .bashrc sources, so bash can
  # be linked. A .bashrc with changes of your own is left alone (skipped).
  if [[ " ${stow_pkgs[*]} " == *" bash "* ]] && [ -f "$HOME/.bashrc" ] &&
     [ ! -L "$HOME/.bashrc" ] && [ -f /etc/skel/.bashrc ] &&
     [ "$(<"$HOME/.bashrc")" = "$(</etc/skel/.bashrc)" ]; then
    mv "$HOME/.bashrc" "$HOME/.bashrc.skel"
    echo "  (your ~/.bashrc was the distro's stock one; moved to ~/.bashrc.skel)"
  fi
  for pkg in "${stow_pkgs[@]}"; do
    if out=$(stow -v --no-folding -t "$HOME" "$pkg" 2>&1); then
      n=$(grep -c '^LINK:' <<< "$out" || true)
      # Re-linking the launcher removed above isn't news on a re-run.
      [ "$pkg" = applications ] && [ $relinked_spotify -eq 1 ] && n=$((n - 1))
      if [ "$n" -eq 0 ]; then status="already linked"
      elif [ "$n" -eq 1 ]; then status="linked (1 file)"
      else status="linked ($n files)"; fi
    else
      skipped+=("$pkg")
      # The files in the way. Stow 2.4 says "... over existing target X since
      # ...", 2.3 says "existing target is ...: X".
      conflicts=$(sed -n -e 's/.* over existing target \(.*\) since .*/~\/\1/p' \
                         -e 's/.*existing target is [^:]*: \(.*\)/~\/\1/p' <<< "$out" | xargs)
      if [ -n "$conflicts" ]; then status="skipped: $conflicts already exists"
      else status="skipped: $(grep -v '^$' <<< "$out" | tail -1)"; fi
    fi
    printf '  %-14s %s\n' "$pkg" "$status"
    [ $verbose -eq 1 ] && [ -n "$out" ] && sed 's/^/      /' <<< "$out"
  done
fi

# Replace the stowed spotify-web.desktop symlink with a generated copy, so
# the repo keeps its placeholders. Also regenerate it if it was removed above
# but applications was then skipped for a conflict.
if [ -L "$spotify_dst" ] || [ $relinked_spotify -eq 1 ]; then
  chromium=""
  for c in "${chromium_cmds[@]}"; do
    command -v "$c" >/dev/null && { chromium=$c; break; }
  done
  if [ -z "$chromium" ]; then
    chromium=chromium
    echo "  (Spotify launcher: Chromium not found, so it uses 'chromium'. Re-run after installing it.)"
  fi
  rm -f "$spotify_dst"
  render_spotify "$chromium" > "$spotify_dst"
fi
[ ${#stow_pkgs[@]} -gt 0 ] && echo

install_galculator() {
  local conf="$HOME/.config/galculator/galculator.conf"
  # /proc rather than pgrep, which minimal Debian and Ubuntu don't have.
  if grep -qsx galculator /proc/[0-9]*/comm; then
    echo "galculator: close it first (it overwrites its config on exit); skipped." >&2
    return
  fi
  mkdir -p "$(dirname "$conf")"
  touch "$conf"
  local key value
  while read -r key value; do
    if grep -q "^$key=" "$conf"; then
      sed -i "s|^$key=.*|$key=\"$value\"|" "$conf"
    else
      # galculator keeps its display settings in the [general] section
      grep -q '^\[general\]' "$conf" || printf '[general]\n' >> "$conf"
      sed -i "/^\[general\]/a $key=\"$value\"" "$conf"
    fi
  done <<'EOF'
display_bkg_color #1f1416
display_result_color #e8d5d0
display_stack_color #e8d5d0
display_module_active_color #e5484d
display_module_inactive_color #7a5a5e
EOF
  echo "galculator: display colours set."
}

install_mousepad() {
  if gsettings writable org.xfce.mousepad.preferences.view color-scheme >/dev/null 2>&1; then
    gsettings set org.xfce.mousepad.preferences.view color-scheme crimson-dark 2>/dev/null || true
    # Saving needs a D-Bus session, which a TTY login right after installing
    # dbus-user-session (Debian/Ubuntu) doesn't have yet.
    if [ "$(gsettings get org.xfce.mousepad.preferences.view color-scheme 2>/dev/null)" = "'crimson-dark'" ]; then
      echo "mousepad: colour scheme set to crimson-dark."
    else
      echo "mousepad: couldn't save the colour scheme (no D-Bus session yet?)." >&2
      echo "          Log out and in again, then run: ./install.sh mousepad" >&2
    fi
  else
    echo "mousepad: schema not found (is mousepad installed?); skipped." >&2
  fi
}

install_firefox() {
  local base="" dir ini profile=""
  # The last one is Ubuntu's Firefox snap.
  for dir in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox" \
             "$HOME/snap/firefox/common/.mozilla/firefox"; do
    [ -f "$dir/profiles.ini" ] && { base="$dir"; break; }
  done
  if [ -z "$base" ]; then
    echo "firefox: no profile yet. Start Firefox once, quit it, then run: ./install.sh firefox" >&2
    return
  fi
  ini="$base/profiles.ini"
  # The profile this Firefox install actually uses ([Install...] Default=),
  # falling back to the profile marked Default=1.
  profile=$(awk -F= '/^\[Install/{i=1;next} /^\[/{i=0} i&&$1=="Default"{print $2;exit}' "$ini")
  if [ -z "$profile" ]; then
    profile=$(awk -F= '/^\[Profile/{p="";d=0} $1=="Path"{p=$2} $1=="Default"&&$2==1{d=1} d&&p{print p;exit}' "$ini")
  fi
  if [ -z "$profile" ] || [ ! -d "$base/$profile" ]; then
    echo "firefox: couldn't work out the default profile from $ini; skipped." >&2
    return
  fi
  local p="$base/$profile"
  mkdir -p "$p/chrome"
  ln -sfn "$PWD/firefox/chrome/userChrome.css" "$p/chrome/userChrome.css"
  ln -sfn "$PWD/firefox/chrome/userContent.css" "$p/chrome/userContent.css"
  # Merge prefs into user.js rather than replacing any existing one.
  touch "$p/user.js"
  local line
  while IFS= read -r line; do
    case "$line" in user_pref*) grep -qxF "$line" "$p/user.js" || echo "$line" >> "$p/user.js" ;; esac
  done < firefox/user.js
  echo "firefox: installed into $p (restart Firefox to apply)."
}

if [ ${#extras[@]} -gt 0 ]; then
  echo "Theme settings that can't be linked:"
  for e in "${extras[@]}"; do
    "install_$e" 2>&1 | sed 's/^/  /'
  done
  echo
fi

mkdir -p "$HOME/Pictures"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
# Let the session bus see the Nautilus D-Bus override without logging out.
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
  org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true

cat <<EOF
To start the desktop:
  - From a TTY: log in and run labwc.
  - From a display manager (GDM, SDDM...): log out and pick "labwc" as the
    session.
  - If labwc is already running: labwc -r, then restart sfwbar.

Optional:
  - A wallpaper at ~/Pictures/wallpaper.png (otherwise a plain background).
  - Per-machine settings such as display scaling in
    ~/.config/labwc/autostart.local, e.g.:
      wlr-randr --output eDP-1 --scale 1.4
  - After a GTK4 upgrade, regenerate the Volume Control theme:
    python3 scripts/gen-gtk4-crimson.py > themes/.local/share/themes/OB-Crimson-Dark/gtk-4.0/gtk.css
EOF
command -v labwc >/dev/null ||
  printf '\nlabwc isn'"'"'t installed yet: run ./install-packages.sh first.\n'

echo
if [ ${#skipped[@]} -gt 0 ]; then
  cat <<EOF
Done, but $([ ${#skipped[@]} -eq 1 ] && echo "1 package was" || echo "${#skipped[@]} packages were") skipped because files already exist:
  ${skipped[*]}
Move or merge those files (listed above), then run: ./install.sh ${skipped[*]}
EOF
  exit 1
fi
echo "Done."
