#!/usr/bin/env bash
# Hakuspace runtime settings, deployed to ~/hakucfg/setting.sh.
#
# Every hakuspace script sources this file for its paths and toggles. It is the
# upstream v2.3.1 template with this machine's values; phases/30-theme.sh
# rewrites the accent and wallpaper keys from config.env on top of it.
#
# shellcheck disable=SC2034  # every value here is read by hakuspace's scripts

# DO NOT EDIT THIS LINE :v, used for checking setting.sh is up-to-date when run update.sh
SETTING_VERSION="2.3.1"

# Upstream's update.sh runs this file to read the version. Every other caller
# sources it, and a sourced file sees the caller's arguments: without the
# BASH_SOURCE test, running any hakuspace script with -v exits it here with no
# output and no error.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
    echo "$SETTING_VERSION"
    exit 0
fi

# ====== General Settings ======
NIGHT_LIGHT_TEMPERATURE=4000
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# Niri screenshots go through the compositor's own screenshot action, so
# SCREENSHOT_DIR only applies if screenshot.sh is bound by hand. The path niri
# writes to is set by screenshot-path in ~/.config/niri/config.kdl.

# ====== Wallpaper Settings ======
WALL_DIR="$HOME/Pictures/Wallpapers"
WALL_MPV_DIR="$HOME/Videos/Wallpapers"
WALL_INTERVAL=300

# Pinned. With this true, every wallpaper rotation re-derives the accent from
# the image and overwrites the generated theme, which undoes the teal accent
# within one rotation interval. random_wallpaper.sh, wallpaper_select.sh and
# wallpaper_video_select.sh all read this one flag.
ACCENT_COLOR_BASED_ON_WALLPAPER=false

AWWW_OPTS="--transition-type random --transition-step 90 --transition-fps 60"

# Only consulted when ACCENT_COLOR_BASED_ON_WALLPAPER is true.
# One of: vivid, dominant, brightest, saturated.
ACCENT_COLOR_MODE="vivid"

# ====== Screen Recording Settings ======
SCREENREC_SAVE_DIR="$HOME/Videos"
REC_COMMAND="wl-screenrec"
REC_OPTS="--max-fps 60"

# ====== Waybar Theme Settings ======
# Custom modes live in ~/hakucfg/config/waybar/<name>/{config,style.css}.
# A name that collides with a shipped mode loses to the shipped one.
WAYBAR_MODE_USER=()

# ====== Rofi Theme Settings ======
# Drop a "name.rasi" into ~/hakucfg/config/rofi and switch to it from the
# Haku Menu (Theme tab).

# ====== Haku Idle Space Settings (haku.sh) ======
HAKU_CLOCK_FONT_SIZE=10
HAKU_GENERAL_FONT_SIZE=11
HAKU_TERMINAL_FONT_SIZE=14

# ====== Exit Settings (exit.sh) ======
# Threshold for RAM warning (in Megabytes)
RAM_THRESHOLD_MB=300

# Asked to quit, then killed, when leaving the session. These hold unsaved work
# and reopen slowly, so they are worth a graceful shutdown. exit.sh matches them
# against whole command lines, so "jetbrains" covers every IDE in the toolbox
# without matching anything else.
EXIT_APP_LIST_USER=("zen" "code" "jetbrains")
