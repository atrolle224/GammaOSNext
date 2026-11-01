#!/system/bin/sh
# RG477M Fan Profiles daemon. Acts only while persist.gammaos.fan_mode=custom, so GammaOS's own
# modes (off/cool/auto/max, the quick settings tile) and its thermal safety guard, which sets
# fan_mode=max for 30 s at 114 C, take over whenever they set a mode of their own.
MODDIR=${0%/*}
. "$MODDIR/profiles.sh"
FAN=/sys/devices/platform/pwm_fan/pwm_fan_set
CONF=/data/adb/rg477m/fan_curve.conf
HYST=3            # C: the fan keeps its speed until the chip is this much cooler
SAFETY_C=90       # C: any profile goes to full speed at or above this
THROTTLE_MIN=200  # pwm while the kernel reports CPU/GPU throttling

zone_file() { for z in /sys/class/thermal/thermal_zone*; do [ "$(cat $z/type 2>/dev/null)" = "$1" ] && echo "$z/temp" && return; done; }
SOC=$(zone_file soc_max); GPU1=$(zone_file gpu1); GPU2=$(zone_file gpu2)

temp_c() {   # hottest valid of soc_max, gpu1, gpu2 (MediaTek reports -274000 when idle)
  best=0
  for f in $SOC $GPU1 $GPU2; do
    r=$(cat "$f" 2>/dev/null); case "$r" in ''|*[!0-9-]*) continue;; esac
    [ "$r" -gt 0 ] || continue
    c=$(( (r + 500) / 1000 )); [ "$c" -le 125 ] && [ "$c" -gt "$best" ] && best=$c
  done
  echo $best
}

curve_for() {
  case "$1" in
    silent) echo "$curve_silent" ;;
    extreme) echo "$curve_extreme" ;;
    custom) [ -s "$CONF" ] && head -n1 "$CONF" || echo "$curve_smart" ;;
    *) echo "$curve_smart" ;;
  esac
}

pwm_at() {   # $1 temp, $2 curve
  t=$1; pt=""; pp=""; out=""
  for p in $2; do
    ct=${p%%:*}; cp=${p##*:}
    if [ -z "$pt" ]; then [ "$t" -le "$ct" ] && { echo $cp; return; }
    elif [ "$t" -le "$ct" ]; then echo $(( pp + (cp - pp) * (t - pt) / (ct - pt) )); return
    fi
    pt=$ct; pp=$cp
  done
  echo $pp
}

cur=$(cat $FAN 2>/dev/null); cur=${cur%%[!0-9]*}; [ -n "$cur" ] || cur=0
held_t=0; active=0
while true; do
  if [ "$(getprop persist.gammaos.fan_mode)" != "custom" ] || [ "$(getprop sys.screen.state)" = "off" ]; then
    held_t=0; active=0; sleep 2; cur=$(cat $FAN 2>/dev/null); cur=${cur%%[!0-9]*}; [ -n "$cur" ] || cur=0; continue
  fi
  if [ "$active" = 0 ]; then
    # GammaOS's init rules only stop its fan services when one of its own modes is picked;
    # stop them here so its auto loop and ramps don't run beside this daemon.
    for svc in setfan_auto setfan_cool setfan_max setfan_off; do setprop ctl.stop $svc; done
    active=1
  fi
  t=$(temp_c)
  # hysteresis: rise at once, fall only once HYST degrees below the temperature last acted on
  if [ "$t" -ge "$held_t" ] || [ "$t" -le $(( held_t - HYST )) ]; then held_t=$t; fi
  target=$(pwm_at "$held_t" "$(curve_for "$(getprop persist.rg477m.fan_profile)")")
  lim=0
  for f in /sys/kernel/thermal/is_cpu_limit /sys/kernel/thermal/is_gpu_limit; do
    v=$(cat $f 2>/dev/null); [ -n "$v" ] && [ "$v" != 0 ] && lim=1
  done
  [ "$lim" = 1 ] && [ "$target" -lt "$THROTTLE_MIN" ] && target=$THROTTLE_MIN
  [ "$t" -ge "$SAFETY_C" ] && target=255
  [ "$target" -gt 255 ] && target=255; [ "$target" -lt 0 ] && target=0
  # ramp like GammaOS's scripts (no sudden jumps): up quickly, down gently
  if [ "$cur" -lt "$target" ]; then
    while [ "$cur" -lt "$target" ]; do cur=$((cur + 5)); [ "$cur" -gt "$target" ] && cur=$target; echo $cur > $FAN; sleep 0.02; done
  elif [ "$cur" -gt "$target" ]; then
    cur=$((cur - 4)); [ "$cur" -lt "$target" ] && cur=$target; echo $cur > $FAN
  fi
  sleep 1
done
