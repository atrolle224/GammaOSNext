#!/system/bin/sh
# Settings shared by the Magisk Action menu and the "rg477m" command.
MODDIR=${MODDIR:-/data/adb/modules/rg477m_toolkit}
set_fan() {   # gammaos|silent|smart|extreme|custom
  if [ "$1" = gammaos ]; then setprop persist.gammaos.fan_mode auto
  else setprop persist.rg477m.fan_profile "$1"; setprop persist.gammaos.fan_mode custom; fi
}
set_perf() {  # max|normal|balanced|efficient|battery|powersave
  case "$1" in
    max) setprop persist.rg477m.perf_profile ""; setprop persist.gammaos.performance_mode max ;;
    powersave) setprop persist.rg477m.perf_profile ""; setprop persist.gammaos.performance_mode powersave ;;
    normal) setprop persist.rg477m.perf_profile ""; setprop persist.gammaos.performance_mode stock; start setclock_stock ;;
    *) # start from GammaOS stock so the profile's caps apply to full clocks
       setprop persist.rg477m.perf_profile "$1"
       if [ "$(getprop persist.gammaos.performance_mode)" = stock ]; then start setclock_stock; else setprop persist.gammaos.performance_mode stock; fi ;;
  esac
}
set_charge() { setprop persist.rg477m.charge "$1"; }   # off|80|90|bypass
set_refresh() { sh "$MODDIR/display.sh" refresh "$1" >/dev/null 2>&1 & }
set_res() { sh "$MODDIR/display.sh" res "$1"; }
status() {
  fm=$(getprop persist.gammaos.fan_mode)
  [ "$fm" = custom ] && fan="$(getprop persist.rg477m.fan_profile)" || fan="GammaOS $fm"
  pm=$(getprop persist.gammaos.performance_mode); pp=$(getprop persist.rg477m.perf_profile)
  [ "$pm" = stock ] && [ -n "$pp" ] && perf=$pp || perf="GammaOS $pm"
  ch=$(getprop persist.rg477m.charge); [ -n "$ch" ] || ch=off
  rr=$(getprop persist.rg477m.refresh); [ "$rr" = 90 ] || rr=$(getprop persist.gammaos.refresh.rate)
  echo "Fan: $fan | Performance: $perf | Charging: $ch | Refresh: ${rr:-60} Hz | Resolution: $(getprop persist.rg477m.res | sed 's/^$/100/')%"
  echo "Battery $(cat /sys/class/power_supply/battery/capacity)% $(cat /sys/class/power_supply/battery/status), $(( $(cat /sys/class/power_supply/battery/temp) / 10 )) C | Fan speed $(cat /sys/devices/platform/pwm_fan/pwm_fan_set)/255"
}
