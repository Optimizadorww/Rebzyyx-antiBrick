!/system/bin/sh

# Load config
source /data/adb/antibrick/config

log -t AntiBrick "Starting Universal Guardian on $SOC - Android $ANDROID"

# Universal partition protection function
protect_partitions() {
    # Generic block device protection
    for block in /dev/block/by-name/*; do
        case $block in
            *boot*|*recovery*|*vbmeta*|*preloader*|*lk*|*splloader*|*uboot*)
                chmod 444 "$block" 2>/dev/null
                ;;
        esac
    done
    
    # MTK specific
    if [ "$SOC" = "mtk" ]; then
        echo 0 > /sys/bus/platform/drivers/mtk-msdc/msdc0/soft_rst 2>/dev/null
    fi
    
    # Unisoc specific
    if [ "$SOC" = "unisoc" ]; then
        # Protect FDL (Firmware Download Loader) region
        echo 1 > /sys/module/sprd_emmc/parameters/protect_fdl 2>/dev/null
    fi
}

# Main monitoring loop
while true; do
    # Monitor dangerous operations by process name (universal)
    for dangerous in "dd" "flash_image" "fastboot" "heimdall" "sprd_flash" "mtk_client"; do
        if pgrep -f "$dangerous" > /dev/null 2>&1; then
            log -t AntiBrick "BLOCKED: $dangerous attempted"
            pkill -f "$dangerous" 2>/dev/null
        fi
    done
    
    # Check for write mounts on critical partitions (universal paths)
    if mount | grep -E "/dev/block.* rw," | grep -v "system_root\|data" > /dev/null 2>&1; then
        log -t AntiBrick "WARNING: Write mount detected"
        # Remount read-only
        mount -o remount,ro /vendor 2>/dev/null
        mount -o remount,ro /product 2>/dev/null
        mount -o remount,ro /system 2>/dev/null
    fi
    
    # Prevent factory reset triggers (universal)
    if getprop persist.sys.factory_reset | grep -q "true" 2>/dev/null; then
        setprop persist.sys.factory_reset false
        log -t AntiBrick "BLOCKED: Factory reset attempt"
    fi
    
    # Protect fstab (universal paths)
    for fstab in /vendor/etc/fstab.* /system/etc/fstab.*; do
        if [ -f "$fstab" ] && [ ! -f "$fstab.antibrick.bak" ]; then
            cp "$fstab" "$fstab.antibrick.bak" 2>/dev/null
        fi
        if [ -f "$fstab" ] && [ -f "$fstab.antibrick.bak" ]; then
            if ! cmp -s "$fstab" "$fstab.antibrick.bak" 2>/dev/null; then
                cp "$fstab.antibrick.bak" "$fstab" 2>/dev/null
                log -t AntiBrick "RESTORED: Modified fstab"
            fi
        fi
    done
    
    # Kernel panic protection (all SoCs)
    echo 0 > /proc/sys/kernel/panic 2>/dev/null
    echo 0 > /proc/sys/kernel/panic_on_oops 2>/dev/null
    echo 0 > /proc/sys/vm/panic_on_oom 2>/dev/null
    
    # Android 16 specific: block reboot-to-bootloader
    if [ "$ANDROID" = "16" ]; then
        if getprop sys.antibrick.reboot_blocked | grep -q "1" 2>/dev/null; then
            setprop ctl.stop reboot 2>/dev/null
        fi
    fi
    
    protect_partitions
    sleep 5
done &