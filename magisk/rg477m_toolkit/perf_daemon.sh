#!/system/bin/sh
# In-between performance profiles. Active only while GammaOS is on its "stock" (Normal) mode,
# so GammaOS Max and Powersave work as before. A profile only ever LOWERS clocks below what is
# currently set, every few seconds: GammaOS's thermal guard can still clamp lower than the
# profile, and nothing here raises a clock the guard has lowered.
MODDIR=${0%/*}; . "$MODDIR/common.sh"
GPU=/sys/devices/platform/soc/13000000.mali/devfreq/13000000.mali
P0=/sys/devices/system/cpu/cpufreq/policy0
P4=/sys/devices/system/cpu/cpufreq/policy4
P7=/sys/devices/system/cpu/cpufreq/policy7

# profile -> "gpu_max_hz little_khz mid_khz big_khz"
caps() {
  case "$1" in
    balanced)  echo "1600000000 2200000 3200000 3350000" ;;  # full speed, but clocks drop when idle
    efficient) echo "1013000000 1800000 2600000 2700000" ;;  # about 75%: cooler, quieter, longer battery
    battery)   echo "800000000 1600000 2000000 2000000" ;;   # light/retro games; GammaOS powersave is 0.7 GHz
    *) echo "" ;;
  esac
}
# highest available frequency <= want (lists are in any order)
pick() { best=0; for f in $1; do [ "$f" -le "$2" ] && [ "$f" -gt "$best" ] && best=$f; done; [ "$best" -gt 0 ] && echo $best || echo $2; }
lower_to() { cur=$(cat "$1" 2>/dev/null); case "$cur" in ''|*[!0-9]*) return;; esac; [ "$cur" -gt "$2" ] && echo "$2" > "$1"; }

GPU_FREQS=$(cat $GPU/available_frequencies 2>/dev/null)
applied=""
while true; do
  prof=$(getprop persist.rg477m.perf_profile)
  if [ "$(getprop persist.gammaos.performance_mode)" != stock ] || [ -z "$(caps "$prof")" ] || [ "$(getprop sys.screen.state)" = off ]; then
    applied=""; sleep 5; continue
  fi
  set -- $(caps "$prof")
  [ "$applied" != "$prof" ] && { log "perf: $prof"; applied=$prof; }
  g=$(pick "$GPU_FREQS" $1)
  # GammaOS stock pins the GPU at 1.4 GHz (performance governor); let it clock down when
  # there is little to draw. Re-checked every pass because GammaOS re-runs setclock_stock.
  if [ "$(cat $GPU/governor 2>/dev/null)" = performance ]; then
    echo simple_ondemand > $GPU/governor 2>/dev/null
    echo 265000000 > $GPU/min_freq 2>/dev/null
    echo -1 > /proc/gpufreqv2/fix_target_opp_index 2>/dev/null
  fi
  m=$(cat $GPU/min_freq 2>/dev/null); [ -n "$m" ] && [ "$m" -gt "$g" ] && echo 265000000 > $GPU/min_freq 2>/dev/null
  lower_to $GPU/max_freq $g
  lower_to $P0/scaling_max_freq $(pick "$(cat $P0/scaling_available_frequencies)" $2)
  lower_to $P4/scaling_max_freq $(pick "$(cat $P4/scaling_available_frequencies)" $3)
  lower_to $P7/scaling_max_freq $(pick "$(cat $P7/scaling_available_frequencies)" $4)
  sleep 4
done
