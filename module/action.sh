#!/system/bin/sh

MODDIR=${0%/*}
LOGDIR=/data/adb/oneplus15_bds_guard
LOGFILE=$LOGDIR/action.log
LOCKDIR=$LOGDIR/action-lock
mkdir -p "$LOGDIR"

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "Another manual repair/reload is already running." | tee -a "$LOGFILE"
    exit 75
fi

finish() {
    rmdir "$LOCKDIR" 2>/dev/null
}
trap finish EXIT

echo "Manual repair requested at $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOGFILE"
"$MODDIR/bin/gnss_efs_fix" --repair 2>&1 | tee -a "$LOGFILE"
result=${PIPESTATUS[0]}
echo "Manual repair result: $result" | tee -a "$LOGFILE"
exit "$result"
