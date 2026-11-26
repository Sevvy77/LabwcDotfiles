![Crimson Dark desktop](screenshot.png)

# dotfiles

labwc + Quickshell + alacritty, themed **Crimson Dark** throughout, with nerdy TUI for volume, Bluetooth and network.
The bar, app launcher, lock screen and notifications are one
[Quickshell](https://quickshell.org) config. Installs on Fedora, Arch and
Arch-based distros (CachyOS, Omarchy, EndeavourOS...) and Debian/Ubuntu,
from a minimal TTY-only install or alongside an existing desktop.

## Quick start

Works on x86 or ARM. You need `git` and `sudo` for your user (or run
`install-packages.sh` as root and `install.sh` as your user).

Put the wallpaper you want at `~/Pictures/wallpaper.png` first, so labwc
picks it up when it launches.

```sh
git clone https://github.com/Sevvy77/LabwcDotfiles ~/dotfiles
cd ~/dotfiles
./install-packages.sh --dry-run   # optional: see what it would install
./install-packages.sh             # the software
./install.sh                      # the configs and theming
labwc                             # from a TTY, or pick "labwc" in GDM/SDDM
```

Later, `./update.sh` brings you up to date with this repo. Exit labwc with
Ctrl+Alt+Delete, `labwc --exit`, or by clicking empty desktop space and
choosing Exit.

## Layout

Each top-level directory holds files laid out relative to `$HOME`, which
`install.sh` copies into place:

```
labwc/.config/labwc/{environment,autostart,rc.xml}
quickshell/.config/quickshell/        # bar, launcher, lock screen, notifications
alacritty/.config/alacritty/alacritty.toml
wiremix/.config/wiremix/wiremix.toml  # Volume Control colours
zellij/.config/zellij/                # System Controls (Super+o) and its tab bar
bin/.local/bin/                       # audio-scope, system-controls
themes/.local/share/themes/OB-Crimson-Dark/   # labwc, GTK3 and GTK4 theme
themes/.local/share/icons/Crimson-Wine/       # red icons with Adwaita fallbacks
gtk3/, gtk4/                          # GTK settings; dark libadwaita apps
gtksourceview/                        # Mousepad editor colours
dbus/                                 # dark Nautilus/Clocks; no mako for notifications
applications/                         # launchers for the terminal apps
bash/, fish/                          # fastfetch, ~/.local/bin on PATH
fastfetch/.config/fastfetch/config.jsonc
firefox/                              # userChrome/userContent, merged into your profile
scripts/gen-gtk4-crimson.py           # regenerates the GTK4 theme (not installed)
```

`install.sh` also sets the GTK theme, icons and cursor with `gsettings`,
Mousepad's and galculator's colours, and downloads zjstatus.

## Quickshell

`~/.config/quickshell` replaces sfwbar, fuzzel, gtklock and mako. labwc's
`autostart` starts it, and saving any of its files reloads it. Colours are
in `Theme.qml`.

- **Bar**: clock (click for a calendar), workspaces, a tab per window
  (right-click for options), CPU and memory graphs (click for `top`), tray.
- **Launcher** (Super+k): search apps by name or keyword; the ones you use
  most come first.
- **Lock screen** (Super+l): checks your password the same way your login
  does.
- **Notifications** (top right): click for the app's action, right-click
  to dismiss. `quickshell ipc call notifications dismissAll`,
  `dismissNewest` and `toggleDnd` (do not disturb) replace `makoctl`.

`quickshell ipc show` lists every command.

If Quickshell crashes while the screen is locked, it **stays locked**. Go to
another TTY (Ctrl+Alt+F2), log in, and run the following, then switch back
and unlock (use `wayland-1` if that's the socket in `/run/user/$(id -u)/`):

```sh
export WAYLAND_DISPLAY=wayland-0
quickshell -d && sleep 2 && quickshell ipc call lock lock
```

## Terminal apps

Volume, Bluetooth, network and an audio scope are Rust TUI apps rather than
GTK windows. Open them from the launcher by name; each gets its own
alacritty window, with a class for labwc window rules:

| Launcher name  | App       | Replaces          | Window class        |
|----------------|-----------|-------------------|---------------------|
| Volume Control | wiremix   | pavucontrol       | `crimson-volume`    |
| Bluetooth      | bluetui   | Blueman           | `crimson-bluetooth` |
| Network        | nmrs-tui  | nm-applet / nmtui | `crimson-network`   |
| Audio Scope    | scope-tui | (new)             | `crimson-scope`     |

Audio Scope shows whichever output is playing when it starts. Tab cycles
the views, Up/Down zoom, Space pauses, `q` quits.

### System Controls (Super+o)

Bluetooth, Networks and Volume Control as tabs of one
[zellij](https://zellij.dev) session, all running at once:

| Keys                       | Does                         |
|----------------------------|------------------------------|
| Alt+←/→, Alt+h/l, or click | previous / next tab          |
| Alt+1, Alt+2, Alt+3        | Bluetooth, Networks, Volume  |
| Alt+q, or close the window | quit all three               |

Every other key goes to the app. If you quit one, Enter in its tab starts it
again. The first time (and after a zjstatus update), it asks you to allow
the [zjstatus](https://github.com/dj95/zjstatus) tab bar: press `y`, then
Alt+q. The tab icons need a Nerd Font.

## Scripts

### install-packages.sh

Installs everything the desktop needs, including what a minimal install
lacks (graphics drivers, PipeWire, Bluetooth, fonts, icons, a polkit agent),
plus fish and everyday apps: REAPER, Ardour, guitarix, Carla, qpwgraph,
GIMP and FreeCAD. It checks every package name first and lists any it
can't find instead of failing.

Options: `--dry-run`, `--yes` (don't ask to confirm), `--skip vlc,gimp`.

Quickshell needs version 0.3 or newer:

| Distro              | Quickshell comes from                     |
|---------------------|-------------------------------------------|
| Arch and Arch-based | the repos                                 |
| Fedora              | the `errornointernet/quickshell` COPR     |
| Debian 13           | trixie-backports (enabled for you)        |
| Ubuntu 26.10+       | universe                                  |
| Ubuntu 26.04        | built from source (takes a while)         |

Terminal apps your distro doesn't package are built with `cargo` into
`~/.local/bin`. nmrs-tui needs Rust 1.96+; [rustup](https://rustup.rs) gets
you one if your distro's is older.

On Ubuntu, clone to `~/dotfiles`, not `~/.dotfiles`: the snap Firefox can't
read hidden directories.

### install.sh

Copies the configs into place. The copies are yours to edit, and re-running
it is safe:

- files you haven't changed are updated;
- files you've changed are kept, with the repo's version beside them as
  `<file>.new`;
- `--force` replaces them instead, keeping yours as `<file>.bak`.

Pass names to install only some, e.g. `./install.sh alacritty firefox`;
`--verbose` shows every file. Your `~/.bashrc` only gets one line added.
Files the repo has dropped are removed, unless you've edited them.

Firefox needs a profile first (start and quit it once, then run
`./install.sh firefox`).

### update.sh

`git pull`, then `install-packages.sh`, then `install.sh --force`. Takes
the same names, `--verbose`, `--yes`, and `--no-packages` to skip the
software. Use `git pull && ./install.sh` instead to keep your changes and
merge the `.new` files yourself.

### Your own changes

- Wallpaper: `~/Pictures/wallpaper.png` (desktop and lock screen).
- Per-machine settings such as display scaling go in
  `~/.config/labwc/autostart.local`, which the repo doesn't ship, e.g.
  `wlr-randr --output eDP-1 --scale 1.4`.
- Anything else: edit the installed files in `~/.config`.
- To use fish as your login shell: `chsh -s "$(command -v fish)"`.

## Known gaps

- After a GTK4 upgrade, re-run `scripts/gen-gtk4-crimson.py`, as
  `install.sh` reminds you.
- nmrs-tui ignores its config file, and bluetui's colours are fixed in its
  code; both use the terminal's palette.
- Fedora, Debian and Ubuntu don't package a Nerd Font; install one (e.g.
  Symbols Only) for System Controls' tab icons.
- REAPER is only packaged on Arch; elsewhere, get it from
  [reaper.fm](https://www.reaper.fm).
- Web pages keep their own colours; use Dark Reader.
- The bar's window tabs list every window, whatever workspace you're on
  (labwc doesn't share that).
- No idle lock: the screen only locks with Super+l.

## License

GPL-3.0; see [`LICENSE`](LICENSE).

Started from [antomfdez/LabwcDots](https://github.com/antomfdez/LabwcDots)
(GPL-3.0).
