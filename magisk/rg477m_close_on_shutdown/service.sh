#!/system/bin/sh
# Shutdown or reboot: every user-installed app is closed first, except Daijishou (and the
# keyboard and Magisk), so nothing comes back half-open and Recents is clear after boot.
# Keep more apps open: one package per line in /data/adb/rg477m/keep_open.conf
CFG=/data/adb/rg477m; mkdir -p $CFG
LOG=$CFG/close_on_shutdown.log
KEEP="com.magneticchen.daijishou com.topjohnwu.magisk"

close_all() {
  ime=$(settings get secure default_input_method 2>/dev/null | cut -d/ -f1)
  n=0
  for p in $(pm list packages -3 2>/dev/null | sed 's/^package://'); do
    case " $KEEP $ime $(cat $CFG/keep_open.conf 2>/dev/null | tr '\n' ' ') " in *" $p "*) continue ;; esac
    am force-stop "$p" 2>/dev/null && n=$((n + 1))
  done
  # Recents: Android 14 keeps the task list across a reboot
  cmd activity clear-recent-apps >/dev/null 2>&1 || am clear-recent-apps >/dev/null 2>&1
  echo "$(date '+%m-%d %H:%M:%S') $1: closed $n apps" >> $LOG
}

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
while true; do
  # Magisk's resetprop waits for the property without polling; fall back to a short poll
  if resetprop -w sys.shutdown.requested "" 2>/dev/null; then :; else
    while [ -z "$(getprop sys.shutdown.requested)" ] && [ -z "$(getprop sys.powerctl)" ]; do sleep 1; done
  fi
  r=$(getprop sys.shutdown.requested)$(getprop sys.powerctl)
  [ -n "$r" ] || continue
  close_all "$r"
  # once per shutdown: wait for the power-off
  sleep 60
done
