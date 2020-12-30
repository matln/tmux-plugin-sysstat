#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/scripts/helpers.sh"

placeholders=(
  "\#{sysstat_cpu}"
  "\#{sysstat_cpu_chart}"
  "\#{sysstat_cpu_chart_rainbow}"
  "\#{sysstat_mem}"
  "\#{sysstat_disk_io}"
  "\#{sysstat_swap}"
  "\#{sysstat_loadavg}"
)

commands=(
  "#($CURRENT_DIR/scripts/cpu.sh)"
  "#($CURRENT_DIR/scripts/cpu_chart.sh)"
  "#($CURRENT_DIR/scripts/cpu_chart_rainbow.sh)"
  "#($CURRENT_DIR/scripts/mem.sh)"
  "#($CURRENT_DIR/scripts/disk_io.sh)"
  "#($CURRENT_DIR/scripts/swap.sh)"
  "#($CURRENT_DIR/scripts/loadavg.sh)"
)

do_interpolation() {
  local all_interpolated="$1"
  for ((i=0; i<${#commands[@]}; i++)); do
    all_interpolated=${all_interpolated//${placeholders[$i]}/${commands[$i]}}
  done
  echo "$all_interpolated"
}

update_tmux_option() {
  local option="$1"
  local option_value="$(get_tmux_option "$option")"
  local new_option_value="$(do_interpolation "${option_value}")"
  set_tmux_option "$option" "${new_option_value}"
}

main() {
  tmp_dir=$(mktemp -d /tmp/tmux_log.XXXX)
  tmux set-option -gq "@sysstat_tmp_dir" "$tmp_dir"

  update_tmux_option "status-right"
  update_tmux_option "status-left"
}

main
