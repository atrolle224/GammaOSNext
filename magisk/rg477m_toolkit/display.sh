#!/system/bin/sh
# display.sh refresh 60|90|120   and   display.sh res 100|87|75   and   display.sh boot
MODDIR=${0%/*}; . "$MODDIR/common.sh"
set_90() {
  # GammaOS only knows 60/120: put it on 60 (no 120 lock) and wait for its script to finish
  if [ "$(getprop persist.gammaos.refresh.rate)" != 60 ]; then setprop persist.gammaos.refresh.rate 60; sleep 8; fi
  setprop persist.gammaos.refresh.lock 0
  settings put system default_refresh_rate 90
  settings put system min_refresh_rate 90
  settings put system peak_refresh_rate 90
  cmd display set-user-preferred-display-mode 0 1280 960 90
  log "display: 90 Hz"
}
set_res() {
  case "$1" in
    87) wm size 1120x840; wm density 245 ;;
    75) wm size 960x720; wm density 210 ;;
    *) wm size reset; wm density reset ;;
  esac
  log "display: resolution $1%"
}
case "$1" in
  refresh)
    setprop persist.rg477m.refresh "$2"
    case "$2" in 90) set_90 ;; 60|120) setprop persist.gammaos.refresh.rate "$2"; log "display: $2 Hz (GammaOS)" ;; esac ;;
  res) setprop persist.rg477m.res "$2"; set_res "$2" ;;
  boot)
    [ "$(getprop persist.rg477m.refresh)" = 90 ] && { sleep 15; set_90; }
    r=$(getprop persist.rg477m.res); [ -n "$r" ] && [ "$r" != 100 ] && set_res "$r" ;;
esac
