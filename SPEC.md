# Desktop Specification

A description of this desktop detailed enough to rebuild it from scratch on a
fresh install, without copying files from the original machine. Everything
below was read from the live system on 2026-09-21. The visual theme was then
changed to a single **Crimson Dark** theme (sections 4, 5 and 6.4), which was
applied to the live system and verified by screenshot on 2026-09-25. The
pre-change configs were backed up locally first.

> **Scope:** desktop environment, appearance, keybindings, startup, and the
> packages that make it work. **Not covered:** browser profiles, shell history,
> Claude Code state, personal files in `~/Downloads`, credentials of any kind.

---

## 1. Platform

| Item | Value |
|---|---|
| Hardware | Apple Silicon laptop (Asahi Linux), `aarch64`, 16k page kernel |
| OS | Fedora Asahi Remix 44 |
| Kernel | `7.1.13-402.asahi.fc44.aarch64+16k` |
| Display | `eDP-1`, native 2560x1600 @ 60 Hz, **scale 1.4** (reported 1.398438) |
| Session type | Wayland |
| Compositor | **labwc 0.9.6** (wlroots, stacking, Openbox-style) |
| Panel | **sfwbar 1.0~beta16** |
| Launcher | **fuzzel 1.14** |
| Terminal | **alacritty 0.17** |
| Shell | bash (Fedora default `.bashrc`, plus `fastfetch` on every interactive shell) |
| Audio | PipeWire + WirePlumber + pipewire-pulse (Fedora default, user units) |
| Default target | `multi-user.target` — **no display manager** |

This is *not* a GNOME session. GNOME apps (Nautilus, Clocks) run inside labwc.

## 2. Session startup

1. Log in on **tty1** (no autologin drop-in exists).
2. Run `labwc` by hand from bash. Nothing in `~/.bash_profile` or `~/.bashrc`
   starts it; the compositor's parent process is the login shell.
   - *Rebuild option:* add to `~/.bash_profile`:
     `[ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ] && exec labwc`
3. labwc reads `~/.config/labwc/{environment,autostart,rc.xml}`.

### 2.1 `labwc/environment`

```
XKB_DEFAULT_LAYOUT=us
XDG_SESSION_TYPE=wayland
GDK_BACKEND=wayland
QT_QPA_PLATFORM=wayland
```

### 2.2 `labwc/autostart` (run in order, all backgrounded except `wlr-randr`)

```
alacritty &
firefox &
sfwbar &
wlr-randr --output eDP-1 --scale 1.4
swaybg -i ~/Pictures/wallpaper.png -m fill &
```

Behaviour: a terminal, Firefox and the bar open at login; output scale is set
to 1.4; wallpaper is `~/Pictures/wallpaper.png` (here a copy of the personal
image, 1672x941), scaled with `fill`. **The wallpaper file is a
personal asset and is not part of this spec or the repo**; substitute any image.

## 3. Keybindings (`labwc/rc.xml`)

`<keyboard><default /></keyboard>` keeps labwc's built-in bindings; these are
added on top. `W` = Super, `C` = Ctrl, `A` = Alt.

| Keys | Action |
|---|---|
| `W-k` | `fuzzel` (app launcher) |
| `W-l` | `swaylock -i ~/Pictures/wallpaper.png --scaling fill` (lock, wallpaper as background) |
| `W-q` | Close focused window |
| `W-p` | Region screenshot: `grim -g "$(slurp)" ~/Pictures/screenshot-YYYYmmdd-HHMMSS.png` |
| `C-A-BackSpace` | Exit labwc |
| `XF86MonBrightnessUp` | `brightnessctl set +5%` |
| `XF86MonBrightnessDown` | `brightnessctl set 5%-` |

Window theme is set with `<theme><name>OB-Crimson-Dark</name></theme>`.

## 4. Visual design: Crimson Dark

The whole desktop uses one palette, **Crimson Dark**: red-tinted near-black
surfaces, warm off-white text, and crimson as the single accent (borders,
focus, selection, hover). Every themed component — window chrome, terminal,
launcher, bar, Firefox (6.5), Volume Control (6.2), and the Nautilus /
Mousepad / galculator / Clocks windows (6.4) — uses it. LibreOffice is
deliberately left stock.

| Role | Hex |
|---|---|
| Terminal bg | `#1f1416` |
| Window chrome / menu bg | `#1a1012` |
| Panel-ish surfaces (menu titles, inactive buttons) | `#2e1b1e` |
| Selection bg (launcher, terminal selection) | `#3a2226` |
| Bar/tooltip bg | `#140c0d` |
| Foreground text | `#e8d5d0` (terminal, bar) / `#f5e9e6` (window titles, text on accent) |
| Muted / inactive text | `#7a5a5e` |
| **Accent — crimson** (borders, focused item, active menu item) | `#c0303a` |
| Accent hover / active / pressed | `#e5484d` |
| Accent bright (matches, highlights) | `#ff7a7f` |
| Deep red (desktop button, destructive actions) | `#8f2530` |
| Amber | `#e0a867` |
| Rose / magenta | `#c77da0` |
| Olive green (terminal only) | `#a3b07a` |
| Steel blue (terminal only) | `#7f9cb4` |
| Sage cyan (terminal only) | `#86b0a8` |
| Black / bright black | `#3a2528` |

The green/blue/cyan entries exist only so terminal programs keep
distinguishable ANSI colours; nothing else in the desktop uses them.

Text on the crimson accent is always light (`#f5e9e6`, ~5:1 contrast), never
dark.

Font: **JetBrains Mono Regular** (terminal), `Sans 12px` (bar labels).
System GTK font is left at the GNOME default (Adwaita Sans 11, Adwaita Mono 11).

### 4.1 Window theme `~/.local/share/themes/OB-Crimson-Dark/labwc/themerc`

