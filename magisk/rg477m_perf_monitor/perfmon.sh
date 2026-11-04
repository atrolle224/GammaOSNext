#!/system/bin/sh
# Performance monitor: while an app other than the launcher is in front, one CSV row a
# second (fps, hitches, CPU/GPU speed and load, throttling, temperatures, power, memory,
# storage reads), and a report when it leaves the screen.
MODDIR=${0%/*}
OUT=/data/media/0/Download/RG477M-perf
STATE=/data/adb/rg477m/perf
mkdir -p "$OUT" "$STATE"
HITCH_MS=50
SKIP=' com.magneticchen.daijishou com.android.systemui com.android.launcher3 com.android.settings com.topjohnwu.magisk android com.android.permissioncontroller com.google.android.permissioncontroller com.android.documentsui com.google.android.documentsui '

front() {
  dumpsys activity activities 2>/dev/null | sed -n 's/.*topResumedActivity=ActivityRecord{[^ ]* [^ ]* \([^/ ]*\)\/.*/\1/p' | head -1
}

num() { tr -c '0-9\n' ' ' | awk '{ print $1 + 0; exit }'; }

readnum() {
  for f in "$@"; do
    [ -r "$f" ] && { num < "$f" 2>/dev/null; return; }
  done
  echo ""
}

maxnum() { tr -c '0-9\n' ' ' | awk '{ for (i = 1; i <= NF; i++) if ($i + 0 > m) m = $i + 0 } END { if (m) print m }'; }

gpu_mhz() {
  v=""
  for f in /sys/kernel/ged/hal/current_freq /sys/class/misc/mali0/device/cur_freq /sys/kernel/gpu/gpu_clock; do
    [ -r "$f" ] && { v=$(maxnum < "$f"); break; }
  done
  [ -n "$v" ] || v=$(awk '/GPU.*[Ff]req/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/ && $i > 100) { print $i; exit } }' /proc/gpufreqv2/gpufreq_status 2>/dev/null)
  [ -n "$v" ] || { echo ""; return; }
  awk -v v="$v" 'BEGIN { if (v > 1000000) v /= 1000000; else if (v > 10000) v /= 1000; printf "%d", v }'
}

gpu_load() {
  readnum /sys/kernel/ged/hal/gpu_utilization /proc/mali/utilization /sys/kernel/gpu/gpu_busy /sys/class/misc/mali0/device/utilization
}

# thermal zones, sorted into chip and GPU once
SOC_ZONES=""; GPU_ZONES=""
for z in /sys/class/thermal/thermal_zone*; do
  t=$(cat "$z/type" 2>/dev/null)
  case "$t" in
    *gpu*|*GPU*) GPU_ZONES="$GPU_ZONES $z/temp" ;;
    *cpu*|*CPU*|*soc*|*SOC*|mtktscpu|*ap*) SOC_ZONES="$SOC_ZONES $z/temp" ;;
  esac
done

maxtemp() {
  m=0
  for f in "$@"; do
    v=$(cat "$f" 2>/dev/null); [ -n "$v" ] || continue
    [ "$v" -gt "$m" ] 2>/dev/null && m=$v
  done
  awk -v m="$m" 'BEGIN { if (m > 1000) m /= 1000; printf "%d", m }'
}

POLICIES=$(ls -d /sys/devices/system/cpu/cpufreq/policy* 2>/dev/null | sort -V)

cpu_freqs() {
  set -- $POLICIES
  f1=""; f2=""; f3=""; thr=0; i=0
  for p in "$@"; do
    i=$((i + 1))
    c=$(( $(cat "$p/scaling_cur_freq" 2>/dev/null || echo 0) / 1000 ))
    mx=$(cat "$p/scaling_max_freq" 2>/dev/null || echo 0)
    hw=$(cat "$p/cpuinfo_max_freq" 2>/dev/null || echo 0)
    [ "$mx" -lt "$hw" ] && thr=1
    case $i in 1) f1=$c ;; 2) f2=$c ;; *) f3=$c ;; esac
  done
  echo "$f1,$f2,$f3,$thr"
}

