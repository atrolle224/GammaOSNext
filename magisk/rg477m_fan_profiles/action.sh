#!/system/bin/sh
# Magisk "Action" button: GammaOS Auto -> Silent -> Smart -> Extreme -> Custom -> GammaOS Auto
mode=$(getprop persist.gammaos.fan_mode); prof=$(getprop persist.rg477m.fan_profile)
if [ "$mode" != custom ]; then next=silent
else case "$prof" in silent) next=smart;; smart) next=extreme;; extreme) next=custom;; *) next=gammaos;; esac
fi
if [ "$next" = gammaos ]; then
  setprop persist.gammaos.fan_mode auto
  echo "Fan: GammaOS Auto (fan off below 70 C)"
else
  setprop persist.rg477m.fan_profile "$next"
  setprop persist.gammaos.fan_mode custom
  case "$next" in
    silent)  echo "Fan: Silent - off below 58 C, full speed at 92 C" ;;
    smart)   echo "Fan: Smart - starts at 50 C, full speed at 85 C" ;;
    extreme) echo "Fan: Extreme - always on (160+), full speed at 74 C" ;;
    custom)  echo "Fan: Custom - curve from /data/adb/rg477m/fan_curve.conf" ;;
  esac
fi
echo "Tap Action again for the next profile."
