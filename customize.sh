#!/system/bin/sh

ui_print "- Installing Anti-Brick Guardian Universal"
ui_print "- Detecting SoC..."

# Detect platform
if grep -qi "qcom\|snapdragon" /proc/cpuinfo 2>/dev/null; then
    SOC="qcom"
    ui_print "- Snapdragon detected"
elif grep -qi "mtk\|mediatek" /proc/cpuinfo 2>/dev/null; then
    SOC="mtk"
    ui_print "- MediaTek detected"
elif grep -qi "unisoc\|sprd\|sc9832\|sc9863" /proc/cpuinfo 2>/dev/null; then
    SOC="unisoc"
    ui_print "- Unisoc detected"
else
    SOC="generic"
    ui_print "- Generic ARM detected"
fi

# Detect Android version
API=$(getprop ro.build.version.sdk)
if [ "$API" -ge 36 ]; then
    ANDROID="16"
elif [ "$API" -ge 35 ]; then
    ANDROID="15"
elif [ "$API" -ge 34 ]; then
    ANDROID="14"
else
    ANDROID="legacy"
fi
ui_print "- Android API: $API"

# Create directories
mkdir -p /data/adb/antibrick
mkdir -p /data/adb/antibrick/logs
chmod 755 /data/adb/antibrick

# Detect partition scheme
if [ -d /dev/block/by-name ]; then
    PARTITION_SCHEME="dynamic"
elif [ -d /dev/block/platform ]; then
    PARTITION_SCHEME="legacy"
else
    PARTITION_SCHEME="unknown"
fi

# Save config
echo "SOC=$SOC" > /data/adb/antibrick/config
echo "ANDROID=$ANDROID" >> /data/adb/antibrick/config
echo "API=$API" >> /data/adb/antibrick/config
echo "PARTITION_SCHEME=$PARTITION_SCHEME" >> /data/adb/antibrick/config
echo "INSTALL_DATE=$(date)" >> /data/adb/antibrick/config

# Apply SoC-specific protections
case $SOC in
    qcom)
        # Protect Qualcomm boot partitions
        chmod 444 /dev/block/by-name/boot 2>/dev/null
        chmod 444 /dev/block/by-name/recovery 2>/dev/null
        chmod 444 /dev/block/by-name/vbmeta 2>/dev/null
        ;;
    mtk)
        # Protect MediaTek bootloader areas
        chmod 444 /dev/block/by-name/preloader 2>/dev/null
        chmod 444 /dev/block/by-name/lk 2>/dev/null
        chmod 444 /dev/block/by-name/lk2 2>/dev/null
        ;;
    unisoc)
        # Protect Unisoc (Spreadtrum) partitions
        chmod 444 /dev/block/by-name/splloader 2>/dev/null
        chmod 444 /dev/block/by-name/uboot 2>/dev/null
        chmod 444 /dev/block/by-name/uboot_log 2>/dev/null
        ;;
esac

# Apply Android version specific protections
if [ "$ANDROID" = "16" ] && [ -f /system/bin/fsverity ]; then
    # Android 16: use fsverity instead of chattr
    fsverity enable /system/bin/init 2>/dev/null
    fsverity enable /system/lib/arm64/libandroid_runtime.so 2>/dev/null
else
    # Legacy: use chattr if available
    chattr +i /system/bin/init 2>/dev/null
    chattr +i /system/lib64/libandroid_runtime.so 2>/dev/null
    chattr +i /system/lib/libandroid_runtime.so 2>/dev/null
fi

ui_print "- Installation complete"
ui_print "- Device protected on $SOC - Android $ANDROID"