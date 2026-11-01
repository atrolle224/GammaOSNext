#!/system/bin/sh
# Charge limit, bypass charging and battery heat protection, using MediaTek's charger switch
# /proc/mtk_battery_cmd/current_cmd ("0 0" = charge, "0 1" = don't charge the battery; the
# charger still powers the device). Charging is always switched back on when the module stops.
MODDIR=${0%/*}; . "$MODDIR/common.sh"
SW=/proc/mtk_battery_cmd/current_cmd
B=/sys/class/power_supply/battery
[ -w $SW ] || { log "charge: $SW missing, charging features off"; exit 0; }
state=on
charge() {   # $1 on|off
  [ "$state" = "$1" ] && return
  if [ "$1" = off ]; then echo "0 1" > $SW; else echo "0 0" > $SW; fi
  state=$1; log "charge: $1 ($why, $lvl%, ${tc}C)"
}
trap 'echo "0 0" > $SW; exit 0' TERM INT
echo "0 0" > $SW
while true; do
  mode=$(getprop persist.rg477m.charge); [ -n "$mode" ] || mode=off
  lvl=$(cat $B/capacity 2>/dev/null); case "$lvl" in ""|*[!0-9]*) lvl=50;; esac; tc=$(( $(cat $B/temp 2>/dev/null || echo 300) / 10 ))
  plugged=0; for o in /sys/class/power_supply/primary_chg/online /sys/class/power_supply/mtk-master-charger/online; do [ "$(cat $o 2>/dev/null)" != 0 ] && [ -n "$(cat $o 2>/dev/null)" ] && plugged=1; done
  want=on; why=normal
  case "$mode" in
    80) limit=80 ;; 90) limit=90 ;; *) limit=100 ;;
  esac
  # charge limit with a 5% gap so it does not flick on and off
  if [ "$limit" -lt 100 ]; then
    if [ "$lvl" -ge "$limit" ]; then want=off; why="limit $limit"
    elif [ "$state" = off ] && [ "$lvl" -gt $((limit - 5)) ]; then want=off; why="limit $limit"; fi
  fi
  # bypass: while the screen is on and plugged in, run from the charger and leave the battery alone
  if [ "$mode" = bypass ] && [ "$(getprop sys.screen.state)" != off ] && [ "$lvl" -ge 20 ]; then want=off; why=bypass; fi
  # heat protection in every mode: pause at 45 C, resume at 40 C
  if [ "$(getprop persist.rg477m.charge_heat)" != 0 ]; then
    if [ "$tc" -ge 45 ]; then want=off; why=hot; hot=1
    elif [ "${hot:-0}" = 1 ] && [ "$tc" -gt 40 ]; then want=off; why=hot
    else hot=0; fi
  fi
  # never hold charging off below 15% (the charger may not be keeping up)
  [ "$lvl" -lt 15 ] && want=on
  [ "$plugged" = 1 ] || want=on
  charge $want
  sleep 10
done
