# tuimenu (Crimson Dark build)

A patched copy of [tuimenu](https://github.com/achester88/tuimenu) 0.0.2 by
Anthony Chester (MIT, see LICENSE), a small menu for launching terminal
programs. `install.sh` builds it into `~/.local/bin` with cargo; it isn't
installed from crates.io, which would replace it with the unstyled version.

Changes from upstream (all in `src/main.rs`):

- Crimson Dark colours (constants at the top of the file), aligned name and
  description columns, a full-width selection bar with a crimson marker, a
  title and a line of key hints
- drawn on the alternate screen, so quitting leaves the shell as it was
- j/k, g/G and Esc as well as the arrows and q; Quit is a key, not a row
- a program that fails to start is reported, and the terminal restored
- no stray "Failed to exec" line for entries that have `args`

The config is unchanged: `~/.config/tuimenu/list.json` (upstream's README
says `~/tuimenu/`, but the code reads `~/.config`), an array of
`{"cmd": ..., "desc": ..., "args": [...]}`. The chosen program replaces the
menu, so quitting it returns to the shell.
