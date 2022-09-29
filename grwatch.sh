#!/usr/bin/env bash
set -eu
LANG=C
LC_ALL=C
# █■⯀▪·
# Of course...
case $(uname) in
	Darwin)	MARK_TIP='⬥'; MARK='■' ;;
	*)		MARK_TIP='◆'; MARK='⯀' ;;
esac
MARK_COLOR="255;255;255"
TICK_COLOR=184
HLINE_COLOR=053
RAINBOW=''
SLEEP=2
HEADER_SIZE=2
X_TICK='|'
X_TICKS_STEP=5
Y_TICKS_STEP=5
scale_factor=1
export LINES="$(tput lines)"
export COLUMNS="$(tput cols)"
export PS4='- $LINENO] '
# y ticks position relative to center
Y_TICKS_RELPOS=( $(seq $(( (-LINES+HEADER_SIZE*Y_TICKS_STEP)/2 )) $Y_TICKS_STEP $(( (LINES-HEADER_SIZE*Y_TICKS_STEP)/2 )) ) )
# size of a tick label, in char
Y_TICKS_STR_LEN="$(wc -c <<< "${Y_TICKS_RELPOS[-1]}" )"
# central line position
lcenter="$(( LINES-(LINES-HEADER_SIZE)/2))"
hcenter="$((COLUMNS/2))"
# absolute position of y ticks
Y_TICKS_LABSPOS=( $(seq $(( (lcenter+(-LINES+HEADER_SIZE*Y_TICKS_STEP)/2) )) $Y_TICKS_STEP $(( (lcenter+(LINES-HEADER_SIZE*Y_TICKS_STEP)/2) )) ) )
HOSTNAME="$(hostname)"
# 2022-09-28T15:48:50+02:00
DATE_COLUMNS="$((COLUMNS-25-${#HOSTNAME}-1))"
START_TIME="$(date +%s)"
command=''
start_value=''
last_x=''
last_y=''
last_mc=''
MIN=''
MAX=''
DUMP_FILE=''
declare -a dot values
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function _check_command() {
	while [ -n "${1:-}" ] ; do
		if ! command -v $1 >/dev/null ; then
			echo "Command '$1' not found" >&2
			return 1
		fi
		shift
	done
}
# Some checks
function preflight_check() {
	_check_command bc
}
# Display a string of the last line
function _log() {
	echo -ne "\e[$LINES;1H$1\e[0K\e[0m"
	(sleep 2 ; echo -en "\e[${LINES};1H\e[2K") &
}
# Return true if $1 is a float
function is_float() {
	local v="$1"
	[[ "$v" =~ ^[-+]?[0-9]*[.,]*[0-9]+$ ]]
}
# Generate the rgb dot of the hues of the chromatic circle, by steps of $1
# Running chromatic circle make rgb value vary this way:
# R   G   B
# 255 0   0
# |   +   |
# 255 255 0
# -   |   |
# 0   255 0
# |   |   +
# 0   255 255
# |   -   |
# 0   0   255
# +   |   |
# 255 0   255
# |   |   -
# 255 0   0
function generate_rainbow() {
	# Order of the colors I will increment/decrement
	local order='bgrbgr'
	# Way I will increment/decrement
	local sign=1
	local step="$1"
	# Staring dot
	declare -A RGB
	RGB[r]=0 ; RGB[g]=255 ; RGB[b]=0
	for i in $(seq 0 $(( ${#order}-1)) ) ; do	# r or g or b
		c=${order:$i:1}					# index in the array
		v=${RGB[$c]}					# starting value
		while [ $v -ge 0 ] && [ $v -le 255 ] ; do	# Am I always in the bounds?
			RGB[$c]="$v"
			echo "${RGB[r]};${RGB[g]};${RGB[b]}"
			v="$(( v+(sign*step) ))"		# increment ot decrement
		done
		RGB[$c]="$(( (sign+1)*255/2 ))"	# set to 0 or 255
		sign="$((sign*-1))"				# flip/flop
	done
}
# Draw the x line, at coord $1
function h_line() {
	local y="$1"
	echo -ne "\e[$y;1H\e[38;5;${HLINE_COLOR}m"
	printf -- '―%.0s' $(seq 1 "$COLUMNS")
	disp_x_ticks "$y"
	echo -ne "\e[0m"
	disp_y_ticks
}
# Displays the y ticks and label, eventually at line $1
function disp_y_ticks() {
	local y="${1:-}"		# absolute position of the tick
	local ticks l
	echo -ne "\e[38;5;${TICK_COLOR}m"
	# one tick ? many ticks ?
	if [ -n "$y" ] ; then
		ticks="$y"
	else
		ticks=( ${Y_TICKS_LABSPOS[*]} )
	fi
	for l in ${ticks[*]}; do
		echo -ne "\e[$l;1H"
		printf "%0.01f" "$(bc<<<"$start_value-(($l-$lcenter)*$scale_factor)")"
	done
	echo -ne "\e[0m"
}
# Display x ticks, at (absolute) line $1, eventually at (absolute) eventually column $2
function disp_x_ticks() {
	local y="$1" x="${1:-}"
	echo -ne "\e[38;5;${HLINE_COLOR}m"
	if [ -n "$x" ] ; then	# if I got only y, I draw all the ticks
		for i in $(seq "${X_TICKS_STEP}" "${X_TICKS_STEP}" "${COLUMNS}") ; do
			echo -ne "\e[$y;${i}H${X_TICK}"
		done
	else	# should I REALLY put a tick?
		if [ "$((x % X_TICKS_STEP))" -eq "0" ] ; then
			echo -ne "\e[$y;${x}H${X_TICK}"
		fi
	fi
	echo -ne "\e[0m"
}
# Clean the screen and draw x axis
function clean_screen() {
	echo -ne "\e[2J\e[?25l"
	printf "\e[1;1HEvery %0.02fs: %s" "$SLEEP" "${command_title:-$command}"
	h_line "$lcenter"
}
# Clean the column at (absolute) position $1
function clean_next() {
	local x="$1"
	local int_y
	int_y="${dot[$x]:-}"
	if [ -n "$int_y" ] ; then
		echo -ne "\e[$int_y;${x}H "
		if [ "$int_y" -eq "$lcenter" ] ; then	# am I on the x axis?
			echo -ne "\e[$lcenter;${x}H\e[38;5;${HLINE_COLOR}m―\e[0m"
		fi
		# am I on a y label?
		if [ "$x" -lt "${Y_TICKS_STR_LEN}" ] && [[ " ${Y_TICKS_LABSPOS[*]} " =~ " $int_y " ]] ; then
			disp_y_ticks "$int_y"
		fi
	fi
	# (eventually) display the x tick I erase
	disp_x_ticks "$lcenter" "$x"
}
function _usage() {
	local bn="$(basename "$0")"
	echo " ~ Graphical watch(1) - a.k.a Grafana in term ~"
	echo
	echo "$bn [ -n <interval in second> | -w <width in second> ] [ -0 <value> ]i [ -f <file> ] [ -r ] [ -m <mark> ] [ -t <command title> ] [ [ -l <lower bound> -u <upper bound> ] | -s <scale> ] [ \"command than returns integer\" ]"
	echo
	echo "-0 : set the horizontal axis to that value"
	echo "-f : dump data in that file upon exit or when SIGHUP is received"
	echo "-l : set lower value"
	echo "-m : use that one-char string to display dot"
	echo "-n : sleep that seconds between each dot. May be decimal. Default is 2s"
	echo "-o : dump (append) each value in the given json"
	echo "-r : rainbow mode"
	echo "-s : scale. One line height in the term will count for that many dot. Set to < 1 to zoom in, > 1 to zoom out. Default is 1"
	echo "-t : display that string in status bar instead of the command"
	echo "-u : set upper value"
	echo "-w : set the duration of a screen to that many seconds, compute -n accordingly"
	echo
	echo "scale and 0 are calculated if -l and -u are provided"
	echo
	echo "Examples:"
	echo "	On Linux:"
	echo "	Memory usage:"
	echo "	$bn -n 0.5 -s 100 'free | grep -i mem | awk \"{print \\\$3}\"'"
	echo "	CPU temp:"
	echo "	$bn -n 0.5 -0 43 'cat /sys/class/thermal/thermal_zone0/temp | cut -c -2'"
	echo
	echo "Show a rainbow bubble sine:"
	echo "	i=0 ; while true ; do LANG=C printf '%0.0f\n' \"\$(bc -l <<<\"scale=2;20*s(\$i*(2*6.28)/360)\")\" ; ((i+=1)) ; done | $bn -n 0 -r -m 'o' -t sine"
	echo
	echo "Monitor number of php-fpm processes on a 1-hour graph:"
	echo "	$bn -w 3600 -r -m '-' 'pgrep -c php-fpm'"
	echo
}
# Redraw the previous mark at (absolute) line $1, (absolute) column $2, with color $3
function correct_last_mark() {
	local last_y="$1" last_x="$2" last_mc="$3"
	if [ -z "${last_y}" ]; then
		return
	fi
	echo -ne "\e[${last_y};${last_x}H\e[38;2;${last_mc}m${MARK}\e[0m"
	# redraw the tick of the x axis if I'm on it
	if [ "$last_x" -lt "${Y_TICKS_STR_LEN}" ] && [[ " ${Y_TICKS_LABSPOS[*]} " =~ " $last_y " ]] ; then
		disp_y_ticks "$last_y"
	fi
}
function disp_status() {
	local min=$1 value=$2 max=$3 scale_factor=$4 x=$5 y=$6
	# status line
	printf "\e[2;1Hm=%i M=%i wdith=%0.0fs tick=%0.01fs scale=%0.01fx x=%i y=%0.02f file=%s pid=%i\e[0K" "$min" "$max" "$WINDOW_WIDTH" "$X_TICKS_WIDTH" "$scale_factor" "$x" "$int_y" "${DUMP_FILE:-<none>}" "$$"
	printf "\e[1;${hcenter}H\e[1;4;37m%0.02f\e[0m " "$value"
	# date line
	printf "\e[1;${DATE_COLUMNS}H%s: %s" "$HOSTNAME" "$(date -Iseconds)"
}
function value_to_y() {
	local v="$1"
	bc <<< "scale=1;$lcenter - ( ($v-$start_value)/$scale_factor )"
}
function redraw() {
	local till="$1"
	local x y
	for x in $(seq 1 "$((till-1))") ; do
		printf -v y '%0.0f' "$( value_to_y "${dot[$x]:-}")"	# do I have the coordinate of the values here?
		rgb="$(( (x + RGB_start) % ${#RGB[*]} ))"
		echo -ne "\e[${y};${x}H\e[38;2;${RGB[$rgb]}m${MARK}\e[0m"
	done
}
function disp_tracers() {
	local x="$1"
	echo -ne "\e[$LINES;${x}H^"
}
function clean_tracers() {
	local x="$1"
	echo -ne "\e[$LINES;${x}H "
}
function _dump() {
	_log "Dumping to $DUMP_FILE..."
	local data d
	data="$(for d in "${!values[@]}" ; do
		jo $d="${values[$d]}"
	done | jq -cs 'add' )"
	jo infos="$(jo -- hostname="$(hostname)" command="$command" command_title="${command_title:-}" pid="$$" start_time="$(date -d@$START_TIME)" start_time_ts="$START_TIME" lines="$LINES" columns="$COLUMNS" scale="$scale_factor" sleep="$SLEEP" mark="$MARK" upper="$MAX" lower="$MIN" -b rainbow="$RAINBOW" )" data="$data" > "$DUMP_FILE"
}
function _exit() {
	# cursor visible and set me at the end of the screen
	echo -ne "\e[?25h\e[$LINES;1H\e[0m"
	if [ -n "$DUMP_FILE" ] ; then
		_dump
	fi
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
while getopts '0:f:hil:m:n:o:rs:t:u:w:' opt ; do
	case $opt in		# Refactor this, please
		0)	is_float "$OPTARG" && start_value="${OPTARG}";;
		f)	DUMP_FILE="${OPTARG}";;
		h)	_usage ; exit 0;;
		i)	IGNORE_EMPTY_VALUES='y';;
		l)	is_float "$OPTARG" && MIN="$OPTARG";;
		m)	MARK="$OPTARG";;
		n)	is_float "$OPTARG" && SLEEP="${OPTARG}";;
		r)	RAINBOW='y';;
		s)	is_float "$OPTARG" && scale_factor="$OPTARG";;
		t)	command_title="$OPTARG";;
		u)	is_float "$OPTARG" && MAX="$OPTARG";;
		w)	is_float "$OPTARG" && SLEEP="$( bc<<<"scale=2;$OPTARG/$COLUMNS" )";;
	esac
