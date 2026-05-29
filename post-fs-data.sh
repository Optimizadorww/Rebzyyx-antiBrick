!/system/bin/sh

source /data/adb/antibrick/config

log -t AntiBrick "Early protection active on $SOC"

# Universal sysctl hardening
sysctl -w kernel.panic=0 2>/dev/null
sysctl -w kernel.panic_on_oops=0 2>/dev/null
sysctl -w vm.panic_on_oom=0 2>/dev/null
sysctl -w fs.protected_fifos=2 2>/dev/null
sysctl -w fs.protected_regular=2 2>/dev/null

# Protect boot control (all SoCs)
if [ -f /system/bin/bootctl ]; then
    bootctl mark-boot-successful 2>/dev/null
fi

# Disable automatic reboot on crash
setprop persist.sys.reboot_on_panic 0

# Detect recovery mode attempts
if getprop ro.boot.mode | grep -q "recovery" 2>/dev/null; then
    log -t AntiBrick "WARNING: Device in recovery mode - protection limited"
fi

# Create sentinel
echo "active" > /data/adb/antibrick/status
date >> /data/adb/antibrick/status
echo "SOC=$SOC" >> /data/adb/antibrick/status
echo "API=$API" >> /data/adb/antibrick/status