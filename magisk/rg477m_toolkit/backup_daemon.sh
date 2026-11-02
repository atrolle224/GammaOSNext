#!/system/bin/sh
# Save backup: once a day, while the screen is off, every emulator's saves, memory cards
# and save states (and OpenMW's saves) are packed into RG477M-backups/<date> on the SD card
# (internal Download when there is no card). The newest 7 are kept.
# Off with persist.rg477m.backup=off; "rg477m backup now" runs one straight away.
MODDIR=${0%/*}; . "$MODDIR/common.sh"
S=/data/media/0
STAMP_FILE=$CFG/last_backup

# app: folders under its Android/data files (any depth up to 4) with these names
NAMES='saves states sstates savestates memcards StateSaves SAVEDATA PPSSPP_STATE GC Wii/title Wii/shared2 data backup'

dest_root() {
  for d in /mnt/media_rw/*; do
    [ -d "$d" ] && [ -w "$d" ] && { echo "$d/RG477M-backups"; return; }
  done
  echo "$S/Download/RG477M-backups"
}

backup() {
  root=$(dest_root); day=$(date +%Y-%m-%d_%H%M); out=$root/$day
  mkdir -p "$out" || return 1
  n=0
  # shared folders some emulators use
  for d in "$S/RetroArch/saves" "$S/RetroArch/states" "$S/PSP/SAVEDATA" "$S/PSP/PPSSPP_STATE" \
           "$S/DraStic/backup" "$S/DraStic/savestates" "$S/Documents/Morrowind Android/saves"; do
    [ -d "$d" ] || continue
    tar -czf "$out/$(echo "${d#$S/}" | tr '/ ' '__').tar.gz" -C "$S" "${d#$S/}" 2>/dev/null && n=$((n + 1))
  done
  # each emulator's own app folder
  for app in "$S"/Android/data/*; do
    p=${app##*/}
    case "$p" in
      com.retroarch.*|org.dolphinemu.*|com.armsx2.*|org.ppsspp.*|com.flycast.emulator*|org.mupen64plusae.*|\
      com.github.stenzek.duckstation*|com.dsemu.drastic*|com.ast.openmw*|org.opennv.*|com.rfandango.haku_x*) ;;
      *) continue ;;
    esac
    L=$CFG/backup.list; : > "$L"
    for nm in $NAMES; do
      (cd "$app" && find files -maxdepth 5 -type d -path "*/$nm" 2>/dev/null | grep -v '/cache/') >> "$L"
    done
    [ -s "$L" ] || continue
    # skip anything over 2 GB (a hakuX hard disk image, say)
    kb=0
    while IFS= read -r f; do k=$(du -sk "$app/$f" 2>/dev/null | cut -f1); kb=$((kb + ${k:-0})); done < "$L"
    [ "$kb" -lt 2097152 ] || { log "backup: $p skipped (${kb} KB)"; continue; }
    tar -czf "$out/$p.tar.gz" -C "$app" -T "$L" 2>/dev/null && n=$((n + 1))
  done
  echo "$(date) $n archives" > "$out/done.txt"
  # keep the newest 7
  total=$(ls -1d "$root"/20* 2>/dev/null | wc -l)
  [ "$total" -gt 7 ] && ls -1d "$root"/20* | sort | head -n $((total - 7)) | while IFS= read -r old; do rm -rf "$old"; done
  date +%s > $STAMP_FILE
  log "backup: $n archives in $out"
}

[ "$1" = now ] && { backup; exit 0; }
while true; do
  sleep 1800
  [ "$(getprop persist.rg477m.backup)" = off ] && continue
  [ "$(getprop sys.screen.state)" = off ] || continue
  last=$(cat $STAMP_FILE 2>/dev/null || echo 0)
  [ $(( $(date +%s) - last )) -ge 86400 ] || continue
  backup
done
