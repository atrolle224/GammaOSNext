ui_print "- RG477M BIOS check (read-only)"
sh "$MODPATH/check.sh" 2>&1 | while IFS= read -r l; do ui_print "  $l"; done
touch "$MODPATH/remove"