done
preflight_check || exit 1
if [ -n "$DUMP_FILE" ] ; then
	_check_command jo jq || exit 1
	trap _dump 1
fi
trap _exit 0
WINDOW_WIDTH="$(bc<<<"$SLEEP*$COLUMNS")"
X_TICKS_WIDTH="$(bc<<<"$X_TICKS_STEP*$SLEEP")"
col=1
n=0
shift $((OPTIND-1))
# Tiny hack to have the "read-from-stdin" command
if [ -z "${1:-}" ] ; then
	command="read -r v ; echo \$v"
	command_title="${command_title:-<stdin>}"
else
	command="${1}"
fi
if [ -n "$MIN" ] && [ -n "$MAX" ] ; then
	if [ "$MIN" -lt "$MAX" ] ; then
		printf -v start_value '%0.0f' "$(bc <<<"scale=2;($MAX+($MIN))/2")"
		scale_factor="$( bc <<<"scale=2;($MAX-($MIN))/$LINES" )"
	else
		echo "-l MUST BE strictly lower that -u" >&2
		exit 2
	fi
fi
# Read value while I don't have an int
while ! is_float "$start_value" ; do
	start_value="$(sh -c "$command")"
done
printf -v start_value '%0.0f' "$start_value"
min=$start_value
max=$start_value
clean_screen
if [ -n "$RAINBOW" ] ; then
	_log "Generating rainbow table..."
	RGB=( $(generate_rainbow 15) )
	RGB_start=$(( ( RANDOM * ${#RGB[*]} ) / 32768 ))	# I'll start somewhere random
else
	RGB=( $MARK_COLOR )
	RGB_start=0
fi
while true ; do
	# Floating value
	fvalue="$(sh -c "$command")"
	if ! is_float "$fvalue" ; then
		asc="$(printf "%02.2X" "'$fvalue'")"
		if [ "$asc" -ne "27" ] ; then				# if it's not EOF
			_log "'$fvalue' (0x$asc) is not at least a float"
			continue
		else
			echo "Got empty value"
			exit 0
		fi
	else
		printf -v value '%0.0f' "$fvalue"
	fi
	x="$col"
	# value => line (eventualy a float value)
	y="$(value_to_y "$fvalue")"
	printf -v int_y '%0.0f' "$y"
	if [ "$value" -lt "$min" ] ; then
		min="$value"
	fi
	if [ "$value" -gt "$max" ] ; then
		max="$value"
	fi
	if [ "$int_y" -le "$HEADER_SIZE" ] || [ "$int_y" -ge "$LINES" ] ; then
		scale_factor="$(bc <<<"scale=2;($value-($start_value))/($LINES-$HEADER_SIZE-$lcenter)" | tr -d '-' )"
		clean_screen
		redraw "$col"
		disp_status "$min" "$fvalue" "$max" "$scale_factor" "$x" "$y"
		y="$(value_to_y "$value")"
		printf -v int_y '%0.0f' "$y"
		_log "Set scale to $scale_factor"
	else
		correct_last_mark "$last_y" "$last_x" "$last_mc"
		clean_tracers "$last_x"
	fi
	# next color: next value in the array, wrapping
	rgb="$(( (n + RGB_start) % ${#RGB[*]} ))"
	# store position of the dot (to delete it next time)
	dot[$x]="$int_y"
	# keep track of all datas
	values[$n]="$fvalue"
	echo -ne "\e[${int_y};${x}H\e[38;2;${RGB[$rgb]}m${MARK_TIP}\e[0m"
	disp_tracers "$x"
	disp_status "$min" "$fvalue" "$max" "$scale_factor" "$x" "$y"
	last_x="$x"
	last_y="$int_y"
	last_mc="${RGB[$rgb]}"
	clean_next "$(( 1 + (col+1) % COLUMNS))"
	sleep "$SLEEP"
	col="$(( 1 + (col % COLUMNS) ))"
	((n+=1))
done
