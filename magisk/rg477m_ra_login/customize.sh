ui_print "- RetroAchievements: one sign-in for every emulator"
sh "$MODPATH/sync.sh" 2>&1 | while IFS= read -r l; do ui_print "  $l"; done
ui_print "- Signed in somewhere new later? Magisk > Modules > Action copies it again."
