#!/system/bin/sh
MODDIR=${0%/*}
mkdir -p /data/adb/rg477m
if [ -f /data/adb/rg477m/perf_off ]; then
  rm -f /data/adb/rg477m/perf_off
  pkill -f "$MODDIR/perfmon.sh" 2>/dev/null
  nohup sh "$MODDIR/perfmon.sh" >/dev/null 2>&1 &
  echo "Performance monitor ON: open a game, play, then leave it to get a report in Download/RG477M-perf."
else
  touch /data/adb/rg477m/perf_off
  pkill -f "$MODDIR/perfmon.sh" 2>/dev/null
  echo "Performance monitor OFF."
fi