cpu_load() {   # total load and the busiest core, since the previous call
  grep '^cpu' /proc/stat > "$STATE/stat.now"
  if [ -f "$STATE/stat.prev" ]; then
    awk 'NR == FNR { for (i = 2; i <= NF; i++) t[$1] += $i; idle[$1] = $5 + $6; next }
         { tot = 0; for (i = 2; i <= NF; i++) tot += $i; d = tot - t[$1]; di = ($5 + $6) - idle[$1]
           if (d <= 0) next; l = 100 * (d - di) / d
           if ($1 == "cpu") all = l; else if (l > mx) mx = l }
         END { printf "%d,%d", all, mx }' "$STATE/stat.prev" "$STATE/stat.now"
  else
    printf ","
  fi
  mv "$STATE/stat.now" "$STATE/stat.prev"
}

disk_mb() {   # MB read from internal storage and SD card since the previous call
  awk '$3 ~ /^sd[a-z]+$/ { u += $6 } $3 ~ /^mmcblk[0-9]+$/ { s += $6 } END { printf "%d %d", u, s }' /proc/diskstats > "$STATE/disk.now"
  if [ -f "$STATE/disk.prev" ]; then
    read pu ps < "$STATE/disk.prev"; read nu ns < "$STATE/disk.now"
    awk -v a="$pu" -v b="$nu" -v c="$ps" -v d="$ns" 'BEGIN { printf "%.1f,%.1f", (b - a) * 512 / 1048576, (d - c) * 512 / 1048576 }'
  else
    printf ","
  fi
  mv "$STATE/disk.now" "$STATE/disk.prev"
}

power() {
  B=/sys/class/power_supply/battery
  bt=$(cat $B/temp 2>/dev/null || echo 0)
  i=$(cat $B/current_now 2>/dev/null || echo 0)
  v=$(cat $B/voltage_now 2>/dev/null || echo 0)
  awk -v t="$bt" -v i="$i" -v v="$v" 'BEGIN { if (i < 0) i = -i; w = i * v / 1e12; if (w > 100) w /= 1000; printf "%.1f,%.2f", t / 10, w }'
}

mem_mb() { awk '/^MemAvailable:/ { printf "%d", $2 / 1024 }' /proc/meminfo; }

layer_for() {
  l=$(dumpsys SurfaceFlinger --list 2>/dev/null | grep -F "$1" | grep -v -e Background -e Bounds -e "^Task=")
  echo "$l" | grep -F "SurfaceView" | tail -1 | grep . || echo "$l" | tail -1
}

# MediaTek's frame tracker: the game's current fps, read by the column named currentFPS
fpsgo_fps() {
  pids=" $(pidof "$PKG" 2>/dev/null) "
  [ "$pids" = "  " ] && return
  for f in /sys/kernel/fpsgo/fstb/fpsgo_status /sys/kernel/debug/fpsgo/fstb/fpsgo_status /proc/fpsgo/fstb/fpsgo_status; do
    [ -r "$f" ] || continue
    awk -v pids="$pids" '
      !col { for (i = 1; i <= NF; i++) if (tolower($i) ~ /^currentfps$|^cur_fps$|^curfps$/) col = i; next }
      index(pids, " " $1 " ") || index(pids, " " $2 " ") { if ($col + 0 > best) best = $col + 0 }
      END { if (best > 0) printf "%.0f", best }' "$f"
    return
  done
}

# frames the screen has shown since boot: the fallback when per-layer timing is unavailable
sf_frames() {
  service call SurfaceFlinger 1013 2>/dev/null | sed -n "s/.*Parcel(\([0-9a-fA-F]*\).*/\1/p" | head -1
}

