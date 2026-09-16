#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - AllTube Configuration Helper                    #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

basefolder="/opt/appdata"
typed="alltube"
config_dir="$basefolder/${typed}"
mkdir -p "$config_dir"

if [[ ! -f "$config_dir/config.yml" && ! -f "$config_dir/config.json" ]]; then
    cat <<'EOF' > "$config_dir/config.yml"
---
# Path to your youtube-dl or yt-dlp binary
youtubedl: vendor/rg3/youtube-dl/youtube_dl/__main__.py

# Path to your python binary
python: /usr/bin/python

# An array of parameters to pass to youtube-dl
params:
    - --no-warnings
    - --ignore-errors
    - --flat-playlist
    - --restrict-filenames

# True to enable audio conversion
convert: false

# True to enable advanced conversion mode
convertAdvanced: false

# List of formats available in advanced conversion mode
convertAdvancedFormats: [mp3, avi, flv, wav]

# Path to your avconv or ffmpeg binary
avconv: vendor/bin/ffmpeg

# avconv/ffmpeg logging level.
avconvVerbosity: error

# Path to the directory that contains the phantomjs binary.
phantomjsDir: vendor/bin/

# True to disable URL rewriting
uglyUrls: false

# True to stream videos through server
stream: false

# MP3 bitrate when converting (in kbit/s)
audioBitrate: 128
EOF
    # Symlink config.json to config.yml for backwards compatibility
    ln -sf "$config_dir/config.yml" "$config_dir/config.json"
    chown -R 1000:1000 "$config_dir" 2>/dev/null || true
fi
