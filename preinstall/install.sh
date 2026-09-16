#!/bin/bash
#
# Title:      headinstaller based of matched OS
# Author(s):  mrdoob
# GNU:        General Public License v3.0
################################################
# Idea from poppabear8883 from UNIT3D
###########################№####################
os_id="$(. /etc/os-release 2>/dev/null && echo "$ID" || true)"
os_like="$(. /etc/os-release 2>/dev/null && echo "${ID_LIKE:-}" || true)"

case "$os_id" in
    ubuntu|debian|raspbian|rasbian|linuxmint|pop|zorin|elementary) type="ubuntu" ;;
    *)
        if [[ "$os_like" =~ (ubuntu|debian) ]]; then
            type="ubuntu"
        else
            type=''
        fi
        ;;
esac
if [ -f ./installer/$type.sh ]; then bash ./installer/$type.sh; fi
#"
