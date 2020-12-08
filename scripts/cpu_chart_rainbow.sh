#!/bin/bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

cpu_tmp_dir=$(tmux show-option -gqv "@sysstat_cpu_tmp_dir")
chart_width=$(get_tmux_option "@cpu_chart_width" "10")
chart_bg_color=$(get_tmux_option "@cpu_chart_bg" "#343746")
cpu_used_percent=$(get_tmux_option "@cpu_chart_with_percent" "0")

template=''
for n in `seq 0 $(($chart_width-1))`; do
  template=${template}"#[fg=#{color${n}}, bg=${chart_bg_color}]#{bar${n}}#[default]"
done
cpu_view_tmpl=${template}

cpu_medium_threshold=$(get_tmux_option "@cpu_chart_medium_threshold" "30")
cpu_stress_threshold=$(get_tmux_option "@cpu_chart_stress_threshold" "70")

# #00ff00: lime, #ffff00: yellow, #ff0000: red
cpu_color_low=$(get_tmux_option "@cpu_chart_color_low" "#00ff00")
cpu_color_medium=$(get_tmux_option "@cpu_chart_color_medium" "#ffff00")
cpu_color_stress=$(get_tmux_option "@cpu_chart_color_stress" "#ff0000")

# https://github.com/guns/xterm-color-table.vim
base_color=(colour155 colour154 colour148 colour142 colour136 colour130 colour124)
# 8ths 
bars=('\u2581' '\u2582' '\u2583' '\u2584' '\u2585' '\u2586' '\u2587' '\u2588')

get_bar_color(){
  local cpu_used=$1

  if fcomp "$cpu_stress_threshold" "$cpu_used"; then
    echo "$cpu_color_stress";
  elif fcomp "$cpu_medium_threshold" "$cpu_used"; then
    echo "$cpu_color_medium";
  else
    echo "$cpu_color_low";
  fi
}

print_cpu_usage_chart() {
  local cpu_usage=$(get_cpu_usage_history)
  cpu_usage=(${cpu_usage//\n/ })
  local cpu_view=${cpu_view_tmpl}

  if [ ${#cpu_usage[@]} -ne ${chart_width} ]; then
    # echo "Initializing..."
    echo "An error occurred"
    exit 1
  fi

  for bar_idx in `seq 0 $(($chart_width-1))`; do
    for n in `seq $((${#bars[@]}-1)) -1 0`; do
      if fcomp $((100 * $n / 8)) ${cpu_usage[$bar_idx]}; then
        local bar=${bars[$n]}
        break
      fi
    done

    local color_idx=$n
    if [ $color_idx -eq 7 ]; then
      (( color_idx=color_idx-1 ))
    fi
    local colour=${base_color[${color_idx}]}
    cpu_view="${cpu_view//"#{color${bar_idx}}"/${colour}}"
    cpu_view="${cpu_view//"#{bar${bar_idx}}"/${bar}}"
  done

  if [ ${cpu_used_percent} -eq 1 ]; then
    # the last item
    local cpu_usage_current="${cpu_usage[${#cpu_usage[@]}-1]}"
    local cpu_current_color=$(get_bar_color "$cpu_usage_current")
    percent_template="#[fg=#{cpu_color}, bg=${chart_bg_color}] #{cpu_current}#[default]"
    cpu_view="${cpu_view}${percent_template}"
    cpu_view="${cpu_view//'#{cpu_color}'/${cpu_current_color}}"
    cpu_view="${cpu_view//'#{cpu_current}'/$(if [ $(echo "$cpu_usage_current < 10" | bc) -eq 1 ]; \
      then printf " %.1f%%" "$cpu_usage_current"; \
      else printf "%.1f%%" "$cpu_usage_current"; \
      fi)}"
  fi

  echo -e "$cpu_view"
}

get_cpu_usage_history() {
  local cpu_used_log
  cpu_used_log="$cpu_tmp_dir/cpu_used_history.log"
  if [ ! -f "$cpu_used_log" ]; then
    log_init=$(seq -s "\n" ${chart_width} | sed -r 's/[0-9]+/0.0/g')
    echo -e ${log_init} > ${cpu_used_log}
  fi
  cat $cpu_used_log

  start_collect_cpu_usage_history >/dev/null 2>&1
}

start_collect_cpu_usage_history() {
  local collect_cpu_pidfile
  collect_cpu_pidfile="$cpu_tmp_dir/cpu_used_history.pid"

  # check if cpu collect process is running, otherwise start it in background
  if [ -f "$collect_cpu_pidfile" ] && ps -p "$(cat "$collect_cpu_pidfile")" > /dev/null 2>&1; then
    return;
  fi
  
  bash "$CURRENT_DIR/cpu_used_history.sh" &>/dev/null &
  if [ -n "$(jobs -n)" ]; then
    echo "$!" > "${collect_cpu_pidfile}"
  else
    echo "Failed to start CPU collect job" >&2
    exit 1
  fi
}

main(){
  print_cpu_usage_chart
}

main
