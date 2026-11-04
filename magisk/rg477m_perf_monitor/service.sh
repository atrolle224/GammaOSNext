#!/system/bin/sh
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
sleep 20
[ -f /data/adb/rg477m/perf_off ] || nohup sh "$MODDIR/perfmon.sh" >/dev/null 2>&1 &
