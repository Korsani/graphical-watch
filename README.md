# graphical-watch

When watch(1) meet Grafana

Have you ever wanted watch(1) to graph command's output ? Or you sometimes want to graph shell script output and you don't want to install Grafana ?

This script is for you!

# Starting

## Pre-requisite

- A fairly recent bash(1)
- bc(1)

## Installation

Copy grwatch.sh(1) somewhere accessible by your PATH, or set PATH so that it finds grwatch.sh(1)

# Running

## Options

	grwatch.sh [ -n <interval in second> | -w <width in second> ] [ -s <scale factor> ] [ -0 <value> ] [ -r ] [ -m <mark> ] [ -t <command title> ] [ "command than returns integer" ]

	-0 : set the horizontal axis to that value instead of the first one returned by the command (or by stdin)
	-m : use that one-char string to display dot
	-n : sleep that seconds between each dot. May be decimal. Default is 2s
	-r : rainbow mode.
	-s : scale factor. One line height in the term will count for that many values. Set to < 1 to zoom in, > 1 to zoom out. Default is 1 (no zoom).
	-t : display that string in status bar instead of the command
	-w : set the duration of a screen to that many seconds, compute -n accordingly

## Examples

Act like watch(1):

	# Run 'pgrep -c php-fpm' every 20s
	grwatch.sh -n 20 "pgrep -c php-fpm"

Act like Grafana:

	# Take values from stdin
	$ while true ; do pgrep -c php-fpm ; sleep 20 ; done | grwatch.sh
	# Exit by ctrl+c or by sending EOF to stdin

More examples:
	
	# Memory usage:
	$ grwatch.sh -n 0.5 -s 100 'free | grep -i mem | awk "{print \$3}"'

	# CPU temp:
	$ grwatch.sh -n 0.5 -0 43 -t "Temp of thermal0" 'cat /sys/class/thermal/thermal_zone0/temp | cut -c -2'

	# Show a rainbow bubble sine:
	$ for i in {0..180} ; do LANG=C printf '%0.0f\n' "$(bc -l <<<"scale=2;20*s($i*(2*6.28)/360)")" ; done | grwatch.sh -n 0 -r -m 'o' -t sine

	# Monitor number of php-fpm processes on a 1-hour graph:
	$ grwatch.sh -w 3600 -r -m '-' 'pgrep -c php-fpm'

# Considerations

## Status

There is a status zone on the top left of the screen, like:

	$ Temp of thermal0
	25 < 25 < 43 w=119.0s tick=2.5s n=0.50s s=1.0x x=19 y=47.00
	2022-09-27@00:25:30

First line is the command (or the string you gave with ```-t ``` )

Second line is:

- 25 < 25 < 43 : min value < current value < max value 
- w=119.0s : width of the screen, in seconds
- tick=2.5s : each X tick is 2.5s wide
- n=0.50s : value is displayed each 0.5s
- s=1.0x : scale factor is 1.0x
- x=19 y=47.00 : x and y coordinate (in term column/line)

Third line is the date of the last printed dot.

# Caveats / To do

- Does only graph integers
- Y axis is in the middle
- Does not auto-scale

# Made with

- bash(1)
- bc(1)
- shellcheck(1)
- love, patience, and colors.

# See also

- bc(1)
- Grafana
