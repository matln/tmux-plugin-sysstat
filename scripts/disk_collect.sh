#!/usr/bin/env bash

LC_NUMERIC=C

set -u
set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

refresh_interval=$(get_tmux_option "status-interval" "5")
samples_count="60"
disk_util_file="$(get_tmux_option "@sysstat_tmp_dir" "/dev/null")/disk.util"
# disk_util_file="/data/lijianchen/.tmux/plugins/tmux-plugin-sysstat/scripts/disk.util"
device="$(get_tmux_option "@sysstat_io_device" "/dev/sdb")"
# device_array=($device)
# device_num=${#device_array[@]}

get_disk_util() {
  if command_exists "iostat"; then
    iostat -dxm $device "$refresh_interval" "$samples_count" | \
      stdbuf -o0 gawk '{if(length($14)!=0 && substr($14,0,1)!="%")print $14}'
  fi
}

main() {
  get_disk_util | while read -r value; do
    echo "$value" | tee "$disk_util_file"
  done
  # get_disk_util | while read -r -N $(echo "$device_num * 5" | bc) value; do
  #   echo "$value" | sed '$d' | tee "$disk_util_file"
  # done
}

main

