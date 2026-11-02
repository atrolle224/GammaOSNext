ui_print "- RG477M Toolkit"
mkdir -p /data/adb/rg477m
[ -s /data/adb/rg477m/fan_curve.conf ] || echo "49:0 50:80 65:130 75:190 84:255" > /data/adb/rg477m/fan_curve.conf
if [ -d /data/adb/modules/rg477m_fan_profiles ]; then
  touch /data/adb/modules/rg477m_fan_profiles/remove
  ui_print "- Replaces RG477M Fan Profiles (removed on reboot)"
fi
set_perm "$MODPATH/system/bin/rg477m" 0 0 0755
ui_print "- Fan:  Smart, Silent, Extreme, Custom"
ui_print "- Performance: Balanced, Efficient, Battery"
ui_print "  (between GammaOS Normal and Powersave)"
ui_print "- Charging: stop at 80/90%, bypass while playing,"
ui_print "  pause when the battery is over 45 C"
ui_print "- Display: 90 Hz, render resolution 87% / 75%"
ui_print "- Game Mode: in an emulator or game, full speed, Smart fan,"
ui_print "  bypass charging and 120 Hz; your settings return after"
ui_print "- Save backup: daily with the screen off, to RG477M-backups"
ui_print "  on the SD card, newest 7 kept"
ui_print "- Menu: Action button in Magisk (volume keys)"
ui_print "- GammaOS's thermal guard keeps priority: nothing here"
ui_print "  raises temperature limits or clocks it has lowered."
ui_print "- Reboot to start."
