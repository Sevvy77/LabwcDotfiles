#!/usr/bin/env bash
# Copies this repo's config files into $HOME, then does the parts of the
# Crimson Dark theme that aren't plain files:
#   - galculator display colours (galculator rewrites its config on exit, so
#     only its colour keys are set)
#   - Mousepad's editor colour scheme (lives in GSettings, not a file)
#   - the GTK theme and dark style for every GTK app (also GSettings)
#   - Firefox userChrome/userContent (the profile directory name is random)
#
# The copies are yours to edit; the repo is only where they come from. Each
# run remembers what it installed (in $state_dir below), so a re-run after
# "git pull":
#   - updates files you haven't changed
#   - leaves files you have changed alone, and puts the repo's new version
#     next to them as <file>.new for you to compare and merge
#   - never overwrites a file it didn't install, unless you pass --force
#     (which backs it up to <file>.bak first)
#
# Usage: ./install.sh              # everything
#        ./install.sh labwc bash   # only these (config directories in this
#                                  # repo and/or the extras: galculator
#                                  # gtk mousepad firefox)
#        ./install.sh --force      # replace files that differ, keeping .bak
#        ./install.sh --verbose    # also show what happened to every file
set -euo pipefail
cd "$(dirname "$0")"
repo=$PWD

state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/crimson-dotfiles
# One line per installed file: the sha256 of the repo version it was last
# brought up to date with, then its absolute path.
manifest=$state_dir/installed

# spotify-web.desktop is generated from the repo copy: __HOME__ becomes the
# home path (.desktop Exec lines aren't variable-expanded, so it can't just be
# "$HOME") and __CHROMIUM__ the Chromium command, which is chromium-browser on
# Fedora and chromium on Arch and Debian.
spotify_src=applications/.local/share/applications/spotify-web.desktop

files_all=(labwc sfwbar fuzzel alacritty themes applications bash gtk3 gtk4 gtklock gtksourceview dbus)
extras_all=(gtk galculator mousepad firefox)

verbose=0
force=0
targets=()
for a in "$@"; do
  case $a in
    -v|--verbose) verbose=1 ;;
    -f|--force)   force=1 ;;
    -*)           echo "Unknown option: $a" >&2; exit 2 ;;
    *)            targets+=("$a") ;;
  esac
done
if [ ${#targets[@]} -eq 0 ]; then
  targets=("${files_all[@]}" "${extras_all[@]}")
fi

groups=()
extras=()
for t in "${targets[@]}"; do
  case " ${extras_all[*]} " in
    *" $t "*) extras+=("$t") ;;
    *) if [ -d "$t" ] && [[ " ${files_all[*]} " == *" $t "* ]]; then groups+=("$t")
       else echo "Unknown name: $t (expected one of: ${files_all[*]} ${extras_all[*]})" >&2; exit 2; fi ;;
  esac
done

declare -A baseline=()
if [ -f "$manifest" ]; then
  while read -r h p; do [ -n "$p" ] && baseline[$p]=$h; done < "$manifest"
fi
save_manifest() {
  mkdir -p "$state_dir"
  local p
  for p in "${!baseline[@]}"; do printf '%s %s\n' "${baseline[$p]}" "$p"; done |
    sort -k2 > "$manifest.tmp"
  mv "$manifest.tmp" "$manifest"
}

sha() { sha256sum "$1" | cut -d' ' -f1; }
tilde() { echo "~${1#"$HOME"}"; }

# Results of the current group, and of the whole run.
n_new=0 n_updated=0 n_same=0 n_custom=0
pending=()   # files with a .new version waiting
backed_up=() # files --force replaced

