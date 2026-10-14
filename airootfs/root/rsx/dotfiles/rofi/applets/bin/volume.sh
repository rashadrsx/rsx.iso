#!/usr/bin/env bash

## Author  : Aditya Shakya (adi1090x)
## Github  : @adi1090x
#
## Applets : Volume (PipeWire / PulseAudio via pactl, with slider)
#
## Usage:
##  - Select Increase / Decrease repeatedly: the menu stays open and the
##    bar updates like a slider.
##  - Type a number (0-150) and press Enter to jump straight to that level.
##  - Press Esc to close.

# Import Current Theme
source "$HOME"/.config/rofi/applets/shared/theme.bash
theme="$type/$style"

STEP=5      # percent per step
MAX=100     # upper limit when increasing
BAR_LEN=20  # slider width in characters
OSD="$HOME/.local/bin/volume-osd.sh"  # popup slider (dunst)

# Helpers
get_vol()      { pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+(?=%)' | head -n1; }
get_mic_vol()  { pactl get-source-volume @DEFAULT_SOURCE@ | grep -oP '\d+(?=%)' | head -n1; }
is_muted()     { pactl get-sink-mute @DEFAULT_SINK@ | grep -q 'yes'; }
mic_muted()    { pactl get-source-mute @DEFAULT_SOURCE@ | grep -q 'yes'; }
sink_name()    {
	local def
	def="$(pactl get-default-sink)"
	pactl list sinks | awk -v s="$def" '
		$1=="Name:" {found=($2==s)}
		found && /Description:/ {sub(/^[ \t]*Description: /,""); print; exit}'
}

make_bar() {
	local vol=$1 n filled i bar=""
	n=$vol; (( n > 100 )) && n=100
	filled=$(( n * BAR_LEN / 100 ))
	for (( i = 0; i < BAR_LEN; i++ )); do
		(( i < filled )) && bar+="█" || bar+="░"
	done
	printf '%s' "$bar"
}

set_vol() {
	local v=$1
	(( v < 0 )) && v=0
	(( v > 150 )) && v=150
	pactl set-sink-mute @DEFAULT_SINK@ 0
	pactl set-sink-volume @DEFAULT_SINK@ "${v}%"
}

if [[ "$theme" == *'type-1'* ]]; then
	list_col='1'
	list_row='5'
	win_width='400px'
elif [[ "$theme" == *'type-3'* ]]; then
	list_col='1'
	list_row='5'
	win_width='120px'
elif [[ "$theme" == *'type-5'* ]]; then
	list_col='1'
	list_row='5'
	win_width='520px'
elif [[ ( "$theme" == *'type-2'* ) || ( "$theme" == *'type-4'* ) ]]; then
	list_col='5'
	list_row='1'
	win_width='670px'
fi

layout=`cat ${theme} | grep 'USE_ICON' | cut -d'=' -f2`

# Build options/state from current audio status
refresh() {
	speaker="$(get_vol)"
	mic="$(get_mic_vol)"
	mixer="$(sink_name)"
	active=""
	urgent=""

	if is_muted; then
		urgent="-u 1"
		stext='Unmute'
		sicon=''
		sstate='Muted'
	else
		active="-a 1"
		stext='Mute'
		sicon=''
		sstate="${speaker}%"
	fi

	if mic_muted; then
		[ -n "$urgent" ] && urgent+=",3" || urgent="-u 3"
		mtext='Unmute'
		micon=''
		mstate='Muted'
	else
		[ -n "$active" ] && active+=",3" || active="-a 3"
		mtext='Mute'
		micon=''
		mstate="${mic}%"
	fi

	prompt="󰕾 ${speaker}%"
	mesg="${mixer}
$(make_bar "$speaker")  ${sstate}
Mic: ${mstate}"

	if [[ "$layout" == 'NO' ]]; then
		option_1=" Increase"
		option_2="$sicon $stext"
		option_3=" Decrease"
		option_4="$micon Mic $mtext"
		option_5=" Settings"
	else
		option_1=""
		option_2="$sicon"
		option_3=""
		option_4="$micon"
		option_5=""
	fi
}

# Rofi CMD
rofi_cmd() {
	rofi -theme-str "window {width: $win_width;}" \
		-theme-str "listview {columns: $list_col; lines: $list_row;}" \
		-theme-str 'textbox-prompt-colon {str: "";}' \
		-dmenu \
		-p "$prompt" \
		-mesg "$mesg" \
		-selected-row "$selected" \
		${active} ${urgent} \
		-markup-rows \
		-theme ${theme}
}

run_rofi() {
	echo -e "$option_1\n$option_2\n$option_3\n$option_4\n$option_5" | rofi_cmd
}

open_settings() {
	for app in pavucontrol pwvucontrol pavucontrol-qt; do
		if command -v "$app" &>/dev/null; then
			"$app" &
			disown
			return
		fi
	done
	notify-send "Volume" "No mixer app found. Install pavucontrol." 2>/dev/null
}

# Main loop: keeps the menu open for slider-like adjustments
selected=0
while true; do
	refresh
	chosen="$(run_rofi)" || exit 0   # Esc closes
	[ -z "$chosen" ] && exit 0

	case "$chosen" in
		"$option_1")
			"$OSD" up "$STEP"
			selected=0
			;;
		"$option_2")
			"$OSD" mute
			selected=1
			;;
		"$option_3")
			"$OSD" down "$STEP"
			selected=2
			;;
		"$option_4")
			"$OSD" mic
			selected=3
			;;
		"$option_5")
			open_settings
			exit 0
			;;
		*)
			# Typed a number -> set exact volume
			num="${chosen//[^0-9]/}"
			if [[ -n "$num" ]]; then
				"$OSD" set "$num"
			fi
			;;
	esac
done
