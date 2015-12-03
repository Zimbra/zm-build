# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias h='history 40'
alias j='jobs'

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

JAVA_HOME=/opt/zimbra/common/lib/jvm/java
export JAVA_HOME

PATH=/opt/zimbra/bin:${JAVA_HOME}/bin:/opt/zimbra/common/bin:/opt/zimbra/common/sbin:/usr/sbin:${PATH}
export PATH

unset LD_LIBRARY_PATH

SNMPCONFPATH=/opt/zimbra/conf
export SNMPCONFPATH

eval `/usr/bin/perl -V:archname`
PERLLIB=/opt/zimbra/common/lib/perl5/$archname:/opt/zimbra/common/lib/perl5
export PERLLIB

PERL5LIB=$PERLLIB
export PERL5LIB

JYTHONPATH=/opt/zimbra/common/lib/jylibs
export JYTHONPATH

ulimit -n 524288 > /dev/null 2>&1
umask 0027

unset DISPLAY

export MANPATH=/opt/zimbra/common/share/man:${MANPATH}

export HISTTIMEFORMAT="%y%m%d %T "
