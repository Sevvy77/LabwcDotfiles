# Crimson Dark dotfiles: what this desktop adds to bash. install.sh adds a
# line to the end of ~/.bashrc that sources this file, and leaves the rest of
# your distro's .bashrc alone. Fedora's .bashrc also sources everything in
# ~/.bashrc.d, so the guard stops it running twice.
[ -n "${CRIMSON_DOTFILES_BASHRC:-}" ] && return
CRIMSON_DOTFILES_BASHRC=1

# Fedora's .bashrc and Debian's ~/.profile put ~/.local/bin on PATH; Arch
# doesn't.
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

if [[ $- == *i* ]] && command -v fastfetch >/dev/null; then
    fastfetch
fi
