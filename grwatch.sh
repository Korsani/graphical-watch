#!/usr/bin/env bash
set -eu
LANG=C
# Evidemment...
case $(uname) in
	Darwin)	MARK_TIP='⬥';;
	*)		MARK_TIP='◆';;
esac
# █■⯀▪·
MARK='⯀'
MARK_COLOR="255;255;255"
TICK_COLOR=184
HLINE_COLOR=053
RAINBOW=''
SLEEP=2
HEADER_SIZE=3
X_TICK='|'
X_TICKS_STEP=5
Y_TICKS_STEP=5
scale_factor=1
export LINES="$(tput lines)"
export COLUMNS="$(tput cols)"
# y ticks position relative to center
Y_TICKS_RELPOS=( $(seq $(( (-LINES+HEADER_SIZE*Y_TICKS_STEP)/2 )) $Y_TICKS_STEP $(( (LINES-HEADER_SIZE*Y_TICKS_STEP)/2 )) ) )
# size of a tick label, in char
Y_TICKS_STR_LEN="$(wc -c <<< "${Y_TICKS_RELPOS[-1]}" )"
# central line position
lcenter="$(( LINES-(LINES-HEADER_SIZE)/2))"
# absolute position of y ticks
Y_TICKS_LABSPOS=( $(seq $(( (lcenter+(-LINES+HEADER_SIZE*Y_TICKS_STEP)/2) )) $Y_TICKS_STEP $(( (lcenter+(LINES-HEADER_SIZE*Y_TICKS_STEP)/2) )) ) )
HOSTNAME="$(hostname)"
DATE_COLUMNS="$((COLUMNS-19-${#HOSTNAME}-2))"
command=''
start_value=''
last_x=''
last_y=''
last_mc=''
declare -a dot
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Some checks
function preflight_check() {
	if ! command -v bc >/dev/null ; then
		echo "bc(1) not found" >&2
		return 1
	fi
}
# Display a string of the last line
function _log() {
	echo -ne "\e[$LINES;1H$1\e[0K"
}
# Return true if $1 is belonging to the N ensemble
function is_int() {
	local v="$1"
	[[ "$v" =~ ^[-+]?[0-9]+$ ]]
}
# Generate the rgb values of the hues of the chromatic circle, by steps of $1
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
	# Staring values
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
		printf "%0.01f" "$(value_to_y "$l")"
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
	printf "\e[1;1HEvery %0.0fs: %s" "$SLEEP" "${command_title:-$command}"
	h_line "$lcenter"
}
# Clean the column at (absolute) position $1
function clean_next() {
	local x="$1"
	local y
	printf -v y '%0.0f' "$( value_to_y "${dot[$x]:-}")"	# do I have the coordinate of the dot here?
	if [ -n "$y" ] ; then
		echo -ne "\e[$y;${x}H "
		if [ "$y" -eq "$lcenter" ] ; then	# am I on the x axis?
			echo -ne "\e[$lcenter;${x}H\e[38;5;${HLINE_COLOR}m―\e[0m"
		fi
		# am I on a y label?
		if [ "$x" -lt "${Y_TICKS_STR_LEN}" ] && [[ " ${Y_TICKS_LABSPOS[*]} " =~ " $y " ]] ; then
			disp_y_ticks "$y"
		fi
	fi
	# (eventually) display the x tick I erase
	disp_x_ticks "$lcenter" "$col"
}
function _usage() {
	local bn="$(basename "$0")"
	echo " ~ Graphical watch(1) - a.k.a Grafana in term ~"
	echo
	echo "$bn [ -n <interval in second> | -w <width in second> ] [ -s <scale factor> ] [ -0 <value> ] [ -r ] [ -m <mark> ] [ -t <command title> ] <\"command than returns integer\">"
	echo
	echo "-0 : set the horizontal axis to that value"
	echo "-m : use that one-char string to display dot"
	echo "-n : sleep that seconds between each dot. May be decimal. Default is 2s"
	echo "-r : rainbow mode"
	echo "-s : scale factor. One line height in the term will count for that many values. Set to < 1 to zoom in, > 1 to zoom out. Default is 1"
	echo "-t : display that string in status bar instead of the command"
	echo "-w : set the duration of a screen to that many seconds, compute -n accordingly"
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
	printf "\e[2;1H\e[1;4;37m%i\e[0m m=%i M=%i w=%0.0fs tick=%0.01fs s=%0.01fx x=%i y=%0.02f\e[0K" "$value" "$min" "$max" "$WINDOW_WIDTH" "$X_TICKS_WIDTH" "$scale_factor" "$x" "$int_y"
	# date line
	printf "\e[1;${DATE_COLUMNS}H%s: %s" "$HOSTNAME" "$(date '+%Y-%m-%d@%H:%M:%S')"
}
function value_to_y() {
	local v="$1"
	bc <<< "scale=1;$lcenter - ( ($v-$start_value)/$scale_factor )"
}
function redraw() {
	local till="$1"
	local x y
	for x in $(seq 1 "$((till-1))") ; do
		printf -v y '%0.0f' "$( value_to_y "${dot[$x]:-}")"	# do I have the coordinate of the dot here?
		rgb="$(( (x + RGB_start) % ${#RGB[*]} ))"
		echo -ne "\e[${y};${x}H\e[38;2;${RGB[$rgb]}m${MARK}\e[0m"
	done
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Set me at the end of the screen upon exit
trap 'echo -ne "\e[?25h\e[$LINES;1H"' 0
while getopts '0:hm:n:rs:t:w:' opt ; do
	case $opt in
		0)	start_value="${OPTARG}";;
		m)	MARK="$OPTARG";;
		n)	SLEEP="${OPTARG}";;
		w)	SLEEP="$( bc<<<"scale=2;$OPTARG/$COLUMNS" )";;
		s)	scale_factor="$OPTARG";;
		r)	RAINBOW='y';;
		t)	command_title="$OPTARG";;
		h)	_usage ; exit 0;;
	esac
