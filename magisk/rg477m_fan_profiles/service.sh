#!/system/bin/sh
# Started by Magisk after boot: keep the fan daemon running.
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
[ -n "$(getprop persist.rg477m.fan_profile)" ] || setprop persist.rg477m.fan_profile smart
while true; do
  sh "$MODDIR/fan_daemon.sh" >/dev/null 2>&1
  sleep 5
done &
