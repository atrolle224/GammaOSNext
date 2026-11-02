#!/system/bin/sh
# Game Mode: while an emulator or game is in front, the game profile applies
# (performance, fan, bypass charging, refresh rate); back at Daijishou or Android,
# the settings from before come back. Off with persist.rg477m.gamemode=off.
MODDIR=${0%/*}; . "$MODDIR/common.sh"; . "$MODDIR/tk.sh"
GAMES='com.retroarch.* org.dolphinemu.* com.armsx2.* com.rfandango.haku_x* org.ppsspp.* com.flycast.emulator* org.mupen64plusae.* com.github.stenzek.duckstation* com.dsemu.drastic* com.ast.openmw* org.opennv.* gamehub.* com.antutu.ABenchMark com.xiaoji.* com.winlator* com.nanodata.* come.nanodata.*'
USER_LIST=$CFG/games.conf

is_game() {
  for g in $GAMES $(cat "$USER_LIST" 2>/dev/null); do
    case "$1" in $g) return 0 ;; esac
  done
  return 1
}

front() {
  dumpsys activity activities 2>/dev/null | sed -n 's/.*topResumedActivity=ActivityRecord{[^ ]* [^ ]* \([^/ ]*\)\/.*/\1/p' | head -1
}

current() {
  fm=$(getprop persist.gammaos.fan_mode)
  [ "$fm" = custom ] && fan=$(getprop persist.rg477m.fan_profile) || fan=gammaos
  pm=$(getprop persist.gammaos.performance_mode); pp=$(getprop persist.rg477m.perf_profile)
  case "$pm" in max) perf=max ;; powersave) perf=powersave ;; *) perf=${pp:-normal} ;; esac
  ch=$(getprop persist.rg477m.charge); [ -n "$ch" ] || ch=off
  rr=$(getprop persist.rg477m.refresh); [ -n "$rr" ] || rr=$(getprop persist.gammaos.refresh.rate)
  echo "$perf $fan $ch ${rr:-60}"
}

apply() {   # perf fan charge refresh: only what differs is changed
  c=$(current)
  [ "$1" != "$(echo $c | cut -d' ' -f1)" ] && set_perf "$1"
  [ "$2" != "$(echo $c | cut -d' ' -f2)" ] && set_fan "$2"
  [ "$3" != "$(echo $c | cut -d' ' -f3)" ] && set_charge "$3"
  [ "$4" != "$(echo $c | cut -d' ' -f4)" ] && set_refresh "$4"
}

# a restart mid-game keeps the settings saved before the game
[ "$(getprop persist.rg477m.gm_active)" = 1 ] && state=game || state=menu
while true; do
  sleep 4
  if [ "$(getprop persist.rg477m.gamemode)" = off ]; then
    [ "$state" = game ] && { apply $(getprop persist.rg477m.gm_saved); state=menu; setprop persist.rg477m.gm_active 0; log "game mode: off"; }
    continue
  fi
  [ "$(getprop sys.screen.state)" = off ] && continue
  pkg=$(front); [ -n "$pkg" ] || continue
  if is_game "$pkg"; then
    if [ "$state" = menu ]; then
      setprop persist.rg477m.gm_saved "$(current)"
      ch=$(getprop persist.rg477m.charge); [ "$(getprop persist.rg477m.gm_charge)" = keep ] || ch=bypass
      apply "$(getprop persist.rg477m.gm_perf | sed 's/^$/balanced/')" \
            "$(getprop persist.rg477m.gm_fan | sed 's/^$/smart/')" "${ch:-off}" \
            "$(getprop persist.rg477m.gm_refresh | sed 's/^$/120/')"
      state=game; setprop persist.rg477m.gm_active 1; log "game mode: on ($pkg)"
    fi
  else
    case "$pkg" in com.android.systemui|android|com.android.permissioncontroller|com.google.android.permissioncontroller|com.topjohnwu.magisk) continue ;; esac
    if [ "$state" = game ]; then
      apply $(getprop persist.rg477m.gm_saved)
      state=menu; setprop persist.rg477m.gm_active 0; log "game mode: back to $(getprop persist.rg477m.gm_saved) ($pkg)"
    fi
  fi
done
