# Fan curves: "temp_C:pwm" points (pwm 0-255, GammaOS: cool=160, max=255), linear between them.
# Below the first point the fan uses the first point's speed; above the last, the last's.
curve_silent="57:0 58:70 72:110 80:160 88:220 92:255"
curve_smart="49:0 50:70 62:110 70:150 78:200 85:255"
curve_extreme="0:160 60:200 68:240 74:255"
# Custom: /data/adb/rg477m/fan_curve.conf (one line, same format); smart until it exists.
