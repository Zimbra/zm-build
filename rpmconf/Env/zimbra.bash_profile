# .bash_profile
umask 0027

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

# this breaks unicode_start on vt consoles
#BASH_ENV=$HOME/.bashrc
#export BASH_ENV

USERNAME="zimbra"
export USERNAME

export LANG=C
