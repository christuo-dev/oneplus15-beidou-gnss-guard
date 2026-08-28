[简体中文](INSTALL.md) | [English](INSTALL_EN.md)

# Installation, verification, and rollback

## Requirements

- Confirmed OnePlus 15 NA CPH2749 / OP611FL1, project 24863;
- an existing working KernelSU root environment;
- no bootloader unlock is required by the module;
- keep Wi-Fi or ADB available;
- back up modemst/fsg/fsc or related NV data first.

## Install

Select `oneplus15_bds_guard-v0.5.1.zip` from Releases in KernelSU Manager, or use:

```sh
cp oneplus15_bds_guard-v0.5.1.zip /data/local/tmp/
su -c '/data/adb/ksud module install /data/local/tmp/oneplus15_bds_guard-v0.5.1.zip'
su -c '/data/adb/ksu/bin/ksud module enable oneplus15_bds_guard'
```

If the service does not start, activate root and perform an Android soft reboot. A
cold reboot or bootloader unlock is not required by the module.

## Check the module

```sh
su -c 'cat /data/adb/modules/oneplus15_bds_guard/module.prop'
su -c '/data/adb/ksu/bin/ksud module list'
su -c 'ps -A -o PID,PPID,USER,ARGS | grep oneplus15_bds_guard/service.sh'
```

Expected: `version=0.5.1`, `versionCode=10`.

## Read-only EFS check

```sh
su -c '/data/adb/modules/oneplus15_bds_guard/bin/gnss_efs_fix --check'
```

`OPTIONAL_MISSING` for `gnss_config_Subscription01` is valid; some eSIM profiles do
not create that item.

## Manual recovery

```sh
su -c '/data/adb/modules/oneplus15_bds_guard/bin/gnss_efs_fix --repair'
su -c 'setprop ctl.restart gnss_service'
```

Wait roughly 5–15 seconds, then inspect BeiDou in a GNSS tool.

## Test an eSIM switch

Confirm the watcher is running, switch eSIM, wait at least 25 seconds, check BeiDou,
then inspect:

```sh
su -c 'tail -150 /data/adb/oneplus15_bds_guard/service.log'
```

Expected events include `subscription state changed`, `restarting gnss_service`,
and `gnss_service running`. If a known `0549` mismatch is detected, the log also
contains `check mismatch` and `repair start reason=subscription_change`; no write
is performed when the values are already `0559`. After the 180-second window,
periodic GNSS EFS checks stop and only event-state polling remains.

## Disable or uninstall

```sh
su -c '/data/adb/ksu/bin/ksud module disable oneplus15_bds_guard'
```

Emergency disable:

```sh
su -c 'touch /data/adb/modules/oneplus15_bds_guard/disable'
```

Then reboot. Uninstall attempts to restore known, existing items to `4905`.

## Bug-report information

Include the exact model/project, firmware and baseband, `module.prop`, roughly 150 log
lines around the failure, operator numeric before and after the switch,
`gnss_efs_fix --check` output, and GNSS screenshots. Remove IMEI, ICCID, EID, phone
number, precise location, and other personal data before publishing.