Written from scratch on 2026-09-25 against `labwc-theme(5)`, using only keys
labwc 0.9 reads (53 lines). It replaced a recolour of Archcraft's
`OB-Everforest-Dark` (238 lines), most of which labwc silently ignored:
per-state button backgrounds, handle/grip, text shadows, shade/desktop button
colours (labwc's default titlebar only shows iconify, max and close), the
Openbox `osd.hilight` alt-tab keys, and the Openbox names `padding.width` /
`padding.height`. Because labwc never read those two, the titlebar has always
used labwc's default padding; the rewrite keeps it that way on purpose.

- Frame: `border.width 2`; active border `#c0303a`, inactive `#2e1b1e`;
  titlebar `#1a1012`; title text left-aligned, `#f5e9e6` / inactive `#7a5a5e`.
- Buttons when focused: iconify `#e0a867`, maximise `#c0303a`, close
  `#e5484d`, window icon/menu `#f5e9e6`; all `#2e1b1e` when unfocused. Hover
  shows a translucent hot-red overlay (`#e5484d33`), labwc's only hover style.
- Menus: 8px border in the chrome colour; title `#2e1b1e` / `#e5484d`; items
  `#1a1012` / `#f5e9e6`; active item crimson with bright text.
- Alt-tab switcher: `#1a1012` with a 6px `#2e1b1e` border; the selected entry
  gets a crimson border and a translucent crimson fill (new: the old theme's
  alt-tab keys were Openbox-only, so this was labwc's default before).

Verified 2026-09-25: titlebars are pixel-identical before and after the
rewrite. Menus and the alt-tab switcher were not screenshotted.

```
# Crimson Dark: labwc window theme
# Uses only keys documented in labwc-theme(5) for labwc 0.9.
# Titlebar layout is labwc's default (icon:iconify,max,close).

# Palette
#   #140c0d bar/tooltip   #1a1012 chrome   #2e1b1e surface
#   #7a5a5e muted text    #f5e9e6 bright text
#   #c0303a crimson       #e5484d hot red  #e0a867 amber

# Frame
border.width: 2
window.active.border.color: #c0303a
window.inactive.border.color: #2e1b1e
window.active.title.bg.color: #1a1012
window.inactive.title.bg.color: #1a1012

# Title text
window.label.text.justify: left
window.active.label.text.color: #f5e9e6
window.inactive.label.text.color: #7a5a5e

# Buttons: one colour per function when focused, all dimmed when not
window.active.button.unpressed.image.color: #f5e9e6
window.active.button.iconify.unpressed.image.color: #e0a867
window.active.button.max.unpressed.image.color: #c0303a
window.active.button.close.unpressed.image.color: #e5484d
window.inactive.button.unpressed.image.color: #2e1b1e
window.button.hover.bg.color: #e5484d33

# Root and window menus
menu.border.width: 8
menu.border.color: #1a1012
menu.overlap.x: -13
menu.overlap.y: 8
menu.title.bg.color: #2e1b1e
menu.title.text.color: #e5484d
menu.title.text.justify: center
menu.items.bg.color: #1a1012
menu.items.text.color: #f5e9e6
menu.items.active.bg.color: #c0303a
menu.items.active.text.color: #f5e9e6
menu.separator.width: 1
menu.separator.padding.width: 0
menu.separator.padding.height: 2
menu.separator.color: #2e1b1e

# Alt-tab window switcher
osd.bg.color: #1a1012
osd.border.color: #2e1b1e
osd.border.width: 6
osd.label.text.color: #f5e9e6
osd.window-switcher.style-classic.item.active.border.color: #c0303a
osd.window-switcher.style-classic.item.active.bg.color: #c0303a40
```

### 4.2 Terminal `alacritty/alacritty.toml`

- Font `JetBrains Mono`, style Regular. Window opacity **0.9**, size **124 cols x 30 lines**.
- Colours: primary bg `#1f1416`, fg `#e8d5d0`; cursor `#e5484d` with text
  `#1f1416`; selection bg `#3a2226`, text `#f5e9e6`. Normal and bright ANSI sets
  are **identical**: black `#3a2528`, red `#e5484d`, green `#a3b07a`,
  yellow `#e0a867`, blue `#7f9cb4`, magenta `#c77da0`, cyan `#86b0a8`,
  white `#e8d5d0`.
- One custom binding: `Shift+Return` sends `ESC` + `CR` (`"\u001B\r"`), i.e.
  Alt+Enter-style newline, used by CLI tools that treat it as "insert newline".

### 4.3 Launcher `fuzzel/fuzzel.ini`

```
[colors]
background=1f1416dd   text=e8d5d0ff
match=ff7a7fff        selection=3a2226dd
selection-text=f5e9e6ff   selection-match=ff7a7fff
border=c0303aff
```

This replaces the old Dracula colours, so the launcher now matches the rest of
the desktop.

## 5. Panel: sfwbar (`sfwbar/sfwbar.config`)

Single bar on every output (`mirror = "*"`), anchored bottom, minimum height
31px, background `rgba(20,12,13,0.85)` (`#140c0d` at 85%). Includes widgets shipped with the sfwbar
package in `/usr/share/sfwbar/`, so a rebuild needs that package's data files.
The config was rewritten from scratch on 2026-09-25 (169 lines, down from
246): only CSS rules that affect a widget on this bar remain, organised by
widget, with the palette as named colours. The bar renders pixel-identical to
before (verified by screenshot).

**Layout, left to right:**

1. Clock: `Time("%H:%M")`, click pops up the `cal.widget` calendar
2. Taskbar: one row, icons + labels, grouped by app, sorted, stretches to fill.
   Right-click opens the `winops` menu, middle-click closes, drag focuses.
3. `cpu.widget` (chart), `memory.widget` (bar); clicking either opens `top`
   in `$Term` (`alacritty`), which is why `Set Term` stays in the config
4. System tray

**Other behaviour:** the config keeps a `switcher` section (icons only,
5 columns, 700ms) even though nothing on labwc opens sfwbar's switcher:
**in sfwbar 1.0~beta16 the bar is not drawn at all without it** (verified
2026-09-25 by removing it; the bar vanished, and restoring only this section
brought it back). There is no `placer` section: sfwbar can't move windows on
labwc, which places new windows itself. No icon theme is set, so the bar uses
the system default.

**Styling:** `theme_text_color #E8D5D0`, `theme_bg_color #140C0D`,
`theme_fg_color`/`borders #C0303A`. Taskbar items are rounded (4px) on a
`rgba(192,48,58,0.12)` fill (faint crimson), hover `rgba(229,72,77,0.25)`; the
**focused** item is solid crimson `#C0303A` with light `#F5E9E6` label.
CPU chart line and memory bar fill are
`#E5484D` with 1px `#C0303A` borders; menus have a 2px crimson border on
`#140C0D`, with the hovered menu item `#C0303A` / `#F5E9E6`. Clock text
`#E8D5D0`; the calendar popup
gets the crimson border (sfwbar's `cal.widget` has no "today" style, so the
current day is not highlighted). After editing, restart the bar
(`pkill -x sfwbar; sfwbar &`); labwc picks up the window theme with `labwc -r`.

**Deliberately disabled** (commented out in the config, with a note): the
`bluez`, `network-module` and `volume` widgets. In this sfwbar version their
channel-ack pattern recurses forever, pinning the CPU and freezing the bar.
Do not re-enable them without testing. Volume/network/Bluetooth are handled
with `pavucontrol`, NetworkManager and `blueman` instead.

## 6. Application defaults

| Purpose | App |
|---|---|
| Browsers | Firefox (autostarted; Crimson Dark, see 6.5), Chromium |
| Files | Nautilus (Crimson Dark, see 6.4) |
| Text editor | Mousepad (Crimson Dark, see 6.4) |
| Calculator | galculator (Crimson Dark, see 6.4) |
| Audio mixer | pavucontrol (Crimson Dark, see 6.2) |
| Bluetooth | blueman (forced dark, see 6.2) |
| Office | LibreOffice (stock theme, deliberately unthemed) |
| Media | VLC |
| Clock | GNOME Clocks (forced dark, see 6.1; picks up Crimson Dark, see 6.4) |
| Screenshots | grim + slurp |
| System info | fastfetch (runs at the end of `~/.bashrc`) |

No GTK settings files exist (`~/.config/gtk-3.0` is empty), so GTK apps follow
GNOME defaults: **Adwaita, light**. The desktop is dark only where configured
below; libadwaita apps are light unless overridden. Nothing global is set on
purpose, so that LibreOffice (which draws with GTK3) keeps its stock look.

### 6.1 GNOME Clocks dark mode

`~/.local/share/applications/org.gnome.clocks.desktop`, copied from
`/usr/share/applications/`, with two edits:

```
Exec=env ADW_DEBUG_COLOR_SCHEME=prefer-dark gnome-clocks
DBusActivatable=false
```

`DBusActivatable=false` is required, otherwise the launcher bypasses `Exec`.
`GTK_THEME=Adwaita:dark` does **not** work (it switches to the legacy GTK
theme, not libadwaita's dark style). Alternative for the whole desktop:
`gsettings set org.gnome.desktop.interface color-scheme prefer-dark`.

### 6.2 Dark mode for Blueman, Crimson Dark for pavucontrol

Neither app follows a dark setting on this desktop (no GTK settings exist), so
each gets a per-user launcher override in `~/.local/share/applications/`,
copied from `/usr/share/applications/` with `Exec` prefixed:

| Override file | Exec |
|---|---|
| `org.pulseaudio.pavucontrol.desktop` | `env GTK_THEME=OB-Crimson-Dark pavucontrol` |
| `blueman-manager.desktop` | `env GTK_THEME=Adwaita:dark blueman-manager` |
| `blueman-adapters.desktop` | `env GTK_THEME=Adwaita:dark blueman-adapters` |

Why `GTK_THEME` here but `ADW_DEBUG_COLOR_SCHEME` for Clocks (6.1): pavucontrol
6.2 is plain **GTK4 without libadwaita** and Blueman 2.4 is **GTK3**, so the
GTK theme variant is the correct switch. Clocks is libadwaita, which ignores it.
No `DBusActivatable` edit is needed; none of these launchers use D-Bus activation.

Verified by screenshot against a control run without the variable: the
overridden windows render dark, the control renders light.

**pavucontrol's Crimson Dark theme** is
`~/.local/share/themes/OB-Crimson-Dark/gtk-4.0/gtk.css`. For a plain GTK4 app,
`GTK_THEME=<name>` loads that file *instead of* GTK's built-in stylesheet, and
that stylesheet hard-codes every colour (blue `#15539e` accent, fixed greys),
so overriding a few named colours or CSS variables leaves blue tabs and
sliders. The file is therefore **generated**: `scripts/gen-gtk4-crimson.py`
(below) takes GTK's own `Default-dark.css`, gives every neutral grey a red
tint at the same lightness, maps the blue accent family onto the crimson
palette, leaves status colours (green/orange/red) alone, and points the
stylesheet's `assets/…` image references back into GTK's resources (without
that, slider knobs and checkmarks disappear). Regenerate after a GTK4 upgrade:

```
python3 scripts/gen-gtk4-crimson.py > ~/.local/share/themes/OB-Crimson-Dark/gtk-4.0/gtk.css
```

Verified by screenshot on 2026-09-25 (GTK 4.22.5): tabs, slider fills,
buttons, dropdowns and backgrounds are crimson/red-tinted, with no GTK warnings
(the unfixed asset paths caused four). Slider knobs stay grey: they are
bitmaps. The generator needs `python3-gobject`.

Caveats:
- Launching from a terminal (`pavucontrol`, `blueman-manager`) bypasses the
  override. Prefix with `GTK_THEME=OB-Crimson-Dark` (pavucontrol) or
  `GTK_THEME=Adwaita:dark` (Blueman) there too.
- `blueman-applet` is not started (labwc does not run `/etc/xdg/autostart`).
  If you add it to `autostart`, launch it as
  `env GTK_THEME=Adwaita:dark blueman-applet &` so windows it spawns inherit the
  variable.
- A global alternative for all GTK3 apps is
  `~/.config/gtk-3.0/settings.ini` with `gtk-application-prefer-dark-theme=1`,
  but that would also restyle sfwbar and galculator, so it was not used.

`scripts/gen-gtk4-crimson.py`:

```python
#!/usr/bin/env python3
"""Generate the Crimson Dark GTK4 theme (for plain-GTK4 apps like pavucontrol).

Recolours GTK's own built-in dark stylesheet, so every widget is covered:
neutral greys get a red tint at the same lightness, the blue accent family
becomes crimson, and status colours (green/orange/red) are left alone.
Re-run after a GTK4 upgrade:

    python3 gen-gtk4-crimson.py > ~/.local/share/themes/OB-Crimson-Dark/gtk-4.0/gtk.css
"""
import colorsys, re, sys
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gio, Gtk  # noqa: F401  (importing Gtk registers its resources)

SRC = "/org/gtk/libgtk/theme/Default/Default-dark.css"
css = Gio.resources_lookup_data(SRC, 0).get_data().decode()

# Exact anchors onto the palette (SPEC.md section 4).
EXACT = {
    (0x15, 0x53, 0x9e): (0xc0, 0x30, 0x3a),  # selected / accent bg -> crimson
    (0x35, 0x84, 0xe4): (0xe5, 0x48, 0x4d),  # accent / links       -> accent hover
    (0x1f, 0x76, 0xe1): (0xe5, 0x48, 0x4d),
    (0xee, 0xee, 0xec): (0xe8, 0xd5, 0xd0),  # foreground
    (0x91, 0x91, 0x90): (0x9a, 0x7a, 0x7e),  # dim label
}
HUE = 353 / 360

def recolour(r, g, b):
    if (r, g, b) in EXACT:
        return EXACT[(r, g, b)]
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if s < 0.08 or max(r, g, b) - min(r, g, b) < 8:        # neutral grey
        if l in (0.0, 1.0):
            return r, g, b
        s2 = 0.22 if l < 0.5 else 0.14
        nr, ng, nb = colorsys.hls_to_rgb(HUE, l, s2)
    elif 0.52 < h < 0.72:                                    # blue family
        nr, ng, nb = colorsys.hls_to_rgb(HUE, l, min(1.0, s * 0.9 + 0.1))
    else:                                                    # status colours
        return r, g, b
    return round(nr * 255), round(ng * 255), round(nb * 255)

def hex_sub(m):
    v = m.group(1)
    if len(v) == 3:
        v = "".join(c * 2 for c in v)
    r, g, b = (int(v[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02x%02x%02x" % recolour(r, g, b)

def rgba_sub(m):
    fn, r, g, b, rest = m.group(1), *map(int, m.group(2, 3, 4)), m.group(5)
    nr, ng, nb = recolour(r, g, b)
    return f"{fn}({nr}, {ng}, {nb}{rest})"

# Assets are referenced relative to the stylesheet; point them back into GTK.
css = css.replace('url("assets/', 'url("resource:///org/gtk/libgtk/theme/Default/assets/')
css = re.sub(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b", hex_sub, css)
css = re.sub(r"\b(rgba?)\(\s*(\d+),\s*(\d+),\s*(\d+)([^)]*)\)", rgba_sub, css)

sys.stdout.write(f"""/* Crimson Dark for plain GTK4 apps (pavucontrol), used via
   GTK_THEME=OB-Crimson-Dark. GENERATED by gen-gtk4-crimson.py from GTK
   {Gtk.get_major_version()}.{Gtk.get_minor_version()}.{Gtk.get_micro_version()}'s {SRC}; do not edit by hand. */

""")
sys.stdout.write(css)
sys.stdout.write("""

/* Exact palette surfaces on top of the recolour. */
window, window.background, dialog { background-color: #1a1012; color: #e8d5d0; }
.view, textview text, listview, list { background-color: #1f1416; color: #e8d5d0; }
notebook > header { background-color: #140c0d; }
""")
```

### 6.3 Custom launchers

- `spotify-web.desktop`: Chromium in app mode for `https://open.spotify.com`,
  own profile dir, `StartupWMClass=spotify-web`, generic audio icon.
  Use `$HOME`, not an absolute path, when publishing.
- `claude-code-url-handler.desktop`: registers `claude-cli://` URLs
  (`mimeapps.list`). Created by Claude Code; omit from the repo.

### 6.4 Crimson Dark for Nautilus, Mousepad and galculator

Each app gets the section 4 palette through whatever its toolkit reads, scoped
so nothing else changes (in particular, **LibreOffice stays stock**):

| App | Toolkit | Mechanism |
|---|---|---|
| Nautilus 50 | GTK4 + libadwaita 1.9 | forced dark (like Clocks, 6.1) + libadwaita colour variables in `~/.config/gtk-4.0/gtk.css` |
| Mousepad 0.7 | GTK3 + GtkSourceView 4 | `GTK_THEME=OB-Crimson-Dark` on the launcher + a GtkSourceView scheme for the editing area |
| galculator 2.1 | GTK3 | `GTK_THEME=OB-Crimson-Dark` on the launcher + its own display colours in `galculator.conf` |

Verified by screenshot on 2026-09-25, running each app against these files
from a scratch directory: all three render in the palette, and Mousepad's
syntax highlighting uses it too.

#### Nautilus

1. `~/.config/gtk-4.0/gtk.css` (below). It is wrapped in
   `@media (prefers-color-scheme: dark)`, so it only restyles libadwaita apps
   that are running dark. On this desktop that is Nautilus and **GNOME Clocks**,
   which becomes crimson as well. pavucontrol (plain GTK4) is not affected by
   this file; it has its own theme (6.2). Light-mode libadwaita apps are
   untouched.
2. `~/.local/share/applications/org.gnome.Nautilus.desktop`, copied from
   `/usr/share/applications/`, with both `Exec` lines prefixed
   (`Exec=env ADW_DEBUG_COLOR_SCHEME=prefer-dark nautilus --new-window %U`, and
   the same without `%U` in the New Window action) and
   `DBusActivatable=false`, exactly as for Clocks.
3. Nautilus is also started over D-Bus (e.g. "show in folder" from a browser),
   which runs `/usr/share/dbus-1/services/org.gnome.Nautilus.service` and
   skips the launcher. Override it with
   `~/.local/share/dbus-1/services/org.gnome.Nautilus.service`:
   ```
   [D-BUS Service]
   Name=org.gnome.Nautilus
   Exec=/usr/bin/env ADW_DEBUG_COLOR_SCHEME=prefer-dark /usr/bin/nautilus --gapplication-service
   ```
   The session bus reads `$XDG_DATA_HOME/dbus-1/services` before `/usr/share`.
   Reload the bus afterwards (`busctl --user call org.freedesktop.DBus
   /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig`, or log out).
   Verified: a D-Bus-activated Nautilus carries `ADW_DEBUG_COLOR_SCHEME`.
   Whichever process starts first owns every Nautilus window, so if it
   starts without the variable, all its windows are light until it exits.

`~/.config/gtk-4.0/gtk.css`:

```css
/* Crimson Dark for libadwaita apps. Only applies to apps running in dark
   mode (Nautilus, Clocks are forced dark); light-mode apps are untouched. */
@media (prefers-color-scheme: dark) {
  :root {
    --accent-bg-color: #c0303a;
    --accent-fg-color: #f5e9e6;
    --accent-color: #ff7a7f;
    --destructive-bg-color: #8f2530;
    --destructive-fg-color: #f5e9e6;
    --destructive-color: #ff7a7f;

    --window-bg-color: #1a1012;
    --window-fg-color: #e8d5d0;
    --view-bg-color: #1f1416;
    --view-fg-color: #e8d5d0;
    --headerbar-bg-color: #140c0d;
    --headerbar-fg-color: #e8d5d0;
    --headerbar-backdrop-color: #1a1012;
    --headerbar-shade-color: rgba(0, 0, 0, 0.5);
    --sidebar-bg-color: #140c0d;
    --sidebar-fg-color: #e8d5d0;
    --sidebar-backdrop-color: #1a1012;
    --sidebar-shade-color: rgba(0, 0, 0, 0.4);
    --secondary-sidebar-bg-color: #1a1012;
    --secondary-sidebar-fg-color: #e8d5d0;
    --secondary-sidebar-backdrop-color: #1a1012;
    --card-bg-color: #2e1b1e;
    --card-fg-color: #e8d5d0;
    --dialog-bg-color: #1f1416;
    --dialog-fg-color: #e8d5d0;
    --popover-bg-color: #2e1b1e;
    --popover-fg-color: #e8d5d0;
    --thumbnail-bg-color: #2e1b1e;
    --thumbnail-fg-color: #e8d5d0;
    --border-color: rgba(192, 48, 58, 0.25);
  }
}
```

#### Mousepad and galculator (GTK3)

A GTK3 theme lives alongside the labwc theme, in the same directory:
`~/.local/share/themes/OB-Crimson-Dark/gtk-3.0/gtk.css`. It imports GTK's
built-in Adwaita dark and recolours it. It is **only** applied through
`GTK_THEME` on these two launchers, never globally, so other GTK3 apps
(LibreOffice, sfwbar, Blueman) are unaffected.

Launcher overrides in `~/.local/share/applications/`, copied from
`/usr/share/applications/` with `Exec` prefixed:

| Override file | Exec |
|---|---|
| `org.xfce.mousepad.desktop` | `env GTK_THEME=OB-Crimson-Dark mousepad %U` (and the `--preferences` action likewise) |
| `galculator.desktop` | `env GTK_THEME=OB-Crimson-Dark galculator` |

Neither uses D-Bus activation, so no other edits are needed. As with 6.2,
starting either app from a terminal skips the override; prefix it by hand.

**Mousepad editing area.** GtkSourceView draws the text area with its own
colours and ignores the GTK theme there, so without a scheme it stays grey.
Install
`~/.local/share/gtksourceview-4/styles/crimson-dark.xml` (below) and select it:

```
gsettings set org.xfce.mousepad.preferences.view color-scheme crimson-dark
gsettings set org.xfce.mousepad.preferences.view show-line-numbers true      # optional
gsettings set org.xfce.mousepad.preferences.view highlight-current-line true # optional
```

**galculator display.** The number display ignores the theme and uses colours
from `~/.config/galculator/galculator.conf`. Set these keys and leave the
rest alone (galculator rewrites the file when it exits, so edit it while
galculator is closed):

```
display_bkg_color="#1f1416"
display_result_color="#e8d5d0"
display_stack_color="#e8d5d0"
display_module_active_color="#e5484d"
display_module_inactive_color="#7a5a5e"
```

`~/.local/share/themes/OB-Crimson-Dark/gtk-3.0/gtk.css`:

```css
/* Crimson Dark for GTK3 apps launched with GTK_THEME=OB-Crimson-Dark
   (Mousepad, galculator). Adwaita dark underneath, recoloured on top. */
@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");

@define-color theme_bg_color #1a1012;
@define-color theme_fg_color #e8d5d0;
@define-color theme_base_color #1f1416;
@define-color theme_text_color #e8d5d0;
@define-color theme_selected_bg_color #c0303a;
@define-color theme_selected_fg_color #f5e9e6;

window, .background, dialog { background-color: #1a1012; color: #e8d5d0; }

headerbar, .titlebar, menubar, toolbar, .toolbar, statusbar {
  background: #140c0d; color: #e8d5d0; border-color: #2e1b1e;
  box-shadow: none;
}
headerbar:backdrop, .titlebar:backdrop { background: #1a1012; }

.view, textview, textview text, iconview, treeview.view {
  background-color: #1f1416; color: #e8d5d0;
}
textview border { background-color: #1a1012; color: #7a5a5e; }
treeview.view header button { background: #1a1012; color: #e8d5d0; border-color: #2e1b1e; }

selection, *:selected, .view:selected, textview text selection,
treeview.view:selected, entry selection {
  background-color: #c0303a; color: #f5e9e6;
}

entry, spinbutton:not(.vertical) {
  background: #1f1416; color: #e8d5d0; border-color: #3a2226; box-shadow: none;
}
entry:focus, spinbutton:focus-within { border-color: #c0303a; box-shadow: inset 0 0 0 1px #c0303a; }

button {
  background: #2e1b1e; color: #e8d5d0; border-color: #3a2226;
  box-shadow: none; text-shadow: none; -gtk-icon-shadow: none;
}
button:hover { background: #3a2226; border-color: #c0303a; }
button:active, button:checked, button.suggested-action {
  background: #c0303a; color: #f5e9e6; border-color: #8f2530;
}
button.destructive-action { background: #8f2530; color: #f5e9e6; }
headerbar button:not(:hover):not(:active):not(:checked),
toolbar button:not(:hover):not(:active):not(:checked) {
  background: transparent; border-color: transparent;
}

menu, .menu, .context-menu, popover, popover.background {
  background: #1f1416; color: #e8d5d0; border-color: #3a2226;
}
menu menuitem:hover, menubar > menuitem:hover, modelbutton:hover {
  background: #c0303a; color: #f5e9e6;
}

notebook > header { background: #140c0d; border-color: #2e1b1e; }
notebook > header tab { color: #7a5a5e; }
notebook > header tab:checked { color: #e8d5d0; box-shadow: inset 0 -3px #c0303a; }
notebook > header.top tab:hover { box-shadow: inset 0 -3px #8f2530; }
notebook > stack:not(:only-child) { background: #1f1416; }

scrollbar { background: #1a1012; border-color: #2e1b1e; }
scrollbar slider { background: #3a2226; }
scrollbar slider:hover { background: #7a5a5e; }
scrollbar slider:active { background: #c0303a; }

scale highlight, progressbar progress, levelbar block.filled {
  background: #c0303a; border-color: #c0303a;
}
switch:checked { background: #c0303a; border-color: #8f2530; }
check:checked, radio:checked, check:indeterminate, radio:indeterminate {
  background: #c0303a; color: #f5e9e6; border-color: #8f2530;
}

separator { background: #2e1b1e; }
tooltip, tooltip.background { background: #140c0d; color: #e8d5d0; border: 1px solid #c0303a; }
```

`~/.local/share/gtksourceview-4/styles/crimson-dark.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- Crimson Dark: GtkSourceView style scheme for Mousepad -->
<style-scheme id="crimson-dark" name="Crimson Dark" version="1.0">
  <description>Dark red scheme matching the Crimson Dark desktop palette</description>

  <color name="bg"        value="#1f1416"/>
  <color name="bg-dim"    value="#1a1012"/>
  <color name="surface"   value="#2e1b1e"/>
  <color name="selection" value="#3a2226"/>
  <color name="fg"        value="#e8d5d0"/>
  <color name="fg-bright" value="#f5e9e6"/>
  <color name="muted"     value="#7a5a5e"/>
  <color name="crimson"   value="#c0303a"/>
  <color name="red"       value="#e5484d"/>
  <color name="red-light" value="#ff7a7f"/>
  <color name="amber"     value="#e0a867"/>
  <color name="rose"      value="#c77da0"/>
  <color name="olive"     value="#a3b07a"/>
  <color name="sage"      value="#86b0a8"/>

  <!-- editor chrome -->
  <style name="text"                 foreground="fg" background="bg"/>
  <style name="selection"            foreground="fg-bright" background="crimson"/>
  <style name="selection-unfocused"  foreground="fg" background="selection"/>
  <style name="cursor"               foreground="red"/>
  <style name="secondary-cursor"     foreground="muted"/>
  <style name="current-line"         background="surface"/>
  <style name="line-numbers"         foreground="muted" background="bg-dim"/>
  <style name="current-line-number"  foreground="red" background="surface"/>
  <style name="right-margin"         foreground="crimson" background="bg-dim"/>
  <style name="bracket-match"        foreground="fg-bright" background="crimson" bold="true"/>
  <style name="bracket-mismatch"     foreground="fg-bright" background="selection" underline="error"/>
  <style name="search-match"         foreground="bg" background="amber"/>
  <style name="draw-spaces"          foreground="selection"/>
  <style name="background-pattern"   background="bg-dim"/>

  <!-- syntax -->
  <style name="def:comment"          foreground="muted" italic="true"/>
  <style name="def:shebang"          foreground="muted" bold="true"/>
  <style name="def:doc-comment-element" foreground="muted" bold="true"/>
  <style name="def:keyword"          foreground="red" bold="true"/>
  <style name="def:builtin"          foreground="red-light"/>
  <style name="def:type"             foreground="rose"/>
  <style name="def:function"         foreground="amber"/>
  <style name="def:identifier"       foreground="fg"/>
  <style name="def:string"           foreground="olive"/>
  <style name="def:special-char"     foreground="sage"/>
  <style name="def:constant"         foreground="red-light"/>
  <style name="def:number"           foreground="amber"/>
  <style name="def:preprocessor"     foreground="rose"/>
  <style name="def:statement"        foreground="red"/>
  <style name="def:operator"         foreground="fg-bright"/>
  <style name="def:heading"          foreground="red" bold="true"/>
  <style name="def:emphasis"         italic="true"/>
  <style name="def:strong-emphasis"  bold="true"/>
  <style name="def:link-text"        foreground="red-light" underline="single"/>
  <style name="def:inline-code"      foreground="olive"/>
  <style name="def:error"            foreground="fg-bright" background="crimson"/>
  <style name="def:warning"          foreground="bg" background="amber"/>
  <style name="def:note"             foreground="bg" background="rose"/>
  <style name="diff:added-line"      foreground="olive"/>
  <style name="diff:removed-line"    foreground="red"/>
  <style name="diff:changed-line"    foreground="amber"/>
</style-scheme>
```

### 6.5 Firefox

Firefox 156 with a third-party theme (currently **Terracotta**, earlier
**Biscuit**) and the **Dark Reader** extension. The Crimson Dark look is
layered on top with profile stylesheets and overrides whichever theme is
active, so rolling back means deleting `chrome/` (and the `user.js` lines).

Files in the profile directory
(`~/.config/mozilla/firefox/<profile>/`, the one named by the `[Install…]`
`Default=` line in `profiles.ini`, usually `<random>.default-release`):

| File | Does |
|---|---|
| `user.js` | enables `userChrome.css`/`userContent.css` loading; asks pages for dark mode |
| `chrome/userChrome.css` | browser UI: tab strip, tabs, toolbars, URL bar, menus, panels, sidebar |
| `chrome/userContent.css` | Firefox's own pages: new tab / home / private browsing, `about:blank` |

Notes:
- Firefox reads all three only at startup; restart it after changes.
- Theme colours are overridden with `!important` custom properties, set on
  both `:root` and the toolbox/toolbars (Firefox applies theme colours to the
  toolbars themselves, so `:root` alone loses). A few things Biscuit colours
  without the variables (tab label and outline, toolbar icon tint, URL-bar
  focus ring) are styled directly.
- Web page content keeps its own colours; Dark Reader darkens it. Its colours
  are not part of this spec.
- The toolbars are also painted directly: the `--toolbar-bgcolor` override
  alone doesn't reach them. That went unnoticed under Biscuit, whose own
  toolbar is near-black, and showed up under Terracotta (`#99250b` toolbar).
- Verified by screenshot on 2026-09-25 in copies of the real profile, with
  Biscuit and then Terracotta active: frame, tabs, toolbar, bookmarks bar, URL
  bar and new-tab page (cards, weather widget) render in the palette; less
  than 0.1% of the toolbar area kept Terracotta's orange.
- Other, unused profiles are not themed.

`user.js`:

```js
// Crimson Dark: let Firefox load chrome/userChrome.css and chrome/userContent.css.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Ask sites and Firefox pages for their dark variant.
user_pref("layout.css.prefers-color-scheme.content-override", 0);
```

`chrome/userChrome.css`:

```css
/* Crimson Dark for the Firefox UI (tabs, toolbars, URL bar, menus, panels).
   Works on top of any Firefox theme; needs
   toolkit.legacyUserProfileCustomizations.stylesheets = true (see user.js). */

:root, :root[lwtheme], :root:-moz-lwtheme,
/* Firefox also applies theme colours on the toolbox and toolbars themselves */
#navigator-toolbox, #navigator-toolbox toolbar, #TabsToolbar, #nav-bar, #PersonalToolbar {
  /* frame / tab strip */
  --lwt-accent-color: #140c0d !important;
  --lwt-accent-color-inactive: #140c0d !important;
  --lwt-text-color: #e8d5d0 !important;
  --lwt-header-image: none !important;
  --lwt-additional-images: none !important;
  --lwt-tab-line-color: #c0303a !important;
  --lwt-toolbarbutton-icon-fill: #e8d5d0 !important;
  --toolbox-bgcolor: #140c0d !important;
  --toolbox-bgcolor-inactive: #140c0d !important;
  --toolbox-textcolor: #e8d5d0 !important;
  --toolbox-textcolor-inactive: #9a7a7e !important;

  /* tabs */
  --tab-selected-bgcolor: #2e1b1e !important;
  --tab-selected-textcolor: #f5e9e6 !important;
  --tab-hover-background-color: rgba(229, 72, 77, 0.15) !important;
  --tab-selected-outline-color: #c0303a !important;
  --tab-line-color: #c0303a !important;
  --lwt-tab-text: #f5e9e6 !important;
  --lwt-selected-tab-background-color: #2e1b1e !important;
  --tab-loading-fill: #e5484d !important;

  /* toolbars and buttons */
  --toolbar-bgcolor: #1a1012 !important;
  --toolbar-color: #e8d5d0 !important;
  --toolbarbutton-icon-fill: #e8d5d0 !important;
  --toolbarbutton-hover-background: rgba(229, 72, 77, 0.2) !important;
  --toolbarbutton-active-background: rgba(229, 72, 77, 0.35) !important;
  --toolbarseparator-color: #2e1b1e !important;
  --chrome-content-separator-color: #2e1b1e !important;

  /* URL / search field */
  --toolbar-field-background-color: #1f1416 !important;
  --toolbar-field-color: #e8d5d0 !important;
  --toolbar-field-border-color: #3a2226 !important;
  --toolbar-field-focus-background-color: #1f1416 !important;
  --toolbar-field-focus-color: #f5e9e6 !important;
  --toolbar-field-focus-border-color: #c0303a !important;
  --urlbar-box-bgcolor: #2e1b1e !important;
  --urlbar-box-hover-bgcolor: #3a2226 !important;
  --urlbar-box-active-bgcolor: #c0303a !important;
  --urlbarView-highlight-background: #c0303a !important;
  --urlbarView-highlight-color: #f5e9e6 !important;
  --urlbarView-hover-background: rgba(229, 72, 77, 0.15) !important;
  --urlbarView-separator-color: #2e1b1e !important;

  /* menus, popups, panels */
  --arrowpanel-background: #1f1416 !important;
  --arrowpanel-color: #e8d5d0 !important;
  --arrowpanel-border-color: #3a2226 !important;
  --arrowpanel-dimmed: rgba(229, 72, 77, 0.12) !important;
  --arrowpanel-dimmed-further: rgba(229, 72, 77, 0.22) !important;
  --panel-separator-color: #2e1b1e !important;
  --menu-background-color: #1f1416 !important;
  --menu-color: #e8d5d0 !important;
  --menu-border-color: #3a2226 !important;
  --menuitem-hover-background-color: #c0303a !important;
  --menuitem-hover-color: #f5e9e6 !important;
  --menu-disabled-color: #7a5a5e !important;

  /* sidebar */
  --sidebar-background-color: #140c0d !important;
  --sidebar-text-color: #e8d5d0 !important;
  --sidebar-border-color: #2e1b1e !important;
  --sidebar-highlight-background-color: #c0303a !important;
  --sidebar-highlight-text-color: #f5e9e6 !important;

  /* accents, focus, buttons */
  --focus-outline-color: #c0303a !important;
  --color-accent-primary: #c0303a !important;
  --color-accent-primary-hover: #e5484d !important;
  --color-accent-primary-active: #ff7a7f !important;
  --button-primary-bgcolor: #c0303a !important;
  --button-primary-hover-bgcolor: #e5484d !important;
  --button-primary-active-bgcolor: #ff7a7f !important;
  --button-primary-color: #f5e9e6 !important;
  --attention-dot-color: #e5484d !important;
  --tab-attention-icon-color: #e5484d !important;

  /* page background before content paints */
  --tabpanel-background-color: #1f1416 !important;
}

#navigator-toolbox {
  background-color: #140c0d !important;
  background-image: none !important;
  border-bottom-color: #2e1b1e !important;
}

/* Selected tab: surface colour with a crimson top line. */
.tabbrowser-tab .tab-background:is([selected], [multiselected]) {
  background-color: #2e1b1e !important;
  background-image: none !important;
  box-shadow: inset 0 2px 0 #c0303a !important;
}

/* Native context menus */
menupopup, panel {
  --panel-background: #1f1416 !important;
  --panel-color: #e8d5d0 !important;
  --panel-border-color: #3a2226 !important;
}
menupopup menuitem[_moz-menuactive], menupopup menu[_moz-menuactive] {
  background-color: #c0303a !important;
  color: #f5e9e6 !important;
}

::selection { background-color: #c0303a; color: #f5e9e6; }

/* Direct element rules for colours some themes apply without the variables
   above (Biscuit's orange tab text/outline, icon tint, teal focus ring). */
.tabbrowser-tab .tab-label,
.tabbrowser-tab:is([selected], [multiselected]) .tab-label { color: #e8d5d0 !important; }
.tabbrowser-tab:is([selected], [multiselected]) .tab-label { color: #f5e9e6 !important; }
.tabbrowser-tab .tab-background { outline-color: transparent !important; }
.tabbrowser-tab:is([selected], [multiselected]) .tab-background {
  outline: 1px solid #3a2226 !important;
  outline-offset: -1px !important;
}
.tab-throbber, .tab-icon-overlay, .tab-close-button { fill: #e8d5d0 !important; color: #e8d5d0 !important; }

#navigator-toolbox toolbarbutton,
#navigator-toolbox .toolbarbutton-text,
#navigator-toolbox .bookmark-item,
#navigator-toolbox .bookmark-item > .toolbarbutton-text {
  color: #e8d5d0 !important;
  fill: #e8d5d0 !important;
}
#navigator-toolbox .toolbarbutton-icon,
#navigator-toolbox .toolbarbutton-badge-stack,
#navigator-toolbox .bookmark-item > .toolbarbutton-icon {
  fill: #e8d5d0 !important;
}

#urlbar, #searchbar {
  --focus-outline-color: #c0303a !important;
  --toolbar-field-focus-border-color: #c0303a !important;
}
#urlbar:is([focused], [open]) > .urlbar-background,
#urlbar:focus-within > .urlbar-background,
#searchbar:focus-within {
  outline-color: #c0303a !important;
  border-color: #c0303a !important;
  background-color: #1f1416 !important;
}
#urlbar-input, #urlbar .urlbar-input, #searchbar .searchbar-textbox { color: #e8d5d0 !important; }

/* Toolbars themselves. Some themes (e.g. Terracotta) colour the toolbar in a
   way the --toolbar-bgcolor override above doesn't reach, so paint them
   directly. */
#nav-bar, #PersonalToolbar, #navigator-toolbox > toolbar:not(#TabsToolbar) {
  background-color: #1a1012 !important;
  background-image: none !important;
  color: #e8d5d0 !important;
  border-color: #2e1b1e !important;
  box-shadow: none !important;
}
#navigator-toolbox, #navigator-toolbox toolbar {
  --tabs-navbar-separator-color: #2e1b1e !important;
  --toolbox-border-bottom-color: #2e1b1e !important;
}
#urlbar-background, #urlbar > .urlbar-background, #searchbar {
  background-color: #1f1416 !important;
  border-color: #3a2226 !important;
}
#sidebar-box, #sidebar-main, sidebar-main, #sidebar-header {
  background-color: #140c0d !important;
  color: #e8d5d0 !important;
}
```

`chrome/userContent.css`:

```css
/* Crimson Dark for Firefox's own pages. Web pages keep their own colours
   (Dark Reader handles those). */

@-moz-document url("about:newtab"), url("about:home"), url("about:privatebrowsing") {
  :root, body, .activity-stream {
    --newtab-background-color: #1f1416 !important;
    --newtab-background-card: #2e1b1e !important;
    --newtab-weather-background-color: #2e1b1e !important;
    --newtab-element-secondary-color: #3a2226 !important;
    --newtab-element-secondary-hover-color: #4a2a2f !important;
    --newtab-button-static-background: #2e1b1e !important;
    --newtab-button-static-hover-background: #3a2226 !important;
    --newtab-button-static-active-background: #c0303a !important;
    --newtab-primary-action-background-pocket: #c0303a !important;
    --newtab-contextual-text-primary-color: #e8d5d0 !important;
    --newtab-contextual-text-secondary-color: #9a7a7e !important;
    --newtab-button-focus-border: #c0303a !important;
    --newtab-background-color-secondary: #2e1b1e !important;
    --newtab-text-primary-color: #e8d5d0 !important;
    --newtab-text-secondary-color: #9a7a7e !important;
    --newtab-primary-action-background: #c0303a !important;
    --newtab-element-hover-color: #3a2226 !important;
    --newtab-element-active-color: #c0303a !important;
    --newtab-button-background: #2e1b1e !important;
    --newtab-button-hover-background: #3a2226 !important;
    --newtab-button-text: #e8d5d0 !important;
    --newtab-border-color: #3a2226 !important;
    --newtab-wordmark-color: #e8d5d0 !important;
    --color-accent-primary: #c0303a !important;
  }
  body { background-color: #1f1416 !important; color: #e8d5d0 !important; }
}

@-moz-document url("about:blank") {
  html, body { background-color: #1f1416 !important; }
}
```

## 7. Packages

Only packages that define this desktop. (The machine also carries ~180 base
Fedora Asahi packages: firmware, filesystems, network, kernel, etc.; install via
the Asahi Remix image, not from this list.)

```
labwc sfwbar fuzzel alacritty swaybg swaylock grim slurp wlr-randr brightnessctl
xorg-x11-server-Xwayland
firefox chromium nautilus mousepad galculator pavucontrol blueman libreoffice vlc gnome-clocks
jetbrains-mono-fonts-all fastfetch mako stow
```

`stow` is only needed to install the dotfiles repo (section 10), and
`python3-gobject` only to regenerate the GTK4 theme (6.2).

In the repo, `install-packages.sh` installs these on Fedora (dnf), Arch
(pacman, plus `yay`/`paru` for AUR packages) or Debian/Ubuntu (apt). A table
in the script gives each package's name per distro, with fallbacks such as
`firefox/firefox-esr`; every name is checked with `dnf info`, `pacman -Si`
(then the AUR helper) or `apt-cache show` before installing, and anything
not found is listed rather than failing the run. Verified 2026-09-26: on this
Fedora machine all 26 resolve; the Arch and Debian paths were exercised with
stand-in package managers (AUR fallback, alternative names, not-found
report), not on real Arch or Debian systems.

`mako` is installed but has no config and is not running (see 8).
Flatpak is not in use; no Flatpaks are installed.

## 8. Known defects and gaps (fix or drop before publishing)

1. ~~Screenshot binding is broken.~~ Fixed 2026-09-25: `~/Pictures` exists and
   each capture gets a timestamped name.
2. ~~`vivaldi` launcher is dead.~~ Removed from the bar 2026-09-25.
3. ~~`mpd-intmod` widget is dead.~~ Removed from the bar 2026-09-25.
4. ~~Icon theme `WhiteSur-dark` is not installed.~~ The `IconTheme` line was
   removed 2026-09-25; the bar uses the default icon theme.
5. ~~Fuzzel is Dracula while everything else is Everforest.~~ Resolved by the
   Crimson Dark theme (4.3), applied 2026-09-25.
6. **No notification daemon running** even though `mako` is installed.
7. **No idle/lock daemon.** Lock is manual (`W-l`); nothing locks on idle or suspend.
8. ~~Config typo in sfwbar CSS: `-GtkWidget-visible: fale;`.~~ Fixed 2026-09-25
   (passive tray icons are now hidden, as intended).
9. ~~`alacritty.toml.73f8a4db.bak` is a stale backup.~~ Deleted 2026-09-25
   (it is in the backup).
10. ~~Wallpaper and lock screen referenced an image in `~/Downloads`.~~ Now
    `~/Pictures/wallpaper.png` (2026-09-25).
11. ~~The `themerc` comes from a third-party theme (Archcraft).~~ Rewritten
    from scratch 2026-09-25 (4.1). The bar config was also rewritten (5).
    Origin: `alacritty.toml`, `sfwbar.config` and the old themerc started as
    copies from [antomfdez/LabwcDots](https://github.com/antomfdez/LabwcDots)
    (GPL-3.0). After the rewrites, line similarity to upstream is 29%
    (alacritty, mostly section headers), 27% (sfwbar, sfwbar option and
    widget names) and 7% (themerc).
12. ~~Theme not yet applied.~~ Applied to the live system and to the
    `dotfiles/` repo on 2026-09-25.

## 9. What must NOT go into a public repo

- `~/.config/mozilla`, `~/.config/chromium`, `~/.local/share/spotify-web`
  (profiles, cookies, sessions). Only the Firefox *stylesheets and prefs* from
  6.5 go in the repo, never the profile itself.
- `~/.bash_history`, `~/.claude`, `~/.claude.json`, `~/.local/share/claude`
- `~/.local/share/recently-used.xbel`, `Trash`, `gvfs-metadata`, `nautilus`
- `~/.config/dconf/user` (binary; window state and history)
- Anything in `~/Downloads`, other personal folders, `~/.cache`
- The absolute home path (`/home/<user>`) in any file; use `$HOME` or `~`

## 10. Suggested repo layout (XDG-relative, for GNU Stow)

```
dotfiles/
  labwc/.config/labwc/{environment,autostart,rc.xml}
  sfwbar/.config/sfwbar/sfwbar.config
  fuzzel/.config/fuzzel/fuzzel.ini
  alacritty/.config/alacritty/alacritty.toml
  themes/.local/share/themes/OB-Crimson-Dark/{labwc/themerc,gtk-3.0/gtk.css,gtk-4.0/gtk.css}
  gtk4/.config/gtk-4.0/gtk.css
  gtksourceview/.local/share/gtksourceview-4/styles/crimson-dark.xml
  dbus/.local/share/dbus-1/services/org.gnome.Nautilus.service
  applications/.local/share/applications/
    {org.gnome.clocks,org.pulseaudio.pavucontrol,blueman-manager,blueman-adapters,spotify-web,
     org.gnome.Nautilus,org.xfce.mousepad,galculator}.desktop
  bash/.bashrc
  firefox/chrome/{userChrome,userContent}.css, firefox/user.js   # not stowed, see below
  scripts/gen-gtk4-crimson.py                                    # not stowed (6.2)
  install-packages.sh   # section 7
  install.sh
  README.md             # this spec, condensed
```

Everything except `firefox/` and `scripts/` is a Stow package. `install.sh`
stows them with `--no-folding` (so a missing `~/.local/share/applications`
becomes a real directory, not a symlink into the repo that later writes would
land in), then handles the pieces a symlink can't: it symlinks the Firefox
stylesheets into the profile named by `profiles.ini` and merges `user.js`
(the profile directory name is random), writes galculator's five colour keys
into its existing config (galculator rewrites that file on exit, which would
replace a stowed symlink), and sets Mousepad's `gsettings` key.

**This machine** runs from the repo since 2026-09-25: every Stow-managed
config in `$HOME` is a symlink into `~/desktop-spec/dotfiles`, so edit files
there (or through the symlinks) and they take effect live. Moving or renaming
the repo breaks the links; re-run `./install.sh` from the new location. The
pre-switch files were backed up locally.

## 11. Rebuild checklist

1. Install Fedora Asahi Remix 44 (minimal), log in on tty1.
2. Run `./install-packages.sh` (section 7).
3. Create `~/Pictures`; place a wallpaper; fix paths in `autostart` and `rc.xml`.
4. Install the configs from sections 2-5 (or `stow` the repo).
5. Add the dark-mode launcher overrides (6.1, 6.2), the Crimson Dark app files
   and Mousepad `gsettings` (6.4), and the `labwc` launch line (section 2).
   Start Firefox once so it creates a profile, then add 6.5's files (or run
   `./install.sh`, which does steps 4–5).
6. Start `labwc`; confirm: bar appears, `W-k` opens fuzzel, Bluetooth Devices
   opens dark; Files, Mousepad, galculator, Clocks, Volume Control and Firefox
   open crimson; LibreOffice opens stock; `W-p` writes a screenshot.
