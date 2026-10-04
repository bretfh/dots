#!/bin/bash
#RESOURCE="${@: -1}"
RESOURCE="$1"

RESOURCE="${RESOURCE/file:\/\//}"

if [[ "$RESOURCE" =~ ^https?:// ]]; then
    alacritty -e emacsclient -t -a '' --eval "(eww \"$RESOURCE\")"
elif [[ "$RESOURCE" =~ ^mailto:// ]]; then
    alacritty -e emacsclient -t -a '' --eval "(compose-mail \"$RESOURCE\")"
elif [[ "$RESOURCE" =~ ^git:// ]]; then
    alacritty -e emacsclient -t -a '' --eval "(magit-clone \"$RESOURCE\")"
else
    alacritty -e emacsclient -t -a '' --eval "(find-file \"$RESOURCE\")"
fi
