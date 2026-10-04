#!/bin/bash

BAR_FIFO=/tmp/bar-fifo
rm -f $BAR_FIFO
mkfifo $BAR_FIFO

update_time() {
    while true; do
#        if (( sec % 15 == 0 )); then
            date=$(date +"%A %d %B, %R")
            echo 'D' "${date}"
 #       fi
        sleep 15
    done
}

update_battery() {
    while true; do
#        if (( sec % 30 == 0 )); then
            capacity=$(< /sys/class/power_supply/BAT0/capacity)
            status=$(< /sys/class/power_supply/BAT0/status)
            charging_indicator=""
            if [[ "$status" == "Charging" ]]; then
                charging_indicator="+"
            fi
            echo 'B' "${charging_indicator}${capacity}"
#        fi
        sleep 10
 #       ((sec++))
    done
}

update_network() {
    while true; do
	if (( sec % 15 == 0 )); then
        network_status=$(connmanctl state | grep 'State' | awk '{print $3}')
        echo "N $network_status"
	# > $BAR_FIFO &
	fi
	sleep 1
	((sec++))
    done
}

update_groups() {
    while true; do
        current_group=$(ratpoison -c groups | cut -sd'*' -f1)
        total_groups=$(ratpoison -c groups | wc -l)
        echo 'G' "[${current_group}/${total_groups}]"
	sleep 1
    done
}

update_mpc() {
    while true; do
	current_song=$(mpc current)
	[[ -n "$current_song" ]] || current_song=" - stopped -"
	echo 'M' "${current_song}"
	sleep 1
    done
}
update_volume() {
    while true; do
	vol="$([ "$(pamixer --get-mute)" = "false" ] && printf '🔊' || printf '🔇')$(pamixer --get-volume)%"
	echo 'V' "${vol}"
	sleep 1
    done
}

update_backlight() {
    if (( sec % 15 == 0)); then
    read -r actual_brightness </sys/class/backlight/intel_backlight/actual_brightness
    read -r max_brightness </sys/class/backlight/intel_backlight/max_brightness
    backlight="☀$((actual_brightness*100/max_brightness))%"
    echo "L ${backlight}"
    fi
    sleep 1
    ((sec++))
}

# Trap signals for external updates
#trap update_volume SIGRTMIN
#trap update_backlight SIGRTMIN+1
#trap update_time SIGRTMIN+2
#trap update_groups SIGRTMIN+3
#trap update_mpc SIGRTMIN+4
###trap update_network SIGRTMIN+4
#trap update_battery SIGRTMIN+5

update_volume > $BAR_FIFO &
update_time > $BAR_FIFO &
update_battery > $BAR_FIFO &
## update_network > $BAR_FIFO &
update_groups > $BAR_FIFO &
update_mpc > $BAR_FIFO &

while read -r line < $BAR_FIFO; do
    case $line in
        D*) cur_date="${line#?}" ;;
        B*) battery_now="${line#?}" ;;
##        N*) network="${line#?}" ;;
        G*) groups_now="${line#?}" ;;
        M*) mpc_playing="${line#?}" ;;
        V*) vol_now="${line#?}" ;;
    esac
    printf "%s\n" "%{l}${groups_now}%{c}${mpc_playing}%{r}${vol_now}${cur_date}${battery_now}"
done | lemonbar -d -n "bar" -f 'Spleen' -n "bar" -B "#000000"

# 	[ $((sec % 5 )) -eq 0 ] && update_time 	# update time every 5 seconds
# 		[ $((sec % 15)) -eq 0 ] && update_cpu 	# update cpu every 15 seconds
# 		[ $((sec % 15)) -eq 0 ] && update_memory
# 		[ $((sec % 60)) -eq 0 ] && update_bat
# 		[ $((sec % 3600)) -eq 2 ] && update_weather 
# 		#[ $((sec % 300)) -eq 1 ] && update_event
