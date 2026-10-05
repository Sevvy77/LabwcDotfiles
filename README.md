# dotfiles

labwc + sfwbar + fuzzel + alacritty, themed **Crimson Dark** throughout (window
chrome, terminal, launcher, bar, Firefox, Nautilus, Mousepad, galculator,
Clocks, Volume Control, lock screen and every other GTK app, LibreOffice
included). Built on Fedora Asahi Remix; installs on Fedora,
Arch (including CachyOS) and Debian/Ubuntu, from a minimal TTY-only install
or alongside an existing desktop.
Full writeup, including known gaps and rationale: [`SPEC.md`](SPEC.md).

## Quick start

Works on x86 or ARM, on Debian, Ubuntu, Arch, CachyOS and Fedora.

Clone the repo into a `dotfiles` folder in your home directory:

```sh
git clone https://github.com/Sevvy77/LabwcDotfiles ~/dotfiles
```

Move into your new dotfiles directory:

```sh
cd ~/dotfiles
```

Run the automated package installer. Use `--dry-run` first if you'd like to
see what it will install before anything changes:

```sh
./install-packages.sh --dry-run
```

then:

```sh
./install-packages.sh
```

Run the installer script to apply my configs and theming:

```sh
./install.sh
```

Launch labwc:

```sh
labwc
```

Exit labwc from a shell with `labwc --exit`, or click on empty desktop space
and choose Exit from the menu that pops up.

## Layout

Each top-level directory holds config files laid out relative to `$HOME`,
which `install.sh` copies into place:

```
labwc/.config/labwc/{environment,autostart,rc.xml}
sfwbar/.config/sfwbar/sfwbar.config
fuzzel/.config/fuzzel/fuzzel.ini
alacritty/.config/alacritty/alacritty.toml
themes/.local/share/icons/Crimson-Wine/index.theme   # red GNOME-Colors Wine icons + Adwaita fallbacks
themes/.local/share/themes/OB-Crimson-Dark/
  labwc/themerc        # window theme
  gtk-3.0/gtk.css      # every GTK3 app (Mousepad, galculator, Blueman, LibreOffice, gtklock)
  gtk-4.0/gtk.css      # plain GTK4 apps: Volume Control (generated, see scripts/)
  gtk-4.0/gtk-dark.css # imports gtk.css; GTK4 loads it when dark is preferred
gtk3/.config/gtk-3.0/settings.ini                  # GTK theme = OB-Crimson-Dark, prefer dark
gtklock/.config/gtklock/style.css                  # lock screen wallpaper (fills portrait screens too)
gtk4/.config/gtk-4.0/settings.ini                  # same, for GTK4
gtk4/.config/gtk-4.0/gtk.css                       # libadwaita apps in dark mode (Nautilus, Clocks)
gtksourceview/.local/share/gtksourceview-4/styles/crimson-dark.xml   # Mousepad editor
dbus/.local/share/dbus-1/services/org.gnome.Nautilus.service         # dark Nautilus when D-Bus-started
dbus/.local/share/dbus-1/services/org.gnome.clocks.service           # dark Clocks when D-Bus-started (alarms)
applications/.local/share/applications/*.desktop   # theme overrides + custom launchers
bash/.bashrc
install-packages.sh   # installs the software (dnf, pacman+AUR, or apt; sfwbar from source on apt)
install.sh
update.sh             # pull from GitHub, then install over your configs (install.sh --force)
```

Handled separately by `install.sh`:

```
firefox/chrome/{userChrome,userContent}.css, firefox/user.js   # copied/merged into the default profile
scripts/gen-gtk4-crimson.py   # regenerates gtk-4.0/gtk.css from GTK's own stylesheet (not installed)
```

plus galculator's display colours (written into `galculator.conf`),
Mousepad's `crimson-dark` colour scheme, and the global GTK theme and dark
style (`org.gnome.desktop.interface` gtk-theme / color-scheme; all set with
`gsettings`, which is what GTK reads on Wayland).

## Install

```sh
git clone https://github.com/Sevvy77/LabwcDotfiles.git ~/dotfiles
cd ~/dotfiles
./install-packages.sh   # the software, as your normal user (uses sudo)
./install.sh            # the config files
labwc                   # from a TTY; or pick "labwc" in GDM/SDDM
```

That works from a minimal install with nothing but a TTY. You need `git`
to clone, and `sudo` for your user (or run `install-packages.sh` as root and
`install.sh` as your user; the script explains how to set up sudo if it's
missing).

### install-packages.sh

