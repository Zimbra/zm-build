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

check_license_expiry() {
    local output json timestamp timestamp_no_z formatted_timestamp timestamp_epoch current_epoch remaining_days
    local zm_license_cache="/opt/zimbra/log/.zm_license_cache"
    local cache_dir
    cache_dir="$(dirname "$zm_license_cache")"

    if [ -f "$zm_license_cache" ] && [ "$(date +%Y-%m-%d -r "$zm_license_cache")" == "$(date +%Y-%m-%d)" ]; then
        output=$(cat "$zm_license_cache")
	else
		output=$(zmprov gcf zimbraNetworkRealtimeActivation 2>/dev/null) || return 0
		[ -n "$output" ] || return 0
		if [ -d "$cache_dir" ]; then
			tmp_cache="$zm_license_cache.$$"
			echo "$output" > "$tmp_cache" && mv -f "$tmp_cache" "$zm_license_cache"
		fi
    fi

    [ -z "$output" ] && return 0

    json=${output#zimbraNetworkRealtimeActivation: }
    [ -z "$json" ] && return 0

    install_type=$(echo "$json" | grep -oP '"InstallType":"\K[^"]+' 2>/dev/null)
    [ -z "$install_type" ] && return 0

    if [[ "$install_type" == "trial" || "$install_type" == "perpetual" || "$install_type" == "perpetualOfflineLicense" ]]; then
        return 0
    fi

    timestamp=$(echo "$json" | grep -oP '"ValidUntilTimestamp":"\K[^"]+' 2>/dev/null)
    [ -z "$timestamp" ] && return 0

    timestamp_no_z="${timestamp%Z}"
    formatted_timestamp=$(echo "$timestamp_no_z" | sed -E 's/([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3 \4:\5:\6/')

    timestamp_epoch=$(date -d "$formatted_timestamp" +%s 2>/dev/null)
    [ -z "$timestamp_epoch" ] && return 0

    current_epoch=$(date +%s 2>/dev/null)

    if [ "$timestamp_epoch" -lt "$current_epoch" ]; then
        remaining_days=-1
    else
        remaining_days=$(( ((timestamp_epoch - current_epoch) / 86400) + 1 ))
    fi

    if [ "$remaining_days" -eq -1 ]; then
        echo -e "\e[31mLicense expiration alert: Your license is expired.\e[0m"
    elif [ "$remaining_days" -le 60 ]; then
        echo -e "\e[31mLicense expiration alert: Your license will expire in $remaining_days days.\e[0m"
    fi
}

# Only run this in interactive shells and if the zmlicense exists
if [[ $- == *i* && -f /opt/zimbra/bin/zmlicense ]]; then
    check_license_expiry
fi
