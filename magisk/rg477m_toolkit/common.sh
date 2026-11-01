# Shared by the RG477M Toolkit scripts.
CFG=/data/adb/rg477m
mkdir -p $CFG
log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> $CFG/toolkit.log; }
# Keep the log small
[ -f $CFG/toolkit.log ] && [ "$(wc -c < $CFG/toolkit.log)" -gt 200000 ] && tail -n 300 $CFG/toolkit.log > $CFG/toolkit.log.1 && mv $CFG/toolkit.log.1 $CFG/toolkit.log
