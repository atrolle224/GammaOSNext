#!/system/bin/sh
# RetroAchievements: sign in once (in RetroArch, or any of the emulators below), and the login
# token is copied to the others. Only the token RetroAchievements gave the app is copied: no
# password is read, stored or sent anywhere, and nothing leaves the device.
S=/data/media/0/Android/data
D=/data/data

ini_set() {   # file section key value: set key in [section], adding either if missing
  f=$1; sec=$2; key=$3; val=$4
  [ -f "$f" ] || { mkdir -p "${f%/*}"; : > "$f"; }
  awk -v s="[$sec]" -v k="$key" -v v="$val" '
    BEGIN { ins = 0; done = 0 }
    { line = $0; t = line; sub(/[ \t\r]+$/, "", t) }
    t ~ /^\[/ { if (ins && !done) { print k " = " v; done = 1 } ins = (tolower(t) == tolower(s)) }
    ins && !done { split(t, a, "="); kk = a[1]; gsub(/[ \t]+$/, "", kk)
      if (tolower(kk) == tolower(k)) { print k " = " v; done = 1; next } }
    { print line }
    END { if (!done) { if (!ins) print s; print k " = " v } }' "$f" > "$f.rg" && cat "$f.rg" > "$f" && rm -f "$f.rg"
}
ini_get() { awk -v s="[$2]" -v k="$3" '{ t = $0; sub(/[ \t\r]+$/, "", t) } t ~ /^\[/ { ins = (tolower(t) == tolower(s)); next }
  ins { n = index(t, "="); if (n) { kk = substr(t, 1, n - 1); gsub(/[ \t]+$/, "", kk); if (tolower(kk) == tolower(k)) { v = substr(t, n + 1); sub(/^[ \t]+/, "", v); print v; exit } } }' "$1" 2>/dev/null; }
cfg_get() { grep "^$2 = " "$1" 2>/dev/null | head -1 | sed 's/^[^"]*"//; s/"$//'; }
cfg_set() { if grep -q "^$2 = " "$1"; then sed -i "s#^$2 = .*#$2 = \"$3\"#" "$1"; else echo "$2 = \"$3\"" >> "$1"; fi; }
keep_owner() { o=$(stat -c %u:%g "$2" 2>/dev/null); c=$(/system/bin/ls -Zd "$2" | awk '{print $1}'); chown "$o" "$1"; chcon "$c" "$1" 2>/dev/null; }

# ---- find a login -----------------------------------------------------------------
U=""; T=""; FROM=""
found() { [ -n "$1" ] && [ -n "$2" ] && [ -z "$T" ] && { U=$1; T=$2; FROM=$3; }; }
for p in com.retroarch.rg477m com.retroarch.aarch64; do
  c=$S/$p/files/retroarch.cfg; found "$(cfg_get $c cheevos_username)" "$(cfg_get $c cheevos_token)" "RetroArch ($p)"
done
for p in org.dolphinemu.dolphinemu.rg477m org.dolphinemu.dolphinemu; do
  c=$S/$p/files/Config/RetroAchievements.ini; found "$(ini_get $c Achievements Username)" "$(ini_get $c Achievements ApiToken)" "Dolphin ($p)"
done
for p in com.flycast.emulator.rg477m com.flycast.emulator; do
  c=$S/$p/files/emu.cfg; found "$(ini_get $c achievements UserName)" "$(ini_get $c achievements Token)" "Flycast ($p)"
done
for p in com.armsx2.dnsmod com.armsx2.netmod; do
  c=$S/$p/files/PCSX2-Android.ini; found "$(ini_get $c Achievements Username)" "$(ini_get $c Achievements Token)" "ARMSX2 ($p)"
done
for p in me.magnum.melonds.rg477m me.magnum.melonds; do
  x=$D/$p/shared_prefs/${p}_preferences.xml
  found "$(sed -n 's#.*<string name="ra_username">\([^<]*\)</string>.*#\1#p' $x 2>/dev/null)" \
        "$(sed -n 's#.*<string name="ra_token">\([^<]*\)</string>.*#\1#p' $x 2>/dev/null)" "melonDS ($p)"
done
PPS=""
for d in /data/media/0/PSP/SYSTEM $S/org.ppsspp.ppsspp.rg477m/files/PSP/SYSTEM $S/org.ppsspp.ppsspp/files/PSP/SYSTEM; do
  [ -f "$d/ppsspp.ini" ] && PPS="$PPS $d"
  found "$(ini_get $d/ppsspp.ini Achievements AchievementsUserName)" "$(cat $d/ppsspp_retroachievements.dat 2>/dev/null)" "PPSSPP ($d)"
done
if [ -z "$T" ]; then
  echo "No RetroAchievements login found. Sign in once in RetroArch 477M"
  echo "(Settings > Achievements), then run this again (Magisk > Action)."
  exit 0
fi
echo "Login of $U found in $FROM"

# ---- copy it to the others -----------------------------------------------------------
stop() { am force-stop "$1" 2>/dev/null; }
for p in com.retroarch.rg477m com.retroarch.aarch64; do
  c=$S/$p/files/retroarch.cfg; [ -f "$c" ] || continue; stop $p
  cfg_set $c cheevos_enable true; cfg_set $c cheevos_username "$U"; cfg_set $c cheevos_token "$T"; cfg_set $c cheevos_password ""
  echo "  RetroArch ($p)"
done
for p in org.dolphinemu.dolphinemu.rg477m org.dolphinemu.dolphinemu; do
  [ -d "$S/$p/files" ] || continue; stop $p; c=$S/$p/files/Config/RetroAchievements.ini
  ini_set $c Achievements Enabled True; ini_set $c Achievements Username "$U"; ini_set $c Achievements ApiToken "$T"
  keep_owner $c "$S/$p/files"; echo "  Dolphin ($p)"
done
for p in com.flycast.emulator.rg477m com.flycast.emulator; do
  c=$S/$p/files/emu.cfg; [ -f "$c" ] || continue; stop $p
  ini_set $c achievements Enabled yes; ini_set $c achievements UserName "$U"; ini_set $c achievements Token "$T"
  echo "  Flycast ($p)"
done
for p in com.armsx2.dnsmod com.armsx2.netmod; do
  c=$S/$p/files/PCSX2-Android.ini; [ -f "$c" ] || continue; stop $p
  ini_set $c Achievements Enabled true; ini_set $c Achievements Username "$U"; ini_set $c Achievements Token "$T"
  ini_set $c Achievements LoginTimestamp "$(date +%s)"
  echo "  ARMSX2 ($p)"
done
for p in me.magnum.melonds.rg477m me.magnum.melonds; do
  x=$D/$p/shared_prefs/${p}_preferences.xml; [ -d "$D/$p" ] || continue; stop $p
  [ -f "$x" ] || { mkdir -p "${x%/*}"; printf "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n</map>\n" > "$x"; }
  sed -i '/<string name="ra_username">/d; /<string name="ra_token">/d' "$x"
  sed -i "s#</map>#    <string name=\"ra_username\">$U</string>\n    <string name=\"ra_token\">$T</string>\n</map>#" "$x"
  chown $(stat -c %u:%g $D/$p) "$x" "${x%/*}"; chmod 660 "$x"; chcon $(/system/bin/ls -Zd $D/$p | awk '{print $1}') "$x" 2>/dev/null
  echo "  melonDS ($p)"
done
for d in $PPS; do
  stop org.ppsspp.ppsspp.rg477m; stop org.ppsspp.ppsspp
  ini_set $d/ppsspp.ini Achievements AchievementsEnable True; ini_set $d/ppsspp.ini Achievements AchievementsUserName "$U"
  printf %s "$T" > $d/ppsspp_retroachievements.dat; keep_owner $d/ppsspp_retroachievements.dat $d
  echo "  PPSSPP ($d)"
done
echo "Done: start each emulator and it should be signed in as $U."
echo "DuckStation isn't covered (its settings format isn't public): sign in there once."
