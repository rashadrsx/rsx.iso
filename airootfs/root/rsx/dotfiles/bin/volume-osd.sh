#!/usr/bin/env bash
#
# volume-osd.sh - change volume and show a slider popup (dunst progress bar)
#
# Usage:
#   volume-osd.sh up [step]     raise volume (default 5%)
#   volume-osd.sh down [step]   lower volume (default 5%)
#   volume-osd.sh set <0-150>   set exact volume
#   volume-osd.sh mute          toggle speaker mute
#   volume-osd.sh mic           toggle mic mute
#   volume-osd.sh show          just show the current level

MAX=100   # 'up' will not go past this
STEP=${2:-5}

get_vol()   { pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+(?=%)' | head -n1; }
is_muted()  { pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes; }
mic_muted() { pactl get-source-mute @DEFAULT_SOURCE@ | grep -q yes; }

case "$1" in
	up)
		pactl set-sink-mute @DEFAULT_SINK@ 0
		v=$(( $(get_vol) + STEP )); (( v > MAX )) && v=$MAX
		pactl set-sink-volume @DEFAULT_SINK@ "${v}%"
		;;
	down)
		pactl set-sink-mute @DEFAULT_SINK@ 0
		pactl set-sink-volume @DEFAULT_SINK@ "-${STEP}%"
		;;
	set)
		v=${2//[^0-9]/}; [[ -z "$v" ]] && exit 1
		(( v > 150 )) && v=150
		pactl set-sink-mute @DEFAULT_SINK@ 0
		pactl set-sink-volume @DEFAULT_SINK@ "${v}%"
		;;
	mute) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
	mic)
		pactl set-source-mute @DEFAULT_SOURCE@ toggle
		if mic_muted; then
			dunstify -a volume -u low -h string:x-dunst-stack-tag:volume \
				"Microphone" "Muted"
		else
			dunstify -a volume -u low -h string:x-dunst-stack-tag:volume \
				"Microphone" "On"
		fi
		exit 0
		;;
	show|"") ;;
	*) echo "usage: $0 up|down|set N|mute|mic|show" >&2; exit 1 ;;
esac

vol=$(get_vol)

if is_muted; then
	title="Volume: Muted"
	vol_bar=0
else
	title="Volume: ${vol}%"
	vol_bar=$vol
fi

# The stack tag replaces the previous popup instead of stacking a new one,
# so the bar slides live while you press the keys.
dunstify -a volume -u low -t 1500 \
	-h string:x-dunst-stack-tag:volume \
	-h int:value:"$vol_bar" \
	"$title"
