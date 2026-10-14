#!/usr/bin/env bash
#
# brightness-osd.sh - change screen brightness and show a slider popup (dunst)
#
# Usage:
#   brightness-osd.sh up [step]     raise brightness (default 5%)
#   brightness-osd.sh down [step]   lower brightness (default 5%)
#   brightness-osd.sh set <5-100>   set exact brightness
#   brightness-osd.sh show          just show the current level

MIN=5     # never go below this, so the screen doesn't turn fully black
STEP=${2:-5}

get_bri() { brightnessctl -m | cut -d',' -f4 | tr -d '%'; }

case "$1" in
	up)   brightnessctl -q set "${STEP}%+" ;;
	down)
		v=$(( $(get_bri) - STEP )); (( v < MIN )) && v=$MIN
		brightnessctl -q set "${v}%"
		;;
	set)
		v=${2//[^0-9]/}; [[ -z "$v" ]] && exit 1
		(( v < MIN )) && v=$MIN
		(( v > 100 )) && v=100
		brightnessctl -q set "${v}%"
		;;
	show|"") ;;
	*) echo "usage: $0 up|down|set N|show" >&2; exit 1 ;;
esac

bri=$(get_bri)

# Same stack-tag trick as the volume popup: replaces the previous popup
# so the bar slides live while you press the keys.
dunstify -a brightness -u low -t 1500 \
	-h string:x-dunst-stack-tag:brightness \
	-h int:value:"$bri" \
	"Brightness: ${bri}%"
