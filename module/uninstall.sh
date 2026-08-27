#!/system/bin/sh

MODDIR=${0%/*}
LOGDIR=/data/adb/oneplus15_bds_guard
mkdir -p "$LOGDIR"
echo "Uninstall rollback requested at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOGDIR/uninstall.log"
"$MODDIR/bin/gnss_efs_fix" --set-na >> "$LOGDIR/uninstall.log" 2>&1
echo "Rollback result: $?" >> "$LOGDIR/uninstall.log"