# place SRC DST: install SRC's content at DST (an absolute path).
place() {
  local src=$1 dst=$2 new cur base action
  new=$(sha "$src")
  base=${baseline[$dst]:-}
  # Earlier versions of this script symlinked files into the repo. Swap
  # those for copies; they point at the same content.
  if [ -L "$dst" ] && [[ $(readlink -f "$dst") == "$repo"/* ]]; then
    rm "$dst"
    base=$new
  fi
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    action=installed; n_new=$((n_new + 1))
  else
    cur=$(sha "$dst")
    if [ "$cur" = "$new" ]; then
      action="up to date"; n_same=$((n_same + 1))
    elif [ -n "$base" ] && [ "$cur" = "$base" ]; then
      # Unchanged since we installed it: take the repo's new version.
      cp "$src" "$dst"
      action=updated; n_updated=$((n_updated + 1))
    elif [ $force -eq 1 ]; then
      mv "$dst" "$dst.bak"
      cp "$src" "$dst"
      backed_up+=("$dst")
      action="replaced (old copy in $(basename "$dst").bak)"; n_updated=$((n_updated + 1))
    elif [ "$base" = "$new" ]; then
      # Your changes, and nothing new from the repo.
      action="kept your changes"; n_custom=$((n_custom + 1))
    else
      # Your changes (or a file that was here before), and the repo has a
      # version you haven't seen: leave yours, put the repo's beside it.
      cp "$src" "$dst.new"
      pending+=("$dst")
      action="kept yours, repo version in $(basename "$dst").new"; n_custom=$((n_custom + 1))
    fi
  fi
  # A .new that's been merged in (or made obsolete) is no longer needed.
  if [ -f "$dst.new" ] && [ "$(sha "$dst")" = "$new" ]; then rm "$dst.new"; fi
  baseline[$dst]=$new
  [ $verbose -eq 1 ] && printf '      %s: %s\n' "$(tilde "$dst")" "$action"
  return 0
}

if [ ${#groups[@]} -gt 0 ]; then
  echo "Copying config files into $HOME:"
  # A new account's ~/.bashrc is just the distro's stock copy from /etc/skel.
  # Move it to ~/.bashrc.skel, which this repo's .bashrc sources, so the
  # distro's defaults are kept.
  if [[ " ${groups[*]} " == *" bash "* ]] && [ -f "$HOME/.bashrc" ] &&
     [ ! -L "$HOME/.bashrc" ] && [ -f /etc/skel/.bashrc ] &&
     [ "$(<"$HOME/.bashrc")" = "$(</etc/skel/.bashrc)" ]; then
    mv "$HOME/.bashrc" "$HOME/.bashrc.skel"
    echo "  (your ~/.bashrc was the distro's stock one; moved to ~/.bashrc.skel)"
  fi
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  for g in "${groups[@]}"; do
    n_new=0 n_updated=0 n_same=0 n_custom=0
    while IFS= read -r -d '' f; do
      src=$f
      if [ "$f" = "$spotify_src" ]; then
        chromium=chromium
        for c in chromium-browser chromium; do
          command -v "$c" >/dev/null && { chromium=$c; break; }
        done
        command -v "$chromium" >/dev/null ||
          echo "  (Spotify launcher: Chromium not found, so it uses 'chromium'. Re-run after installing it.)"
        src=$tmp/spotify-web.desktop
        sed -e "s|__HOME__|$HOME|g" -e "s|__CHROMIUM__|$chromium|g" "$f" > "$src"
      fi
      place "$src" "$HOME/${f#"$g"/}"
    done < <(find "$g" -type f ! -name '*.bak' ! -name '*~' ! -name mimeinfo.cache -print0 | sort -z)
    parts=()
    [ $n_new -gt 0 ]     && parts+=("$n_new new")
    [ $n_updated -gt 0 ] && parts+=("$n_updated updated")
    [ $n_custom -gt 0 ]  && parts+=("$n_custom customised")
    [ ${#parts[@]} -eq 0 ] && parts=("up to date")
    status=$(IFS=,; echo "${parts[*]}" | sed 's/,/, /g')
    printf '  %-14s %s\n' "$g" "$status"
  done
  save_manifest
  echo
fi

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

install_gtk() {
  local schema=org.gnome.desktop.interface key value failed=0
  if ! gsettings writable $schema gtk-theme >/dev/null 2>&1; then
    echo "gtk: schema $schema not found (is gsettings-desktop-schemas installed?); skipped." >&2
    return
  fi
  # GTK on Wayland takes these from GSettings, not settings.ini.
  while read -r key value; do
    gsettings set $schema "$key" "$value" 2>/dev/null || true
    [ "$(gsettings get $schema "$key" 2>/dev/null)" = "'$value'" ] || failed=1
  done <<'EOF'
gtk-theme OB-Crimson-Dark
icon-theme Adwaita
color-scheme prefer-dark
EOF
  if [ $failed -eq 0 ]; then
    echo "gtk: theme set to OB-Crimson-Dark, dark style preferred."
  else
    echo "gtk: couldn't save the GTK theme settings (no D-Bus session yet?)." >&2
    echo "     Log out and in again, then run: ./install.sh gtk" >&2
  fi
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
  local p="$base/$profile" f
  for f in userChrome.css userContent.css; do
    place "firefox/chrome/$f" "$p/chrome/$f"
  done
  # Merge prefs into user.js rather than replacing any existing one.
  touch "$p/user.js"
  local line
  while IFS= read -r line; do
    case "$line" in user_pref*) grep -qxF "$line" "$p/user.js" || echo "$line" >> "$p/user.js" ;; esac
  done < firefox/user.js
  echo "firefox: installed into $p (restart Firefox to apply)."
}

if [ ${#extras[@]} -gt 0 ]; then
  tmp_out=$(mktemp)
  echo "Theme settings that aren't plain config files:"
  for e in "${extras[@]}"; do
    # Not in a pipeline, so place() can update the manifest and lists.
    "install_$e" > "$tmp_out" 2>&1 || true
    sed 's/^/  /' "$tmp_out"
  done
  rm -f "$tmp_out"
  save_manifest
  echo
fi

mkdir -p "$HOME/Pictures"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
# Let the session bus see the D-Bus overrides (Nautilus, Clocks) without logging out.
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
  - Your own changes: edit the files in ~/.config and ~/.local/share
    directly. They're copies, and re-running this script won't undo them.
    Display scaling is a good fit for ~/.config/labwc/autostart.local, e.g.:
      wlr-randr --output eDP-1 --scale 1.4
  - After a GTK4 upgrade, regenerate the Volume Control theme:
    python3 scripts/gen-gtk4-crimson.py > themes/.local/share/themes/OB-Crimson-Dark/gtk-4.0/gtk.css
    ./install.sh themes
EOF
command -v labwc >/dev/null ||
  printf '\nlabwc isn'"'"'t installed yet: run ./install-packages.sh first.\n'

echo
if [ ${#pending[@]} -gt 0 ]; then
  echo "These files differ from the repo's latest version and were left as they"
  echo "are. The repo's version is beside each as .new: compare, merge what you"
  echo "want, then delete the .new."
  for p in "${pending[@]}"; do echo "  diff $(tilde "$p") $(tilde "$p").new"; done
  echo "(Or run with --force to take the repo versions, backing yours up as .bak.)"
  echo
fi
if [ ${#backed_up[@]} -gt 0 ]; then
  echo "Replaced with the repo's version (your old copies are the .bak files):"
  for p in "${backed_up[@]}"; do echo "  $(tilde "$p")"; done
  echo
fi
echo "Done."
