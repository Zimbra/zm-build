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

if [ -x "/opt/zimbra/libexec/get_plat_tag.sh" ]; then
  ZCS_PLATFORM=$(/opt/zimbra/libexec/get_plat_tag.sh)
else 
  ZCS_PLATFORM=unknown
fi

JAVA_HOME=/opt/zimbra/java
export JAVA_HOME

PATH=/opt/zimbra/bin:/opt/zimbra/postfix/sbin:/opt/zimbra/openssl/bin:${JAVA_HOME}/bin:/opt/zimbra/common/bin:/usr/sbin:${PATH}
export PATH

unset LD_LIBRARY_PATH

SNMPCONFPATH=/opt/zimbra/conf
export SNMPCONFPATH

eval `/usr/bin/perl -V:archname`
PERLLIB=/opt/zimbra/zimbramon/lib/$archname:/opt/zimbra/zimbramon/lib
export PERLLIB

PERL5LIB=$PERLLIB
export PERL5LIB

JYTHONPATH=/opt/zimbra/zimbramon/pylibs
export JYTHONPATH

ulimit -n 524288 > /dev/null 2>&1
umask 0027

unset DISPLAY

export MANPATH=/opt/zimbra/opendkim/share/man:/opt/zimbra/common/share/man:${MANPATH}

export HISTTIMEFORMAT="%y%m%d %T "
