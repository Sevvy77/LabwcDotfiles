# dotfiles

labwc + sfwbar + fuzzel + alacritty, themed **Crimson Dark** throughout (window
chrome, terminal, launcher, bar, Firefox, Nautilus, Mousepad, galculator,
Clocks, Volume Control), on Fedora Asahi Remix. LibreOffice is left stock.
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
packages.txt   # dnf package list
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
sudo dnf install $(cat packages.txt)
./install.sh
```

`install.sh` stows every package into `$HOME`, fills in the one `.desktop`
file that needs an absolute path, applies the non-stowable theme pieces
(`galculator`, `mousepad`, `firefox`), creates `~/Pictures`, refreshes the
desktop database and reloads the D-Bus session config. Pass names to install
a subset, e.g. `./install.sh alacritty bash firefox`.

It is safe to re-run. Stow runs with `--no-folding`, so only individual files
are symlinked and nothing written into `~/.config/...` or `~/.local/share/...`
later ends up inside this repo. Existing regular files in `$HOME` are never
overwritten; Stow stops with a conflict instead (move or delete them first).

Firefox needs a profile to exist first (start and quit it once), and a
restart to pick up the stylesheets. galculator must be closed while its
colours are written.

You still need to:
- Drop a wallpaper at `~/Pictures/wallpaper.png`.
- Start `labwc` on login — see `SPEC.md` section 2 (no display manager is
  configured here; login is on a tty and `labwc` is launched by hand or from
  `.bash_profile`).

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

Started from [antomfdez/LabwcDots](https://github.com/antomfdez/LabwcDots)
(GPL-3.0). The bar config and window theme have since been rewritten from
scratch; the alacritty config keeps its general shape.
