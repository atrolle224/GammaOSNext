#!/system/bin/sh
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
[ -n "$(getprop persist.rg477m.fan_profile)" ] || setprop persist.rg477m.fan_profile smart
keep() { while true; do sh "$MODDIR/$1" >/dev/null 2>&1; sleep 5; done & }
keep fan_daemon.sh
keep perf_daemon.sh
keep charge_daemon.sh
keep gamemode_daemon.sh
keep backup_daemon.sh
sh "$MODDIR/display.sh" boot &