Works on Fedora, Arch and Debian/Ubuntu. It has one table mapping each
package to its name on each distro, checks every name before installing,
and lists anything it can't find instead of failing. Besides the desktop's
own programs it installs what a minimal system lacks: graphics drivers,
PipeWire audio, bluetooth, a polkit agent for password prompts, fonts and
icons. It then enables bluetooth and the PipeWire user services.

The bar, `sfwbar`, isn't packaged everywhere. On Arch it comes from the
AUR: with `yay` or `paru` if you have one, otherwise the script builds it
with `makepkg`. On Debian and Ubuntu it's built from source (the version
this config was written for) and installed to `/usr/local`.

Options: `--dry-run` shows what it would do, `--yes` doesn't ask to
confirm, `--skip vlc,libreoffice` leaves packages out.

On Ubuntu, Firefox and Chromium are snaps. Ubuntu's snap Firefox is
supported, but it can't read hidden directories in `$HOME`, so clone this
repo somewhere like `~/dotfiles`, not `~/.dotfiles`.

### install.sh

Copies every config file into `$HOME`, fills in the one `.desktop` file that
needs an absolute path, applies the theme pieces that aren't plain files
(`galculator`, `mousepad`, `firefox`), creates `~/Pictures`, refreshes the
desktop database and reloads the D-Bus session config. Pass names to install
a subset, e.g. `./install.sh alacritty bash firefox`, and `--verbose` to see
what happened to every file.

The installed files are copies, not links into this repo: once installed,
they're yours to edit, and the repo stays clean. It is safe to re-run (for
example after `git pull`). The script remembers which version of each file
it installed (in `~/.local/state/crimson-dotfiles/`), and on a re-run:

- files you haven't changed are updated to the repo's current version;
- files you have changed are left alone. If the repo's version has changed
  too, it's written beside yours as `<file>.new` and listed at the end, so
  you can compare and merge (`diff`), then delete the `.new`;
- files that were already there before the first install are treated the
  same way: never overwritten, with the repo's version as `.new`.

`--force` replaces files that differ with the repo's version, keeping yours
as `<file>.bak`.

The one exception is a `~/.bashrc` that is still the distro's stock copy
from `/etc/skel` (as on a new install): it's moved to `~/.bashrc.skel`,
which this repo's `.bashrc` sources, so you keep your distro's defaults.

Installs made by earlier versions of this script symlinked files into the
repo; a re-run replaces those symlinks with copies.

Firefox needs a profile to exist first (start and quit it once, then run
`./install.sh firefox`), and a restart to pick up the stylesheets. galculator
must be closed while its colours are written.

### update.sh

Gets the latest version from GitHub and installs it over your config files,
replacing any that differ from the repo (your changed copies are kept as
`<file>.bak`). It's `git pull --ff-only` then `./install.sh --force`, and
takes the same names and `--verbose`. Without git (e.g. a copy from the
.zip), it downloads the repo with curl or wget instead. Works on Fedora,
Arch, CachyOS, Debian and Ubuntu.

Use `./install.sh` after `git pull` instead if you'd rather keep your
changes and merge the repo's `.new` versions yourself.

### Your own changes

- Wallpaper: `~/Pictures/wallpaper.png` if it exists (desktop and lock
  screen), otherwise the theme's background colour.
- Anything specific to one machine (a different monitor setup, the bar on
  one screen only, keybindings): edit the installed files in `~/.config`
  directly.
- Display scaling and other startup commands can also go in
  `~/.config/labwc/autostart.local`, which `autostart` runs and which the
  repo doesn't ship, so repo updates to `autostart` still apply cleanly.
  For example: `wlr-randr --output eDP-1 --scale 1.4`

## Known gaps (see SPEC.md section 8 for details)

- The Volume Control theme is generated from GTK 4.22's built-in stylesheet.
  After a GTK4 upgrade, re-run `scripts/gen-gtk4-crimson.py` (needs
  `python3-gobject`), as `install.sh` reminds you.
- Volume Control's slider knobs stay grey: they are bitmap images inside GTK.
- Web pages keep their own colours; Dark Reader (a browser extension, not in
  this repo) darkens them.
- `bluez`, `network-module` and `volume` sfwbar widgets are commented out —
  re-enabling them on `sfwbar 1.0~beta16` deadlocks the bar (see the config
  file for the full explanation).
- No idle/lock daemon and no notification daemon (`mako` is installed but not
  started); add them to `autostart` if you want either.

## License

GPL-3.0; see [`LICENSE`](LICENSE).

Started from [antomfdez/LabwcDots](https://github.com/antomfdez/LabwcDots)
(GPL-3.0). The bar config and window theme have since been rewritten from
scratch; the alacritty config keeps its general shape.
