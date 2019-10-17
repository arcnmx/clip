#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<EOF
clipboard tool
usage: $0 [OPTIONS]
options:
-h: help
-i: copy to clipboard from stdin (default)
-z: clear the clipboard contents
-o: paste from clipboard to stdout

-p: use the primary selection (default)
-b: use the clipboard

-n: trim trailing newline when copying

-X: force X11 mode
-W: force Wayland mode
-O: force OSC52 mode
EOF
}

PREFERRED=
TARGET=primary
DIR=in
TRIM=
while getopts ":hpbXWOiozn" opt; do
	case $opt in
		h)
			usage
			exit
			;;
		p)
			TARGET=primary
			;;
		b)
			TARGET=clip
			;;
		#t)
		#	TARGET=$OPTARG
		#	;;
		i) # copy
			DIR=in
			;;
		o) # paste
			DIR=out
			;;
		z) # clear TARGET
			DIR=clear
			;;
		X) # mode X11
			PREFERRED=x
			;;
		W) # mode wayland
			PREFERRED=way
			;;
		O) # mode OSC52
			PREFERRED=osc
			;;
		n) # trim trailing newline
			TRIM=1
			;;
		*)
			usage >&2
			exit 1
			;;
	esac
done

if [[ $PREFERRED = way ]] || [[ -z $PREFERRED && (${XDG_SESSION_TYPE-} = wayland || -n ${SWAYSOCK-}) ]]; then
	# TODO: test and support this properly
	WL_OPTS=()
	if [[ -n $TRIM ]]; then
		WL_OPTS+=(-n)
	fi
	case $TARGET in
		clip);;
		primary)
			WL_OPTS+=(-p)
			;;
	esac
	case $DIR in
		out)
			exec wl-paste "${WL_OPTS[@]}"
			;;
		in)
			# TODO: --foreground? forking can cause problems...
			exec wl-copy "${WL_OPTS[@]}"
			;;
		clear)
			exec wl-copy -c "${WL_OPTS[@]}"
			;;
	esac
fi

if [[ $PREFERRED = x ]] || [[ -z $PREFERRED && (${XDG_SESSION_TYPE-} = x11 || -n ${DISPLAY-}) ]]; then
	XSEL_OPTS=()
	if [[ $TARGET = clip ]]; then
		XSEL_OPTS+=(-b)
	else
		XSEL_OPTS+=(-p)
	fi
	case $DIR in
		out)
			XSEL_OPTS+=(-o)
			;;
		in)
			XSEL_OPTS+=(-i)
			;;
		clear)
			XSEL_OPTS+=(-c)
			;;
	esac
	# TODO: figure out if --keep is useful in some way... I hate how closing an application clears the selection...
	exec xsel "${XSEL_OPTS[@]}"
fi

escape_tmux() {
	printf '\ePtmux;\e%s\e\\' "$1"
}

escape_screen() {
	# https://github.com/chromium/hterm/blob/master/etc/osc52.vim#L70
	# TODO: the above splits the message up into small chunks?
	printf '\eP%s\e\x5c' "$1"
}

isatty() {
	if [[ -t 2 ]]; then
		OSC_OUT=2
	elif [[ -t 1 ]]; then
		OSC_OUT=1
	else
		return 1
	fi

	case $DIR in
		in|clear) [[ -t 0 ]];;
		out) true;;
	esac
}

lazytty() {
	if [[ -t 2 ]]; then
		OSC_OUT=2
	else
		OSC_OUT=1
	fi
}

if { [[ $PREFERRED = osc ]] && lazytty; } || { [[ -z $PREFERRED ]] && isatty; }; then
	case $TARGET in
		primary)
			CLIPBOARD=s
			;;
		clip|*)
			CLIPBOARD=c
			;;
	esac
	case $DIR in
		in)
			if [[ -n $TRIM ]]; then
				DATA="$(printf %s "$(cat)" | base64 -w0)"
			else
				DATA="$(base64 -w0)"
			fi
			;;
		clear)
			DATA=
			;;
		out)
			DATA=?
			TTYSTATE=$(stty -g)
			stty -echo
			trap "stty $TTYSTATE" EXIT
			;;
	esac
	COMMAND=$(printf '\e]52;%s;%s\a' "$CLIPBOARD" "$DATA")
	if [[ -n ${TMUX-} ]]; then
		escape_tmux "$COMMAND"
	elif [[ ${TERM-} = screen* ]]; then
		escape_screen "$COMMAND"
	else
		printf %s "$COMMAND"
	fi >&$OSC_OUT

	if [[ $DIR = out ]]; then
		# TODO: forcibly take over the tty somehow..?
		# There's $SSH_TTY but that's unhelpful for tmux...
		# For tmux you can $(tmux list-panes -F "#{pane_active} #{pane_tty}") to check if current pane is active, and if so, use its tty... but ew..? and can we even steal stdin from tmux?
		# what you actually want might be $(tmux list-clients -F "#{client_tty}") hmmm....
		if read -t 2 -r -d "$(printf '\a')" LINE; then
			# TODO: can we get more than one response? what if multiple terminals are listening!
			if [[ $LINE != "$(printf '\e]52;%s')"*\;* ]]; then
				echo "unsupported data" >&2
				printf %s "$LINE" | hexdump -C >&2
			else
				#DATA_CLIPBOARD=$(printf %s "$LINE" | cut -d';' -f2)
				# TODO: assert DATA_CLIPBOARD = CLIPBOARD?
				# TODO: trim and/or append trailing newlines?
				printf %s "$LINE" | cut -d';' -f3 | base64 -d
			fi
		else
			echo "clip: expected osc52 response" >&2
		fi
	fi
	exit 0
fi

echo "clip: out of backends to try" >&2
exit 1
