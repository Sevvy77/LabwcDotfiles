# .bashrc

# Source global definitions: Fedora keeps them in /etc/bashrc. Elsewhere
# install.sh moved the distro's stock ~/.bashrc to ~/.bashrc.skel.
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
elif [ -f ~/.bashrc.skel ]; then
    . ~/.bashrc.skel
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
fastfetch
