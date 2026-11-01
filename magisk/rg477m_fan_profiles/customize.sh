ui_print "- RG477M Fan Profiles"
mkdir -p /data/adb/rg477m
[ -s /data/adb/rg477m/fan_curve.conf ] || echo "49:0 50:80 65:130 75:190 84:255" > /data/adb/rg477m/fan_curve.conf
ui_print "- Profiles: Silent, Smart, Extreme, Custom"
ui_print "  Switch with the Action button on this module in Magisk."
ui_print "- GammaOS's fan tile still works: picking a GammaOS mode"
ui_print "  there hands the fan back to GammaOS until you pick a"
ui_print "  profile here again."
ui_print "- Safety: full speed at 90 C in every profile; GammaOS's"
ui_print "  thermal guard still overrides at 114 C."
ui_print "- Reboot to start it."
