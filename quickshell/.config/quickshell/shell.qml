//@ pragma IconTheme Crimson-Wine
//@ pragma ShellId crimson

// Crimson Dark desktop shell for labwc: the bottom bar (was sfwbar), the app
// launcher (was fuzzel), the lock screen (was gtklock) and notification
// popups (was mako). labwc's autostart
// starts it (quickshell --no-duplicate); the keybinds in rc.xml talk to it:
//   quickshell ipc call launcher toggle     (Super+k)
//   quickshell ipc call lock lock           (Super+l)
//   quickshell ipc call bar reload          (crimson-bar-outputs, after saving)
//
// Saving any file here reloads the shell. A lock that's up stays up through a
// reload (and through the shell crashing: labwc keeps the screen locked
// until a new lock screen unlocks it; see the README).

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    // Which outputs get a bar: the output names (HDMI-A-1, DP-1...) in
    // ~/.config/crimson/bar-outputs, one per line. It's this machine's own
    // setting, not part of the repo; crimson-bar-outputs (the Bar tab of
    // System Controls) edits it. No file, an empty one, or none of its
    // outputs plugged in: a bar on every output, like sfwbar's mirror = "*".
    FileView {
        id: barOutputs
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
              + "/crimson/bar-outputs"
        blockLoading: true   // read it before the first bars go up
        printErrors: false   // a missing file is the usual case
        watchChanges: true
        onFileChanged: reload()
    }

    // A file that didn't exist yet has nothing to watch, so the TUI also
    // calls this after saving.
    IpcHandler {
        target: "bar"
        function reload(): void { barOutputs.reload(); }
    }

    Variants {
        model: {
            const wanted = barOutputs.text().split("\n")
                .map(l => l.trim())
                .filter(l => l !== "" && !l.startsWith("#"));
            const picked = Quickshell.screens.filter(s => wanted.includes(s.name));
            return picked.length > 0 ? picked : Quickshell.screens;
        }
        Bar {}
    }

    Launcher {}
    Lock {}
    Notifications {}
}
