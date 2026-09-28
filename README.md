# dotfiles

labwc + sfwbar + fuzzel + alacritty, themed **Crimson Dark** throughout (window
chrome, terminal, launcher, bar, Firefox, Nautilus, Mousepad, galculator,
Clocks, Volume Control). Built on Fedora Asahi Remix; installs on Fedora,
Arch (including CachyOS) and Debian/Ubuntu, from a minimal TTY-only install
or alongside an existing desktop. LibreOffice is left stock.
Full writeup, including known gaps and rationale: [`SPEC.md`](SPEC.md).

## Layout

Each top-level directory is a [GNU Stow](https://www.gnu.org/software/stow/)
package, laid out relative to `$HOME`:

```
labwc/.config/labwc/{environment,autostart,rc.xml}
sfwbar/.config/sfwbar/sfwbar.config
fuzzel/.config/fuzzel/fuzzel.ini
alacritty/.config/alacritty/alacritty.toml
themes/.local/share/themes/OB-Crimson-Dark/
  labwc/themerc        # window theme
  gtk-3.0/gtk.css      # Mousepad, galculator (via GTK_THEME on their launchers)
  gtk-4.0/gtk.css      # Volume Control (generated, see scripts/)
gtk4/.config/gtk-4.0/gtk.css                       # libadwaita apps in dark mode (Nautilus, Clocks)
gtksourceview/.local/share/gtksourceview-4/styles/crimson-dark.xml   # Mousepad editor
dbus/.local/share/dbus-1/services/org.gnome.Nautilus.service         # dark Nautilus when D-Bus-started
applications/.local/share/applications/*.desktop   # theme overrides + custom launchers
bash/.bashrc
install-packages.sh   # installs the software (dnf, pacman+AUR, or apt; sfwbar from source on apt)
install.sh
```

Not stowed, applied by `install.sh` instead:

```
firefox/chrome/{userChrome,userContent}.css, firefox/user.js   # symlinked/merged into the default profile
scripts/gen-gtk4-crimson.py   # regenerates gtk-4.0/gtk.css from GTK's own stylesheet
```

plus galculator's display colours (written into `galculator.conf`) and
Mousepad's `crimson-dark` colour scheme (set with `gsettings`).

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

Stows every package into `$HOME`, fills in the one `.desktop` file that
needs an absolute path, applies the non-stowable theme pieces (`galculator`,
`mousepad`, `firefox`), creates `~/Pictures`, refreshes the desktop database
and reloads the D-Bus session config. Pass names to install a subset, e.g.
`./install.sh alacritty bash firefox`, and `--verbose` to see every file.

It is safe to re-run. Stow runs with `--no-folding`, so only individual files
are symlinked and nothing written into `~/.config/...` or `~/.local/share/...`
later ends up inside this repo. Existing regular files in `$HOME` are never
overwritten. Any package that would replace one is skipped, the rest are
installed, and the script lists what it skipped at the end. Move or merge
those files, then re-run with just those package names.

The one exception is a `~/.bashrc` that is still the distro's stock copy
from `/etc/skel` (as on a new install): it's moved to `~/.bashrc.skel`,
which this repo's `.bashrc` sources, so you keep your distro's defaults.

Firefox needs a profile to exist first (start and quit it once, then run
`./install.sh firefox`), and a restart to pick up the stylesheets. galculator
must be closed while its colours are written.

### Per-machine settings

- Wallpaper: `~/Pictures/wallpaper.png` if it exists (desktop and lock
  screen), otherwise the theme's background colour.
- Display scaling and anything else specific to one machine: put it in
  `~/.config/labwc/autostart.local`, which `autostart` runs and which isn't
  part of this repo. For example:
  `wlr-randr --output eDP-1 --scale 1.4`

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
