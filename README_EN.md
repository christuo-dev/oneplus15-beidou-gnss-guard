[简体中文](README.md) | [English](README_EN.md)

# OnePlus 15 BeiDou GNSS Guard

> Restore and retain BeiDou on a North American OnePlus 15 used in China after
> eSIM or carrier-configuration refreshes.
> **No bootloader unlock, modem flashing, or vendor replacement is required.**

[Technical details](docs/TECHNICAL_EN.md) · [Install and rollback](docs/INSTALL_EN.md) · [Safety](docs/SAFETY_EN.md) · [Build](docs/BUILD_EN.md) · [Attribution](ATTRIBUTION_EN.md)

## Why this project exists

BeiDou is important for a phone used in China. It contributes local coverage, visible
satellites, positioning availability, and performance in difficult urban environments.

The tested North American OnePlus 15 can physically receive BeiDou, yet eSIM changes
and carrier-profile refreshes may make it disappear. Apart from the practical loss,
it is frustrating when capable hardware is restricted by a regional configuration.
This repository records the investigation and provides a small, verifiable, and
reversible KernelSU module.

## Short conclusion

The antenna is not the problem, and an EU modem image is unnecessary. The decisive
parts are two Qualcomm modem GNSS EFS items and stale configuration cached by the GNSS
HAL.

```text
Detect SIM/eSIM state change
        ↓
Validate and repair existing GNSS EFS items to 0x5905
        ↓
Wait for subscription configuration to settle and check again
        ↓
Restart only Android gnss_service
        ↓
BeiDou remains available or returns
```

## No bootloader unlock, but root is required

This module does not unlock the bootloader, flash `boot`, `vendor`, or `modem`, disable
AVB, replace MCFG MBN files, restart MPSS/modem/radio, or change RF bands.

It does require an **already working KernelSU root environment**. Root is needed to
use the stock `diag_socket_log` bridge to access modem EFS and to restart
`gnss_service`. The module does not obtain root for you, and this repository does not
guarantee that every firmware can gain KernelSU root while the bootloader is locked.

## Compatibility

| Device | Status |
|---|---|
| OnePlus 15 NA CPH2749 / OP611FL1, project 24863 | Verified on hardware |
| Android 16, OxygenOS/ColorOS 16.0.5.703 | Verified on hardware |
| Qualcomm Kaanapali modem | Verified |
| OnePlus 15 EU CPH2747 | Unverified; normally should not need this fix |
| OnePlus 15 India CPH2745 | Unverified; do not install directly |
| OnePlus 15 China PLK110 | Unverified; do not install directly |
| Other OnePlus/OPPO/Qualcomm devices | Unsupported; paths and formats may differ |

Sharing a Qualcomm chipset is not enough to establish compatibility. This module
accesses modem EFS; do not experiment on an unverified model.

## Installation

1. Download `oneplus15_bds_guard-v0.4.1.zip` from [Releases](https://github.com/christuo-dev/oneplus15-beidou-gnss-guard/releases).
2. Install and enable it with KernelSU Manager.
3. After root is active, perform one Android soft reboot if needed so the service runs.
4. Verify BeiDou satellites with GPSTest, GnssLogger, or a comparable tool.

The module works in the background. See [Install and rollback](docs/INSTALL_EN.md) for
commands and troubleshooting.

## What the module changes

Only these two paths are handled:

```text
/nv/item_files/gps/cgps/me/gnss_config
/nv/item_files/gps/cgps/me/gnss_config_Subscription01
```

Observed values:

```text
NA:     05 49 00 00 (0x4905)
Target: 05 59 00 00 (0x5905)
```

Safeguards:

- only `4905` and `5905` are accepted;
- unknown contents are never written;
- every write is read back and verified;
- the primary item must exist;
- `Subscription01` is repaired only when present and is never force-created.

After a SIM/eSIM change, the watcher performs an early and a settled check. It then
restarts only `gnss_service`, allowing the GNSS HAL to reload the corrected state.

## Verified observations

- With both items already at `5905`, restarting `gnss_service` restored BeiDou.
- Root activation and an Android soft reboot did not remove BeiDou again.
- BeiDou remained visible through a live eSIM switch.
- Under profile `45403`, the optional item disappeared while the primary item stayed
  at `5905`; BeiDou remained available.
- The GNSS process continued to load the stock `libloc_api_v02.so`; no binary patch is
  required.

“Restored” means Android GNSS tools observed and tracked BeiDou satellites. Whether a
particular satellite participates in every position fix also depends on sky view,
signal strength, measurement state, and engine policy.

## Manual check and repair

```sh
su -c '/data/adb/modules/oneplus15_bds_guard/bin/gnss_efs_fix --check'
```

```sh
su -c '/data/adb/modules/oneplus15_bds_guard/bin/gnss_efs_fix --repair'
su -c 'setprop ctl.restart gnss_service'
```

Log: `/data/adb/oneplus15_bds_guard/service.log`

## Rollback

Disable or uninstall the module in KernelSU, then reboot. Emergency disable:

```sh
su -c 'touch /data/adb/modules/oneplus15_bds_guard/disable'
```

The uninstall script attempts to restore known, existing GNSS EFS items to `4905`.
Keep your own modemst/fsg/fsc or related NV backup before modifying modem EFS.

## Risk warning

This is device-specific low-level research, not a universal “BeiDou unlocker.” Different
models, modem builds, or OEM changes may behave differently. Read the
[safety document](docs/SAFETY_EN.md) before installation.

## Repository layout

```text
module/                 KernelSU module contents
src/gnss_efs_fix.c      Qualcomm DIAG/EFS client source
scripts/build.sh        Reproducible build and packaging script
docs/TECHNICAL*.md      Mechanism, evidence, and rejected approaches
docs/INSTALL*.md        Installation, verification, and rollback
docs/SAFETY*.md         Safety boundary and compatibility
dist/                   Built release package and checksums
```

## License and required credit

Code is licensed under the [MIT License](LICENSE). See the
[unofficial Chinese explanation](LICENSE.zh-CN.md). The static client is built with
musl libc; notices are in [`third_party/musl-COPYRIGHT`](third_party/musl-COPYRIGHT).

If you use or adapt the research, EFS paths, `4905`/`5905` analysis, state-machine
design, documentation, or implementation in a module, port, article, video, or
tutorial, **prominent attribution is required**. Credit the project, author
`christuo-dev`, and original repository URL. See [Attribution](ATTRIBUTION_EN.md).

Research and device verification: [@christuo-dev](https://github.com/christuo-dev).
OpenAI Codex assisted with analysis and engineering documentation.
