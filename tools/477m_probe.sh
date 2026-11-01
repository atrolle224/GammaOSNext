#!/system/bin/sh
# 477m_probe.sh - read-only hardware report for an Anbernic RG477M on GammaOS.
# It only READS system files (no writes, no settings changed) and saves the report to
#   /sdcard/Download/477m_probe.txt
# Run it as root from Termux:   su -c sh /sdcard/Download/477m_probe.sh
# (or from a PC:  adb shell su -c sh /sdcard/Download/477m_probe.sh)

OUT=/sdcard/Download/477m_probe.txt
exec > "$OUT" 2>&1

section() { echo; echo "===== $1"; }
show() { [ -r "$1" ] && printf '%s = %s\n' "$1" "$(cat "$1" 2>/dev/null | head -c 400 | tr '\n' ' ')"; }

section "device"
date
id
getprop | grep -i -E "ro\.product\.|ro\.board|ro\.hardware|ro\.build\.(display|version\.release|fingerprint)|gamma|fan|perf|thermal|mali|gpu" | head -150

section "thermal zones"
for z in /sys/class/thermal/thermal_zone*; do
  [ -d "$z" ] || continue
  echo "--- $z  type=$(cat $z/type 2>/dev/null)  temp=$(cat $z/temp 2>/dev/null)  mode=$(cat $z/mode 2>/dev/null)  policy=$(cat $z/policy 2>/dev/null)"
  for t in $z/trip_point_*_temp; do [ -r "$t" ] && printf '   %s=%s type=%s\n' "$(basename $t)" "$(cat $t)" "$(cat ${t%_temp}_type 2>/dev/null)"; done
done

section "cooling devices (a fan usually shows up here)"
for c in /sys/class/thermal/cooling_device*; do
  [ -d "$c" ] || continue
  echo "--- $c  type=$(cat $c/type 2>/dev/null)  cur_state=$(cat $c/cur_state 2>/dev/null)  max_state=$(cat $c/max_state 2>/dev/null)"
done

section "hwmon"
for h in /sys/class/hwmon/hwmon*; do
  [ -d "$h" ] || continue
  echo "--- $h  name=$(cat $h/name 2>/dev/null)"
  for f in $h/pwm* $h/fan* $h/temp*_input $h/temp*_label; do show "$f"; done
done

section "anything named fan"
find /sys -maxdepth 6 -iname "*fan*" 2>/dev/null | grep -v -E "/fanout|fanotify" | head -80
for f in $(find /sys -maxdepth 6 -iname "*fan*" -type f 2>/dev/null | grep -v -E "/fanout|fanotify" | head -60); do show "$f"; done
find /sys/class/pwm /sys/devices/platform -maxdepth 3 -iname "*pwm*" 2>/dev/null | head -40

section "gpu (mali devfreq)"
for d in /sys/class/devfreq/*; do
  echo "--- $d  name=$(basename $d)"
  for f in governor available_governors cur_freq min_freq max_freq available_frequencies target_freq polling_interval; do show "$d/$f"; done
done
ls /sys/kernel/ged/hal 2>/dev/null && for f in /sys/kernel/ged/hal/*; do show "$f"; done
for f in /proc/gpufreqv2/* /proc/gpufreq/*; do show "$f"; done 2>/dev/null | head -60
ls -d /sys/devices/platform/*mali* /sys/devices/platform/soc/*mali* 2>/dev/null
for d in $(ls -d /sys/devices/platform/*mali* /sys/devices/platform/soc/*mali* 2>/dev/null); do ls "$d"; for f in $d/dvfs_period $d/power_policy $d/core_mask $d/gpuinfo; do show "$f"; done; done

section "cpu"
for p in /sys/devices/system/cpu/cpufreq/policy*; do
  echo "--- $p  cpus=$(cat $p/related_cpus 2>/dev/null)"
  for f in scaling_governor scaling_available_governors scaling_min_freq scaling_max_freq cpuinfo_max_freq scaling_available_frequencies; do show "$p/$f"; done
done
for f in /proc/ppm/policy_status /proc/ppm/enabled /proc/cpufreq/cpufreq_power_mode /sys/kernel/fpsgo/common/fpsgo_enable; do show "$f"; done

section "mediatek power/thermal services"
ls /proc/driver/thermal 2>/dev/null | head -40
ls /vendor/etc/thermal* /vendor/etc/*thermal* /vendor/etc/powerhint* /vendor/etc/power_app_cfg.xml 2>/dev/null
getprop | grep -i -E "init.svc.*(thermal|power|fan|perf|gamma)"

section "GammaOS scripts and settings mentioning fan / performance"
for d in /system/bin /system/xbin /vendor/bin /system/etc/init /vendor/etc/init /data/adb/modules /data/adb/service.d /data/adb/post-fs-data.d; do
  ls "$d" 2>/dev/null | grep -i -E "fan|perf|gamma|thermal|cool|gov" | sed "s|^|$d/|"
done
grep -l -i -E "fan|pwm" /system/etc/init/*.rc /vendor/etc/init/*.rc 2>/dev/null
for k in system global secure; do settings list $k 2>/dev/null | grep -i -E "fan|perf|thermal|gamma|refresh|peak" | sed "s|^|$k: |"; done

section "display"
dumpsys display 2>/dev/null | grep -i -E "supportedModes|refreshRate|mode " | head -20

echo; echo "done"
