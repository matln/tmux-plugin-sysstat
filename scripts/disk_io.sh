#!/usr/bin/env bash

# Author: https://github.com/matln
# 2020/12/30

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

bar_bg_color=$(get_tmux_option "@disk_bar_bg" "#21222C")
disk_util_file="$(get_tmux_option "@sysstat_tmp_dir" "/dev/null")/disk.util"
# disk_util_file="/data/lijianchen/.tmux/plugins/tmux-plugin-sysstat/scripts/disk.util"
disk_util_pidfile="$(get_tmux_option "@sysstat_tmp_dir" "/dev/null")/disk.pid"
disk_util_percent=$(get_tmux_option "@disk_util_percent" "0")
disk_util_bar=$(get_tmux_option "@disk_util_bar" "0")

get_disk_util() {
  if [ ! -f "$disk_util_file" ]; then
    file_init=$(seq -s "\n" ${disk_num} | sed -r 's/[0-9]+/0.0/g')
    echo -e ${file_init} > ${disk_util_file}
  fi
  cat $disk_util_file

  start_collect_disk_util >/dev/null 2>&1
}

start_collect_disk_util() {
  # check if collect process is running, otherwise start it in background
  if [ -f "$disk_util_pidfile" ] && ps -p "$(cat "$disk_util_pidfile")" > /dev/null 2>&1; then
    return;
  fi
  
  bash "$CURRENT_DIR/disk_collect.sh" &>/dev/null &
  if [ -n "$(jobs -n)" ]; then
    echo "$!" > "${disk_util_pidfile}"
  else
    echo "Failed to start disk collect job" >&2
    exit 1
  fi
}

disk_util=$(get_disk_util)

if [ "${disk_util_bar}" -eq 1 ]; then
  template=" #[fg=#{color}, bg=${bar_bg_color}]#{bar}#[default]"
  disk_view_tmpl=$(get_tmux_option "@disk_view_tmpl" "${template}")
else
  disk_view_tmpl=""
fi

disk_medium_threshold=$(get_tmux_option "@disk_medium_threshold" "10")
disk_stress_threshold=$(get_tmux_option "@disk_stress_threshold" "99")

# 256-color list: https://www.cnblogs.com/guochaoxxl/p/7399886.html
# base_colours=(226 191 156 121 86 51)
base_colours=226

get_bar_color(){
  local color=$2

  if fcomp "$disk_stress_threshold" "$1"; then
    echo "colour$(($color-24))";
  elif fcomp "$disk_medium_threshold" "$1"; then
    echo "colour$(($color-12))";
  else
    echo "colour$color";
  fi
}

# 8ths 
bars=('\u2581' '\u2582' '\u2583' '\u2584' '\u2585' '\u2586' '\u2587' '\u2588')

print_disk_util_bar() {
  local disk_view="$disk_view_tmpl"

  for n in `seq $((${#bars[@]}-1)) -1 0`; do
    if fcomp $((100 * $n / 8)) ${disk_util}; then
      local bar=${bars[$n]}
      # echo -e ${bar}
      break
    fi
  done

  local base_colour=${base_colours}
  local colour=$(get_bar_color ${disk_util} ${base_colour})
  # echo $colour

  if [ "${disk_util_bar}" -eq 1 ]; then
    disk_view="${disk_view//"#{color}"/${colour}}"
    disk_view="${disk_view//"#{bar}"/${bar}}"
  fi

  if [ "${disk_util_percent}" -eq 1 ]; then
    percent_template="#[fg=#{percent_color}, bg=${bar_bg_color}] #{percent_value}#[default]"
    disk_view="${disk_view}${percent_template}"
    disk_view="${disk_view//'#{percent_color}'/${colour}}"
    disk_view="${disk_view//'#{percent_value}'/$(if [ $(echo "$disk_util < 10" | bc) -eq 1 ]; \
      then printf " %.1f%%" "$disk_util"; \
      else printf "%.1f%%" "$disk_util"; \
      fi)}"
  fi

  echo -e "$disk_view"
}

main(){
  print_disk_util_bar
}

main
