#!/bin/bash

set -euo pipefail
export LC_ALL=C

if (( $# == 0 || $# % 2 != 0 )); then
    echo "Usage: $0 <mount> <target> [<mount> <target> ...]" >&2
    exit 1
fi

while (( $# > 0 )); do
    mount_point="$1"
    target="$2"
    shift 2

    if ! [[ "$target" =~ ^[1-9][0-9]*[Gg]$ ]]; then
        echo "Invalid target size: $target" >&2
        exit 1
    fi

    device=$(findmnt -n -o SOURCE --target "$mount_point")
    lvs "$device" >/dev/null 2>&1 || {
        echo "$mount_point is not an LVM logical volume: $device" >&2
        exit 1
    }

    current_bytes=$(lvs --noheadings --units b --nosuffix -o lv_size "$device" | xargs | cut -d. -f1)
    target_number="${target%[Gg]}"
    target_bytes=$((target_number * 1024 * 1024 * 1024))

    if (( current_bytes < target_bytes )); then
        echo "Extending $mount_point ($device) to $target"
        lvextend --resizefs -L "$target" "$device"
    else
        echo "$mount_point is already $target or larger"
    fi
done
