#!/usr/bin/env bash

LC_NUMERIC=C

set -u
set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

refresh_interval=$(get_tmux_option "status-interval" "5")
samples_count="60"
cpu_used_history_file="$(get_tmux_option "@sysstat_tmp_dir" "/dev/null")/cpu_used_history.log"

get_cpu_usage() {
  if is_osx; then
    if command_exists "iostat"; then
      iostat -w "$refresh_interval" -c "$samples_count" \
        | stdbuf -o0 awk 'NR > 2 { print 100-$(NF-3); }'
    else
      top -l "$samples_count" -s "$refresh_interval" -n 0 \
        | sed -u -nr '/CPU usage/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*idle.*/\1/p' \
        | stdbuf -o0 awk '{ print 100-$0 }'
    fi
  elif ! command_exists "vmstat"; then
    if is_freebsd; then
      vmstat -n "$refresh_interval" -c "$samples_count" \
        | stdbuf -o0 awk 'NR>2 {print 100-$(NF-0)}'
    else
      vmstat -n "$refresh_interval" "$samples_count" \
        | stdbuf -o0 awk 'NR>2 {print 100-$(NF-2)}'
    fi
  else
    if is_freebsd; then
      top -d"$samples_count" \
        | sed -u -nr '/CPU:/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)%[[:space:]]*id.*/\1/p' \
        | stdbuf -o0 awk '{ print 100-$0 }'
    else
      if [ -x "$(command -v gawk)" ]; then
        # For ubuntu18.04, stdbuf and awk cause an extremely long delay in CPU usage updates
        # https://github.com/samoshkin/tmux-plugin-sysstat/issues/16
        # replace awk with gawk
        top -b -n "$samples_count" -d "$refresh_interval" \
          | sed -u -nr '/%Cpu/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)[[:space:]]*id.*/\1/p' \
          | stdbuf -o0 gawk '{ print 100-$0 }'
      else
        top -b -n "$samples_count" -d "$refresh_interval" \
          | sed -u -nr '/%Cpu/s/.*,[[:space:]]*([0-9]+[.,][0-9]*)[[:space:]]*id.*/\1/p' \
          | stdbuf -o0 awk '{ print 100-$0 }'
      fi
    fi
  fi
}

main() {
  get_cpu_usage | while read -r value; do
    # -a: append
    echo "$value" | tee -a "$cpu_used_history_file"
    # delete the first line
    sed -i '1d' $cpu_used_history_file
  done
}

main

