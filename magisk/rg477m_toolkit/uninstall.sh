#!/system/bin/sh
# Runs when the module is removed. Put charging, fan and screen back to GammaOS's defaults.
echo "0 0" > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
(
  until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
  sleep 5
  [ "$(getprop persist.gammaos.fan_mode)" = custom ] && setprop persist.gammaos.fan_mode auto
  r=$(getprop persist.rg477m.res); [ -n "$r" ] && [ "$r" != 100 ] && { wm size reset; wm density reset; }
  [ "$(getprop persist.rg477m.refresh)" = 90 ] && setprop persist.gammaos.refresh.rate 120
  for p in fan_profile perf_profile charge refresh res charge_heat; do resetprop -p --delete persist.rg477m.$p 2>/dev/null; done
) &
