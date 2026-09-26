#!/usr/bin/env bash
# Installs this repo's packages into $HOME with GNU Stow, then does the parts
# of the Crimson Dark theme that can't be symlinked:
#   - spotify-web.desktop needs an absolute path (.desktop Exec lines are not
#     variable-expanded by spec, so it can't just be "$HOME")
#   - galculator display colours (galculator rewrites its config on exit,
#     which would replace a stowed symlink)
#   - Mousepad's editor colour scheme (lives in GSettings, not a file)
#   - Firefox userChrome/userContent (the profile directory name is random)
#
# Usage: ./install.sh              # everything
#        ./install.sh labwc bash   # only these (stow packages and/or the
#                                  # extras: galculator mousepad firefox)
set -euo pipefail
cd "$(dirname "$0")"

stow_all=(labwc sfwbar fuzzel alacritty themes applications bash gtk4 gtksourceview dbus)
extras_all=(galculator mousepad firefox)

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  targets=("${stow_all[@]}" "${extras_all[@]}")
fi

stow_pkgs=()
extras=()
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
  # A previous run replaced spotify-web.desktop's symlink with a filled-in
  # copy (see below). Remove it if it's still exactly that, so stow can
  # re-link; a hand-edited copy is left alone and stow reports the conflict.
  spotify_src=applications/.local/share/applications/spotify-web.desktop
  spotify_dst="$HOME/.local/share/applications/spotify-web.desktop"
  if [ -f "$spotify_dst" ] && [ ! -L "$spotify_dst" ] &&
     sed "s|__HOME__|$HOME|g" "$spotify_src" | cmp -s - "$spotify_dst"; then
    rm "$spotify_dst"
  fi

  # --no-folding: create real directories and link individual files. With
  # folding, a missing ~/.local/share/applications would become a symlink to
  # the repo, and anything written there later (desktop database caches, the
  # spotify-web fix-up below) would land inside the repo.
  stow -v --no-folding -t "$HOME" "${stow_pkgs[@]}"
fi

# spotify-web.desktop needs the absolute home path. Replace the stowed
# symlink with a real, filled-in copy so the repo keeps its __HOME__ placeholder.
desktop_file="$HOME/.local/share/applications/spotify-web.desktop"
if [ -L "$desktop_file" ]; then
  src=$(readlink -f "$desktop_file")
  rm "$desktop_file"
  sed "s|__HOME__|$HOME|g" "$src" > "$desktop_file"
elif [ -e "$desktop_file" ]; then
  sed -i "s|__HOME__|$HOME|g" "$desktop_file"
fi

install_galculator() {
  local conf="$HOME/.config/galculator/galculator.conf"
  if pgrep -x galculator >/dev/null; then
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
    gsettings set org.xfce.mousepad.preferences.view color-scheme crimson-dark
    echo "mousepad: colour scheme set to crimson-dark."
  else
    echo "mousepad: schema not found (is mousepad installed?); skipped." >&2
  fi
}

install_firefox() {
  local base="" dir ini profile=""
  for dir in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
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

for e in "${extras[@]}"; do
  "install_$e"
done

mkdir -p "$HOME/Pictures"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
# Let the session bus see the Nautilus D-Bus override without logging out.
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
  org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true

cat <<EOF

Installed. Still needed:
  - A wallpaper at ~/Pictures/wallpaper.png (or edit the path in
    labwc/.config/labwc/autostart and rc.xml).
  - Start labwc on login (see SPEC.md section 2) if not already configured.
    If labwc is already running: labwc -r, and restart sfwbar.
  - Install the software first with ./install-packages.sh, if you haven't.
  - After a GTK4 upgrade, regenerate the Volume Control theme:
    python3 scripts/gen-gtk4-crimson.py > themes/.local/share/themes/OB-Crimson-Dark/gtk-4.0/gtk.css
EOF
