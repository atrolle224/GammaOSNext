#!/system/bin/sh
# Read-only: finds BIOS files on internal storage and the SD cards, checks them against
# known good dumps and says which emulator folders have them. Report: Download/477m_bios_report.txt
MOD=$(cd "$(dirname "$0")" && pwd)
R=/sdcard/Download/477m_bios_report.txt
S=/data/media/0
: > "$R"
say() { echo "$*"; echo "$*" >> "$R"; }
roots="$S"; for d in /mnt/media_rw/*; do [ -d "$d" ] && roots="$roots $d"; done
T=/data/local/tmp/rg477m_bios.$$; : > $T
for r in $roots; do
  find "$r" -maxdepth 7 -type f \( -iname 'scph*' -o -iname 'psxonpsp*' -o -iname 'sega_101*' -o -iname 'mpr-17933*' \
       -o -iname 'dc_boot*' -o -iname 'dc_flash*' -o -iname 'bios7*' -o -iname 'bios9*' -o -iname 'firmware*.bin' \
       -o -iname '*ps2*bios*' -o -iname 'ps2-*.bin' \) -size -16384k 2>/dev/null | grep -v '/RG477M-' >> $T
done
say "RG477M BIOS check $(date '+%Y-%m-%d %H:%M')"
say ""
found_sys=""
while IFS= read -r f; do
  m=$(md5sum "$f" | cut -d' ' -f1); s=$(stat -c %s "$f")
  hit=$(grep "^$m|" "$MOD/known.txt")
  if [ -n "$hit" ]; then
    sys=$(echo "$hit" | cut -d'|' -f2); name=$(echo "$hit" | cut -d'|' -f3); note=$(echo "$hit" | cut -d'|' -f4)
    found_sys="$found_sys $sys"
    want=""; [ "$(echo "${f##*/}" | tr A-Z a-z)" = "$name" ] || want=" (rename to $name for RetroArch)"
    say "OK    [$sys] $f  = good $name, $note$want"
  else
    case "$(echo "${f##*/}" | tr A-Z a-z)" in
      *.mec|*.nvm|*.erom|*.rom1|*.rom2) continue ;;   # a PS2 BIOS's companion files (settings, DVD/ROM parts)
      scph*|*ps2*|ps2-*) if [ "$s" -ge 4000000 ]; then say "PS2?  $f  ($((s/1024)) KB: a PS2 BIOS size; ARMSX2 checks it itself)"; found_sys="$found_sys PS2"
                         else say "?     $f  (not a known good PS1 dump: may be modified, overdumped or another revision)"; fi ;;
      dc_flash*|firmware*) say "INFO  $f  (differs per console by design; Flycast/melonDS can make their own)" ;;
      *) say "?     $f  (not a known good dump: may still work)" ;;
    esac
  fi
done < $T
rm -f $T
say ""
for sys in PS1 PS2 Saturn Dreamcast DS; do
  case " $found_sys " in *" $sys "*) ;; *) say "MISSING: no $sys BIOS found" ;; esac
done
say ""
say "Where each emulator looks:"
say "  RetroArch (PS1, Saturn, Dreamcast in system/dc/, DS): $(grep -h '^system_directory' $S/Android/data/com.retroarch.*/files/retroarch.cfg 2>/dev/null | head -1 | cut -d'"' -f2)"
for p in com.github.stenzek.duckstation com.armsx2.dnsmod com.flycast.emulator.rg477m com.flycast.emulator com.dsemu.drastic; do
  for d in $S/Android/data/$p/files/bios $S/Android/data/$p/files/data $S/DraStic/system; do
    [ -d "$d" ] && say "  $p: $d ($(ls "$d" 2>/dev/null | wc -l) files)"
  done
done
say ""
say "Full report: Download/477m_bios_report.txt"
