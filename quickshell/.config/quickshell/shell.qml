//@ pragma IconTheme Crimson-Wine
//@ pragma ShellId crimson

// Crimson Dark desktop shell for labwc: the bottom bar (was sfwbar), the app
// launcher (was fuzzel), the lock screen (was gtklock) and notification
// popups (was mako). labwc's autostart
// starts it (quickshell --no-duplicate); the keybinds in rc.xml talk to it:
//   quickshell ipc call launcher toggle     (Super+k)
//   quickshell ipc call lock lock           (Super+l)
//
// Saving any file here reloads the shell. A lock that's up stays up through a
// reload (and through the shell crashing: labwc keeps the screen locked
// until a new lock screen unlocks it; see the README).

import QtQuick
import Quickshell

ShellRoot {
    // One bar per output, like sfwbar's mirror = "*".
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Launcher {}
    Lock {}
    Notifications {}
}