frames() {   # new frames since $LAST_PRESENT: count, worst gap in ms, hitches; updates LAST_PRESENT
  r=$(dumpsys SurfaceFlinger --latency "$LAYER" 2>/dev/null | awk -v last="$LAST_PRESENT" -v h="$HITCH_MS" '
    NR == 1 { next }
    NF >= 3 && $2 > 0 && $2 < 9e18 {
      if ($2 <= last) { prev = $2; next }
      if (prev > 0) { g = ($2 - prev) / 1e6; if (g > worst) worst = g; if (g > h) hitches++ }
      n++; prev = $2; newlast = $2
    }
    END { printf "%d %.0f %d %.0f", n, worst, hitches, (newlast > 0 ? newlast : last) }')
  set -- $r
  first=$LAST_PRESENT
  # runs in a subshell, so the next call reads where this one stopped from a file
  echo "${4:-$LAST_PRESENT}" > "$STATE/last_present"
  # the first read only sets where counting starts
  if [ "$first" = 0 ]; then echo ",,"; return; fi
  awk -v n="${1:-0}" -v dt="$DT" -v w="${2:-0}" -v hh="${3:-0}" 'BEGIN { if (dt <= 0) dt = 1; printf "%.0f,%s,%s", n / dt, w, hh }'
}

report() {   # $1 csv
  csv=$1; txt=${csv%.csv}.txt
  med=$(awk -F, 'NR > 1 && $2 != "" { print $2 }' "$csv" | sort -n | awk '{ a[NR] = $1 } END { if (NR) print a[int((NR + 1) / 2)] }')
  awk -F, -v h="$HITCH_MS" -v pkg="$PKG" -v med="${med:-0}" '
    NR == 1 { next }
    { n++; fps[n] = $2 + 0; sumfps += $2; if ($3 > worst) worst = $3; hit += $4
      if ($4 == "") { pertime = 0 } else { pertime = 1 }
      dip = (!pertime && med > 0 && $2 < 0.75 * med)
      if (dip) dips++
      if ($4 > 0 || dip) { hs++; hsd += $19; hufs += $18; hbig += $10; hgpu += $16 } else { ns++; nsd += $19; nufs += $18 }
      big += $10; if ($16 != "") { gpu += $16; gpun++ }
      if ($11 == 1) thr++
      if ($12 > soc) soc = $12; if ($13 > gpuc) gpuc = $13; if ($14 > batt) batt = $14
      pw += $15; if ($17 != "" && (memmin == "" || $17 < memmin)) memmin = $17 }
    END {
      if (n < 5) exit
      for (i = 1; i <= n; i++) s[i] = fps[i]
      for (i = 2; i <= n; i++) { v = s[i]; j = i - 1; while (j > 0 && s[j] > v) { s[j + 1] = s[j]; j-- } s[j + 1] = v }
      low = s[int(n * 0.05) + 1]
      printf "RG477M performance report: %s\n", pkg
      if (sumfps == 0) printf "Played %d s.  Frame rate: not available on this device.\n", n
      else printf "Played %d s.  Average %.0f fps, low (worst 5%% of seconds) %.0f fps.\n", n, sumfps / n, low
      if (sumfps == 0) { }
      else if (dips || !hit && worst == 0)
        printf "Frame-rate dips (seconds below 75%% of the usual %d fps): %d of %d seconds.\n", med, dips, n
      else
        printf "Hitches (frames over %d ms): %d, in %d of %d seconds. Worst frame: %d ms.\n", h, hit, hs, n, worst
      printf "CPU: busiest core %.0f%% on average; clocks held below maximum (throttled) %d%% of the time.\n", big / n, 100 * thr / n
      if (gpun) printf "GPU: %.0f%% busy on average.\n", gpu / gpun
      printf "Hottest: chip %d C, GPU %d C, battery %.0f C.  Power %.1f W on average.  Lowest free memory %s MB.\n", soc, gpuc, batt, pw / n, memmin
      printf "Storage reads per second: SD %.1f MB and internal %.1f MB during hitches, SD %.1f MB and internal %.1f MB otherwise.\n\n", \
        hs ? hsd / hs : 0, hs ? hufs / hs : 0, ns ? nsd / ns : 0, ns ? nufs / ns : 0
      printf "What it points to:\n"
      said = 0
      if (hs && (hsd / hs > 1 && hsd / hs > 2 * (ns ? nsd / ns : 0) + 0.5)) {
        print "- Hitches line up with reads from the SD card: the game is streaming from it. Move the game to internal storage, and use an uncompressed image (.iso, XISO) rather than .chd or .cso."; said = 1 }
      if (hs && (hufs / hs > 5 && hufs / hs > 2 * (ns ? nufs / ns : 0) + 1)) {
        print "- Hitches line up with heavy reads from internal storage: loading or streaming. Fast CDVD (ARMSX2) can help."; said = 1 }
      if (thr / n > 0.2) {
        print "- The chip got hot and slowed down (thermal throttling) for " int(100 * thr / n) "% of the time. Use the extreme fan profile for this app, or lower the resolution."; said = 1 }
      else if (soc >= 90)
        print "- The chip peaked at " soc " C but kept full speed: heat is not what limits this game."
      if (gpun && gpu / gpun >= 90) {
        print "- The GPU was close to full: lower the internal resolution or turn off heavy effects."; said = 1 }
      if (big / n >= 90) {
        print "- The busiest CPU core was close to full: the emulator is CPU-limited. Try EE Cycle Skipping (ARMSX2) or lighter settings."; said = 1 }
      if (memmin != "" && memmin < 400) {
        print "- Memory ran low: close other apps before playing."; said = 1 }
      if (!said && sumfps == 0) print "- Nothing on the device was maxed out: no throttling, the GPU and CPU had headroom, and storage was quiet. Stutter here comes from the emulator (shader compiling, frame pacing or its own timing), so its settings are where to look."
      if (!said && sumfps > 0 && (hit > 0 || dips > 0)) print "- No device limit lines up with the hitches. Hitches that fade on a second run are shaders being compiled; ones that stay are the emulator itself."
      if (!said && sumfps > 0 && hit == 0 && dips == 0) print "- Smooth: no hitches recorded."
    }' "$csv" > "$txt"
  [ -s "$txt" ] || rm -f "$txt"
  chown -R media_rw:media_rw "$OUT" 2>/dev/null
}

uptime_s() { cut -d' ' -f1 /proc/uptime; }
PKG=""; CSV=""; LAYER=""; LAST_PRESENT=0; LAYER_TRIES=0; PREV=$(uptime_s)
while [ ! -f /data/adb/rg477m/perf_off ]; do
  T0=$(date +%s)
  NOW=$(uptime_s)
  DT=$(awk -v a="$PREV" -v b="$NOW" 'BEGIN { printf "%.3f", b - a }')
  PREV=$NOW
  p=$(front)
  if [ "$p" != "$PKG" ]; then
    [ -n "$CSV" ] && report "$CSV"
    CSV=""; PKG=$p; LAYER=""; LAST_PRESENT=0; LAYER_TRIES=0; SF_PREV=""
    rm -f "$STATE/stat.prev" "$STATE/disk.prev"
    case "$SKIP" in *" $p "*) p="" ;; esac
    if [ -n "$p" ]; then
      CSV=$OUT/$p-$(date +%Y%m%d-%H%M%S).csv
      echo "time,fps,worst_frame_ms,hitches,cpu_little_mhz,cpu_mid_mhz,cpu_big_mhz,throttled,cpu_load,busiest_core_load,throttled_flag,chip_c,gpu_c,battery_c,power_w,gpu_load,mem_avail_mb,internal_read_mb,sd_read_mb,gpu_mhz" > "$CSV"
    fi
  fi
  if [ -n "$CSV" ]; then
    if [ -z "$LAYER" ] && [ "$LAYER_TRIES" -lt 10 ]; then
      LAYER=$(layer_for "$PKG"); LAYER_TRIES=$((LAYER_TRIES + 1))
    fi
    fr=",,"
    if [ -n "$LAYER" ]; then
      fr=$(frames)
      LAST_PRESENT=$(cat "$STATE/last_present" 2>/dev/null || echo 0)
    fi
    if [ "$fr" = ",," ] || [ "${fr%%,*}" = 0 ]; then
      g=$(fpsgo_fps)
      [ -n "$g" ] && fr="$g,,"
    fi
    if [ "$fr" = ",," ] || [ "${fr%%,*}" = 0 ]; then
      fr=",,"
      c=$(sf_frames)
      if [ -n "$c" ]; then
        c=$(printf '%d' "0x$c" 2>/dev/null)
        if [ -n "$SF_PREV" ] && [ -n "$c" ]; then
          fr=$(awk -v a="$SF_PREV" -v b="$c" -v dt="$DT" 'BEGIN { if (dt <= 0) dt = 1; f = (b - a) / dt; if (f <= 0) printf ",,"; else printf "%.0f,,", f }')
        fi
        SF_PREV=$c
      fi
    fi
    cf=$(cpu_freqs)
    thr=${cf##*,}
    row="$(date +%H:%M:%S),$fr,$cf,$(cpu_load),$thr,$(maxtemp $SOC_ZONES),$(maxtemp $GPU_ZONES),$(power),$(gpu_load),$(mem_mb),$(disk_mb),$(gpu_mhz)"
    echo "$row" >> "$CSV"
  fi
  # one sample a second
  el=$(( $(date +%s) - T0 ))
  [ "$el" -lt 1 ] && sleep 1
done
[ -n "$CSV" ] && report "$CSV"