done
preflight_check || exit 1
WINDOW_WIDTH="$(bc<<<"$SLEEP*$COLUMNS")"
X_TICKS_WIDTH="$(bc<<<"$X_TICKS_STEP*$SLEEP")"
col=1
n=0
shift $((OPTIND-1))
# Tiny hack to have the "read-from-stdin" command
command="${1:-read -r v ; echo \$v}"
if [ -z "$start_value" ] ; then
	start_value="$(eval "$command")"
fi
min=$start_value
max=$start_value
if ! is_int "$start_value" ; then
	echo "Start value '$start_value' is not even an int..." >&2
	exit 2
fi
clean_screen
if [ -n "$RAINBOW" ] ; then
	_log "Generating rainbow table..."
	RGB=( $(generate_rainbow 15) )
	RGB_start=$(( ( RANDOM * ${#RGB[*]} ) / 32768 ))	# I'll start somewhere random
	_log ""
else
	RGB=( $MARK_COLOR )
	RGB_start=0
fi
while true ; do
	value="$(eval "$command")"
	if ! is_int "$value" ; then
		asc="$(printf "%02.2X" "'$value'")"
		if [ "$asc" -ne "27" ] ; then				# if it's not EOF
			_log "'$value' (0x$asc) is not an int"
			continue
		else
			exit 0
		fi
	fi
	x="$col"
	# value => line (eventualy floating value)
	y="$(value_to_y "$value")"
	printf -v int_y '%0.0f' "$y"
	if [ "$value" -lt "$min" ] ; then
		min="$value"
	fi
	if [ "$value" -gt "$max" ] ; then
		max="$value"
	fi
	if [ "$int_y" -lt 0 ] || [ "$int_y" -gt "$LINES" ] ; then
		scale_factor="$(bc <<<"scale=2;($value-($start_value))/($LINES-$lcenter)" | tr -d '-' )"
		clean_screen
		redraw "$col"
		disp_status "$min" "$value" "$max" "$scale_factor" "$x" "$y"
		y="$(value_to_y "$value")"
		printf -v int_y '%0.0f' "$y"
		_log "Set scale to $scale_factor"
	else
		correct_last_mark "$last_y" "$last_x" "$last_mc"
		_log ""
	fi
	# next color: next value in the array, wrapping
	rgb="$(( (n + RGB_start) % ${#RGB[*]} ))"
	# store the value of the current x value (to delete it next time)
	dot[$x]="$value"
	echo -ne "\e[${int_y};${x}H\e[38;2;${RGB[$rgb]}m${MARK_TIP}\e[0m"
	disp_status "$min" "$value" "$max" "$scale_factor" "$x" "$y"
	last_x="$x"
	last_y="$int_y"
	last_mc="${RGB[$rgb]}"
	clean_next "$(( 1 + (col+1) % COLUMNS))"
	sleep "$SLEEP"
	col=$(( 1 + (col % COLUMNS) ))
	((n+=1))
done
