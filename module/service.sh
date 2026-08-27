#!/system/bin/sh

MODDIR=${0%/*}
LOGDIR=/data/adb/oneplus15_bds_guard
LOGFILE=$LOGDIR/service.log
LOCKDIR=$LOGDIR/lock
SERVICE_LOCKDIR=$LOGDIR/service-lock
SERVICE_PIDFILE=$SERVICE_LOCKDIR/pid

mkdir -p "$LOGDIR"
chmod 700 "$LOGDIR"

# KernelSU can start service.sh again after a manual root/module reload. Keep
# exactly one long-running watcher so DIAG access and event handling do not race.
if ! mkdir "$SERVICE_LOCKDIR" 2>/dev/null; then
    old_pid="$(cat "$SERVICE_PIDFILE" 2>/dev/null)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        exit 0
    fi
    rm -f "$SERVICE_PIDFILE"
    rmdir "$SERVICE_LOCKDIR" 2>/dev/null
    mkdir "$SERVICE_LOCKDIR" 2>/dev/null || exit 0
fi
echo $$ > "$SERVICE_PIDFILE"

service_cleanup() {
    rm -f "$SERVICE_PIDFILE"
    rmdir "$SERVICE_LOCKDIR" 2>/dev/null
}
trap service_cleanup EXIT INT TERM

log_line() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGFILE"
}

run_repair() {
    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        return
    fi
    log_line "repair start reason=$1"
    "$MODDIR/bin/gnss_efs_fix" --repair >> "$LOGFILE" 2>&1
    result=$?
    log_line "repair end rc=$result"
    rmdir "$LOCKDIR" 2>/dev/null
    return "$result"
}

reload_gnss() {
    log_line "restarting gnss_service"
    setprop ctl.restart gnss_service
    sleep 3
    if [ "$(getprop init.svc.gnss_service)" != "running" ]; then
        log_line "gnss_service restart failed"
        return 5
    fi
    log_line "gnss_service running pid=$(getprop init.svc_debug_pid.gnss_service)"
    return 0
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done

sleep 10
log_line "service start pid=$$"
if run_repair boot; then
    reload_gnss
fi

last_state="$(getprop gsm.sim.state)|$(getprop gsm.sim.operator.numeric)|$(getprop persist.radio.multisim.config)"
unchanged_ticks=0

while true; do
    sleep 2
    state="$(getprop gsm.sim.state)|$(getprop gsm.sim.operator.numeric)|$(getprop persist.radio.multisim.config)"
    if [ "$state" != "$last_state" ]; then
        log_line "subscription state changed: $last_state -> $state"
        last_state=$state
        unchanged_ticks=0
        sleep 5
        run_repair subscription_change_early
        sleep 10
        if run_repair subscription_change_settled; then
            reload_gnss
        fi
        continue
    fi

    unchanged_ticks=$((unchanged_ticks + 1))
    if [ "$unchanged_ticks" -ge 300 ]; then
        unchanged_ticks=0
        "$MODDIR/bin/gnss_efs_fix" --check >> "$LOGFILE" 2>&1
        result=$?
        if [ "$result" = "2" ]; then
            if run_repair periodic_check; then
                reload_gnss
            fi
        fi
    fi
done
