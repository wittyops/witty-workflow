#!/bin/bash
# Wrapper for kiwix-serve that globs all ZIM files in the ZIM directory.
# kiwix-serve doesn't accept a directory path — each ZIM must be a positional arg.
# Waits up to 5 minutes if no ZIMs present yet (handles race on first boot).
#
# Managed by systemd: /etc/systemd/system/kiwix-serve.service
# ZIM storage:        /data/witty-lab-data/kiwix-zims/

ZIMS_DIR="/data/witty-lab-data/kiwix-zims"

while true; do
    ZIMS=( "$ZIMS_DIR"/*.zim )
    if [ -e "${ZIMS[0]}" ]; then
        break
    fi
    echo "No ZIM files found in $ZIMS_DIR — waiting 30s..."
    sleep 30
done

echo "Starting kiwix-serve with ${#ZIMS[@]} ZIM(s): ${ZIMS[*]}"
exec /usr/bin/kiwix-serve --port=8282 --address=0.0.0.0 --nodatealiases "${ZIMS[@]}"
