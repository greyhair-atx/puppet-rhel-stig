#!/bin/bash

set -u
export LC_ALL=C

if (( $# == 0 || $# % 2 != 0 )); then
    echo "Usage: $0 <mount> <target> [<mount> <target> ...]" >&2
    exit 1
fi

total_needed=0
vg_name=""

while (( $# > 0 )); do
    mount_point="$1"
    target="$2"
    shift 2

    device=$(findmnt -n -o SOURCE --target "$mount_point") || {
        echo "Unable to determine device for $mount_point" >&2
        exit 1
    }

    lvs "$device" >/dev/null 2>&1 || {
        echo "$mount_point is not an LVM logical volume: $device" >&2
        exit 1
    }

    current_vg=$(lvs --noheadings -o vg_name "$device" | xargs)
    if [[ -z "$current_vg" ]]; then
        echo "Unable to determine volume group for $device" >&2
        exit 1
    fi

    if [[ -z "$vg_name" ]]; then
        vg_name="$current_vg"
    elif [[ "$vg_name" != "$current_vg" ]]; then
        echo "Configured logical volumes are not in the same volume group" >&2
        exit 1
    fi

    current_bytes=$(lvs --noheadings --units b --nosuffix -o lv_size "$device" | xargs | cut -d. -f1)
    target_number="${target%[Gg]}"
    if ! [[ "$target" =~ ^[1-9][0-9]*[Gg]$ ]]; then
        echo "Invalid target size: $target" >&2
        exit 1
    fi
    target_bytes=$((target_number * 1024 * 1024 * 1024))

    if (( current_bytes < target_bytes )); then
        needed=$((target_bytes - current_bytes))
        total_needed=$((total_needed + needed))
        echo "$mount_point needs $needed additional bytes"
    fi
done

if (( total_needed == 0 )); then
    exit 1
fi

vg_free=$(vgs --noheadings --units b --nosuffix -o vg_free "$vg_name" | xargs | cut -d. -f1)
if [[ -z "$vg_free" ]]; then
    echo "Unable to determine free space in volume group $vg_name" >&2
    exit 1
fi

if (( vg_free < total_needed )); then
    echo "Insufficient free space in volume group $vg_name" >&2
    echo "Required: $total_needed bytes" >&2
    echo "Available: $vg_free bytes" >&2
    exit 1
fi

exit 0
