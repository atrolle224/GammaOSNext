#!/system/bin/sh
# Magisk Action menu. Volume Up = next choice, Volume Down = pick. 30 s without a key: exit.
MODDIR=${0%/*}; . "$MODDIR/tk.sh"
key() {
  while true; do
    if command -v timeout >/dev/null; then ev=$(timeout 30 getevent -lqc 1 2>/dev/null) || return 1
    else ev=$(getevent -lqc 1 2>/dev/null); fi
    case "$ev" in
      *KEY_VOLUMEUP*DOWN*) KEY=up; return 0 ;;
      *KEY_VOLUMEDOWN*DOWN*) KEY=down; return 0 ;;
    esac
  done
}
# choose "Title" "label=value" ...  -> CHOICE=value (empty on timeout)
choose() {
  echo; echo "== $1"; shift; n=$#; i=1; CHOICE=""
  while true; do
    eval "item=\${$i}"; echo "   > ${item%%=*}"
    key || { echo "(no key pressed, nothing changed)"; return 1; }
    [ "$KEY" = down ] && { CHOICE=${item#*=}; echo "   selected: ${item%%=*}"; return 0; }
    i=$(( i % n + 1 ))
  done
}
echo "RG477M Toolkit"; status
echo "Volume Up: next   Volume Down: select"
choose "What to change?" "Fan=fan" "Performance=perf" "Charging=charge" "Refresh rate=refresh" "Render resolution=res" "Game Mode=gm" "Save backup=bk" "Exit=exit" || exit 0
case "$CHOICE" in
  fan) choose "Fan profile" "Smart: on from 50 C, full at 85 C=smart" "Silent: on from 58 C, full at 92 C=silent" "Extreme: always on, full at 74 C=extreme" "Custom (fan_curve.conf)=custom" "GammaOS Auto=gammaos" && set_fan "$CHOICE" ;;
  perf) choose "Performance" "Balanced: full speed, clocks drop when idle=balanced" "Efficient: about 75%, cooler and quieter=efficient" "Battery: light and retro games=battery" "GammaOS Normal=normal" "GammaOS Max=max" "GammaOS Powersave=powersave" && set_perf "$CHOICE" ;;
  charge) choose "Charging" "Stop at 80% (battery lasts longer)=80" "Stop at 90%=90" "Bypass while playing (screen on)=bypass" "Normal, charge to 100%=off" && set_charge "$CHOICE" ;;
  refresh) choose "Refresh rate" "90 Hz=90" "120 Hz=120" "60 Hz=60" && set_refresh "$CHOICE" ;;
  res) choose "Render resolution (lower = faster, less battery)" "100%: 1280x960=100" "87%: 1120x840=87" "75%: 960x720=75" && set_res "$CHOICE" ;;
  gm) choose "Game Mode (while an emulator or game is open)" "On=on" "Off=off" "Games: full speed (Balanced)=perf:balanced" "Games: GammaOS Max=perf:max" "Games: cooler (Efficient)=perf:efficient" "Games at 120 Hz=refresh:120" "Games at 60 Hz (less battery)=refresh:60" "Games at 90 Hz=refresh:90" || exit 0
      case "$CHOICE" in on|off) set_gamemode "$CHOICE" ;; *) set_gm "${CHOICE%%:*}" "${CHOICE#*:}" ;; esac ;;
  bk) choose "Save backup (daily, screen off, newest 7 kept)" "Back up now=now" "On=on" "Off=off" && set_backup "$CHOICE" ;;
  *) exit 0 ;;
esac
sleep 1; echo; status
