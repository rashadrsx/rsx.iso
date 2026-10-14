# Keyboard: US + Arabic. Super+Space (and Alt+Shift) switch layouts.
# NOTE: every setxkbmap call rewrites the WHOLE keymap, so all options must be
# in one call, and xmodmap must run AFTER it - otherwise each line wipes the
# previous ones (that is why caps/Super_R/layout kept disappearing).
setxkbmap -model pc105+inet -layout us,ara \
    -option terminate:ctrl_alt_bksp \
    -option grp:win_space_toggle \
    -option grp:alt_shift_toggle \
    -option caps:escape
xmodmap -e "keycode 135 = Super_R"

# only start these if they are installed
command -v variety >/dev/null 2>&1 && variety &
# xfce4-clipman &
greenclip daemon &
command -v blueberry-tray >/dev/null 2>&1 && blueberry-tray &
feh --bg-fill ~/Pictures/Screenshots/Screenshot\ From\ 2026-09-27\ 21-01-07.png 
exit 0
# ~/.local/bin/monitor.sh
# xrandr --output eDP-1 --primary --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-4 --off --output HDMI-1 --off --output DP-5 --off --output HDMI-2 --mode 1920x1080 --pos 0x0 --rotate normal --output DP-6 --off --output HDMI-3 --off --output VGA-1-0 --off --output DP-1-0 --off --output DP-1-1 --off --output DP-1-2 --off --output DP-1-3 --off --output DP-1-4 --off --output DP-1-5 --off
