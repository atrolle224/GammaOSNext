ui_print "- Close apps on shutdown/reboot (Daijishou stays)"
ui_print "  Keep others open: list packages in /data/adb/rg477m/keep_open.conf"
set_perm "$MODPATH/service.sh" 0 0 0755
