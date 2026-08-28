#!/system/bin/sh

MODDIR=${0%/*}
LOGDIR=/data/adb/oneplus15_bds_guard
LOGFILE=$LOGDIR/service.log
LOCKDIR=$LOGDIR/lock
SERVICE_LOCKDIR=$LOGDIR/service-lock
SERVICE_PIDFILE=$SERVICE_LOCKDIR/pid
GUARD_WINDOW_SEC=180
STABLE_WINDOW_SEC=12
HIGH_FREQ_INTERVAL_SEC=1
NORMAL_POLL_INTERVAL_SEC=2

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
# A SIGKILL can leave the empty operation lock behind. The service lock above
# proves this is the only watcher, so an empty operation lock is stale.
rmdir "$LOCKDIR" 2>/dev/null || true

service_cleanup() {
    rm -f "$SERVICE_PIDFILE"
    rmdir "$SERVICE_LOCKDIR" 2>/dev/null
}
trap service_cleanup EXIT INT TERM

log_line() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGFILE"
}

wifi_state() {
    value="$(settings get global wifi_on 2>/dev/null)"
    case "$value" in
        0|1) printf '%s' "$value" ;;
        *) printf '%s' "unknown" ;;
    esac
}

mobile_signal_state() {
    service_state="$(printf '%s\n' "$telephony_state" | grep -E 'm(Voice|Data)RegState=|voiceRegState=|dataRegState=')"
    if printf '%s\n' "$service_state" | grep -Eq 'm(Voice|Data)RegState=0([^0-9]|$)|voiceRegState=0([^0-9]|$)|dataRegState=0([^0-9]|$)'; then
        printf '%s' "in_service"
        return
    fi
    if [ -n "$service_state" ] && printf '%s\n' "$service_state" | grep -Eq 'm(Voice|Data)RegState=[123]([^0-9]|$)|voiceRegState=[123]([^0-9]|$)|dataRegState=[123]([^0-9]|$)'; then
        printf '%s' "no_service"
        return
    fi

    network_types="$(getprop gsm.network.type) $(getprop gsm.voice.network.type) $(getprop gsm.data.network.type)"
    case "$network_types" in
        *LTE*|*NR*|*GSM*|*UMTS*|*HSPA*|*CDMA*|*EVDO*) printf '%s' "in_service" ;;
        *) printf '%s' "no_service" ;;
    esac
}

vowifi_state() {
    ims_state="$(dumpsys ims 2>/dev/null)"
    ims_props="$(getprop | grep -Ei 'vowifi|wfc|ims')"
    combined_state="$telephony_state
$ims_state
$ims_props"

    ims_wlan=0
    call_active=0
    if printf '%s\n' "$combined_state" | grep -Eiq 'mImsRegistrationTech[^0-9]*2([^0-9]|$)|transport[^[:alnum:]]*(WLAN|IWLAN)|((vowifi|wfc)[^[:alnum:]]*)(registered|connected|connecting|disconnecting|active)([^[:alpha:]]|$)'; then
        ims_wlan=1
    fi
    if printf '%s\n' "$combined_state" | grep -Eiq 'mCallState[^0-9]*[12]([^0-9]|$)|CallState.*(ACTIVE|DIALING|RINGING|CONNECTING|DISCONNECTING)|state[=:](ACTIVE|DIALING|RINGING|CONNECTING|DISCONNECTING)'; then
        call_active=1
    fi
    printf '%s/%s' "$ims_wlan" "$call_active"
}

run_repair() {
    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        return 125
    fi
    log_line "repair start reason=$1"
    "$MODDIR/bin/gnss_efs_fix" --repair >> "$LOGFILE" 2>&1
    result=$?
    log_line "repair end rc=$result"
    rmdir "$LOCKDIR" 2>/dev/null
    return "$result"
}

run_check() {
    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        return 125
    fi
    tmpfile="$LOGDIR/check.$$.tmp"
    "$MODDIR/bin/gnss_efs_fix" --check > "$tmpfile" 2>&1
    result=$?
    if [ "$result" = "2" ]; then
        log_line "check mismatch reason=$1"
        grep -E '^/nv/item_files/gps/cgps/me/gnss_config|^OPTIONAL_MISSING:' "$tmpfile" >> "$LOGFILE" 2>/dev/null || true
    elif [ "$result" != "0" ]; then
        log_line "check failed reason=$1 rc=$result"
    fi
    rm -f "$tmpfile"
    rmdir "$LOCKDIR" 2>/dev/null
    return "$result"
}

repair_happened=0

ensure_target() {
    repair_happened=0
    run_check "$1"
    result=$?
    if [ "$result" = "2" ]; then
        run_repair "$1"
        repair_result=$?
        if [ "$repair_result" = "0" ]; then
            repair_happened=1
            return 0
        fi
        return "$repair_result"
    fi
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
guard_until=0
stable_since=0
needs_reload=0
if ensure_target boot; then
    reload_gnss
else
    guard_until=$(( $(date +%s) + GUARD_WINDOW_SEC ))
    needs_reload=1
fi

last_state="$(getprop gsm.sim.state)|$(getprop gsm.sim.operator.numeric)|$(getprop persist.radio.multisim.config)"
last_wifi_state="$(wifi_state)"
telephony_state="$(dumpsys telephony.registry 2>/dev/null)"
last_signal_state="$(mobile_signal_state)"
last_vowifi_state="$(vowifi_state)"
guard_reason="unknown"

while true; do
    now="$(date +%s)"
    if [ "$now" -lt "$guard_until" ]; then
        sleep "$HIGH_FREQ_INTERVAL_SEC"
    else
        sleep "$NORMAL_POLL_INTERVAL_SEC"
    fi

    state="$(getprop gsm.sim.state)|$(getprop gsm.sim.operator.numeric)|$(getprop persist.radio.multisim.config)"
    wifi="$(wifi_state)"
    telephony_state="$(dumpsys telephony.registry 2>/dev/null)"
    signal="$(mobile_signal_state)"
    vowifi="$(vowifi_state)"
    now="$(date +%s)"
    if [ "$state" != "$last_state" ]; then
        log_line "subscription state changed: $last_state -> $state"
        last_state=$state
        guard_until=$((now + GUARD_WINDOW_SEC))
        stable_since=0
        needs_reload=1
        guard_reason="subscription_change"
    fi

    if [ "$wifi" != "unknown" ]; then
        if [ "$last_wifi_state" != "unknown" ] && [ "$wifi" != "$last_wifi_state" ]; then
            log_line "wifi state changed: $last_wifi_state -> $wifi"
            guard_until=$((now + GUARD_WINDOW_SEC))
            stable_since=0
            needs_reload=1
            guard_reason="wifi_change"
        fi
        last_wifi_state=$wifi
    fi

    if [ "$vowifi" != "$last_vowifi_state" ]; then
        log_line "vowifi state changed: $last_vowifi_state -> $vowifi"
        guard_until=$((now + GUARD_WINDOW_SEC))
        stable_since=0
        needs_reload=1
        guard_reason="vowifi_change"
        last_vowifi_state=$vowifi
    fi

    if [ "$signal" = "in_service" ] && [ "$last_signal_state" = "no_service" ]; then
        log_line "mobile signal recovered: $last_signal_state -> $signal"
        guard_until=$((now + GUARD_WINDOW_SEC))
        stable_since=0
        needs_reload=1
        guard_reason="signal_recovery"
    fi
    last_signal_state=$signal

    if [ "$now" -lt "$guard_until" ]; then
        if ensure_target "$guard_reason"; then
            if [ "$repair_happened" = "1" ]; then
                stable_since=0
                needs_reload=1
            elif [ "$stable_since" = "0" ]; then
                stable_since=$now
            fi
        else
            stable_since=0
        fi

        if [ "$needs_reload" = "1" ] && [ "$stable_since" != "0" ] && \
           [ $((now - stable_since)) -ge "$STABLE_WINDOW_SEC" ]; then
            if reload_gnss; then
                needs_reload=0
            fi
        fi
        continue
    fi
done
