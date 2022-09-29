# graphical-watch

When watch(1) meet Grafana

Have you ever wanted watch(1) to graph command's output ? Or you sometimes want to graph shell script output and you don't want to install Grafana ?

This pure shell script is for you!

Unlike the nice [gwatch](https://github.com/robertely/gwatch), it is pure shell, and colored, and can take from stdin, and has more options.

	grwatch.sh -n 1 -r -l 100 -u 250 -t "Ping to google, 100x" "ping -c 1 www.google.com | grep 'time=' | awk '{print \$8}' | tr -cd '[0-9]'"

![Ping to google, zoomed x100](/doc/ping-to-google.png)

# Starting

## Pre-requisite

- A fairly recent bash(1)
- bc(1)
- Eventualy jq(1) and jo(1)

## Installation

Copy grwatch.sh(1) somewhere accessible by your PATH, or set PATH so that it finds grwatch.sh(1)

# Running

## Options

	grwatch.sh [ -n <interval in second> | -w <width in second> ] [ -0 <value> ] [ -f <file> ] [ -r ] [ -m <mark> ] [ -t <command title> ] [ [ -l <lower bound> -u <upper bound> ] | -s <scale> ] [ "command than returns integer" ]

	-0 : set the horizontal axis to that value instead of the first one returned by the command (or by stdin) (or by the mean of -l and -u)
	-f : dump data in that file upon exit or when SIGHUP is received
	-l : set lower bound
	-m : use that one-char string to display dot
	-n : sleep that seconds between each value read. May be decimal. Default is 2s
	-o : dump (append) each value in the given json
	-r : rainbow mode.
	-s : scale. One line height in the term will count for that many values. Set to < 1 to zoom in, > 1 to zoom out. Default is 1 (no zoom).
	-t : display that string in status bar instead of the command
	-u : set upper bound
	-w : set the duration of a screen to that many seconds, compute -n accordingly

If ```-t``` and ```-u``` are provided, ```-s``` and ```-0``` are ignored.

Last one of ```-n``` and ```-w``` win.

Command is run by ```sh -c```

## Examples

Act like watch(1):

	# Run 'pgrep -c php-fpm' every 20s
	$ grwatch.sh -n 20 "pgrep -c php-fpm"

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

	# Monitor your ping, values are x100 
	$ grwatch.sh "ping -c 1 www.google.com | grep 'time=' | awk '{print \$8}' | tr -cd '[0-9]'"

# Considerations

## Status

There is a status zone on the top left of the screen, like:

	Every 10s: Temp of thermal0                                                                              Cygnus: 2022-09-27@00:25:30
	25.00 m=25 M=43 width=119.0s tick=2.5s n=0.50s scale=1.0x x=19 y=47.00 file=dump.json pid=666

First line is the periodicity and the command (or the string you gave with ```-t ``` )

Second line is:

- 25: current value
- m=25: min value, rounded to int
- M=43: max value, rounded to int
- width=119.0s : width of the screen, in seconds
- tick=2.5s : time between each x tick on axis
- scale=1.0x : scale
- x=19 y=47.00 : x and y coordinate (in column/line)
- file=dump.json : file values will dumped to upon exit, if asked so
- pid=666 : pid of running instance (useful for kill -1)

Hostname and date are shown on upper right corner.

## Autoscale

Scale is recalculated if value exceed screen bounds. Graph is redraw with the new scale.

Starting value is kept. That means that graph is not recentered, just zoomed in or out.

## Dump

Dump is made in json format. It contains enough info to fully replay a run:

	for i in {0..180} ; do LANG=C printf '%0.0f\n' "$(bc -l <<<"scale=2;20*s($i*(2*6.28)/360)")" ; done | grwatch.sh -n 0 -r -m '~' -f sine.json
	jq '.infos' sine.json
	jq '.data | .[]' sine.json | grwatch.sh

# To do

- Allow y axis to be elsewhere than in the middle
- Improve speed
- Find why my utf8 dot is not well displayed on some terminal ('kitty' is ok, not iTerm2, not Gnome Terminal)
- Handle screen resizing

# Made with

- bash(1)
- bc(1)
- shellcheck(1)
- love, patience, and colors.

# See also

- bc(1), jq(1), jo(1)
- Grafana
- [A nice list of term codes](https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797)
- [UTF8 table and search](https://unicode-table.com/fr)
