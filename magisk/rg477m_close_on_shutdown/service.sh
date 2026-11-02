#!/system/bin/sh
# Shutdown or reboot: every user-installed app is closed first, except Daijishou (and the
# keyboard and Magisk), so nothing comes back half-open and Recents is clear after boot.
# Keep more apps open: one package per line in /data/adb/rg477m/keep_open.conf
CFG=/data/adb/rg477m; mkdir -p $CFG
LOG=$CFG/close_on_shutdown.log
log_line() { echo "$(date '+%m-%d %H:%M:%S') $*" >> $LOG; }
KEEP="com.magneticchen.daijishou com.topjohnwu.magisk"

MODDIR=${0%/*}
# Recents, as its "Clear all" does (Android keeps the list across a reboot)
clear_recents() {
  CLASSPATH="$MODDIR/clearrecents.dex" app_process / ClearRecents >/dev/null 2>&1 && return 0
  log_line "recents: couldn't clear"; return 1
}

close_all() {
  ime=$(settings get secure default_input_method 2>/dev/null | cut -d/ -f1)
  n=0
  for p in $(pm list packages -3 2>/dev/null | sed 's/^package://'); do
    case " $KEEP $ime $(cat $CFG/keep_open.conf 2>/dev/null | tr '\n' ' ') " in *" $p "*) continue ;; esac
    am force-stop "$p" 2>/dev/null && n=$((n + 1))
  done
  clear_recents
  echo "$(date '+%m-%d %H:%M:%S') $1: closed $n apps" >> $LOG
}

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
# whatever Android restored into Recents at boot goes too
sleep 15
clear_recents && log_line "boot: recents cleared"
log_line "watching for shutdown (apps: $(pm list packages -3 | wc -l), recents: $(dumpsys activity recents 2>/dev/null | grep -c 'Recent #'))"
while true; do
  r=$(getprop sys.shutdown.requested)$(getprop sys.powerctl)
  if [ -n "$r" ]; then
    close_all "$r"
    sleep 60
  fi
  sleep 1
done
