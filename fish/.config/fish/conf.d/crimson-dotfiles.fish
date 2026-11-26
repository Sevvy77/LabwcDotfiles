# Crimson Dark dotfiles: what this desktop adds to fish, the same as
# ~/.bashrc.d/crimson-dotfiles.sh does for bash. fish runs everything in
# conf.d before config.fish, so your config.fish (and a distro's, such as
# CachyOS's) can still override any of this.

# system-controls and audio-scope live in ~/.local/bin. Only for
# this session (-g), so nothing is saved into your universal variables.
fish_add_path -g ~/.local/bin ~/bin

# fastfetch when a terminal opens, instead of fish's default greeting.
if status is-interactive; and command -q fastfetch
    function fish_greeting
        fastfetch
    end
end
