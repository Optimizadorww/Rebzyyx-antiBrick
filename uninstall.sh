!/system/bin/sh

ui_print "- Removing Anti-Brick Guardian Universal"

# Restore fstab backups
for fstab in /vendor/etc/fstab.* /system/etc/fstab.*; do
    if [ -f "$fstab.antibrick.bak" ]; then
        cp "$fstab.antibrick.bak" "$fstab" 2>/dev/null
        rm -f "$fstab.antibrick.bak"
    fi
done

# Remove immutable flags (legacy)
chattr -i /system/bin/init 2>/dev/null
chattr -i /system/lib64/libandroid_runtime.so 2>/dev/null
chattr -i /system/lib/libandroid_runtime.so 2>/dev/null

# Android 16 fsverity removal
fsverity disable /system/bin/init 2>/dev/null

# Remove protection from block devices
for block in /dev/block/by-name/*; do
    chmod 644 "$block" 2>/dev/null
done

# Clean up
rm -rf /data/adb/antibrick

ui_print "- Guardian Universal removed"
ui_print "- Device protection disabled"