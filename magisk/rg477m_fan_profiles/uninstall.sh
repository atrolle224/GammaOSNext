#!/system/bin/sh
# Hand the fan back to GammaOS.
[ "$(getprop persist.gammaos.fan_mode)" = custom ] && setprop persist.gammaos.fan_mode auto
resetprop -p --delete persist.rg477m.fan_profile 2>/dev/null
