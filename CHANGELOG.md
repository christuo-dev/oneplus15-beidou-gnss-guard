[简体中文](CHANGELOG_ZH.md) | [English](CHANGELOG.md)

## v0.5.1 — 2026-08-29

- Changed high-frequency guard-window polling to `1` second.
- Added Android `global wifi_on` changes as a high-frequency guard trigger.
- Added VoWiFi WLAN registration/disconnection and call-state changes as triggers.
- Added mobile-signal recovery from no service to in-service as a trigger.
- Ignore failed Wi-Fi state reads to avoid false triggers.
- Removed the periodic low-frequency EFS check; outside the guard window only event state is polled every 2 seconds.

## v0.5.0 — 2026-08-29

- Added a 180-second high-frequency GNSS EFS guard window after SIM/eSIM property changes.
- Reapply `0x5905` with verified writes whenever either live NV item returns to `0x4905`.
- Reload `gnss_service` only after both items remain stable for 12 seconds.
- Kept `Subscription01` optional and never create a modem-managed item.
- Reduced normal operation to a ten-minute periodic check.

# Changelog

## v0.4.1 — 2026-08-28

- Treat `gnss_config_Subscription01` as optional because some eSIM profiles
  legitimately remove it.
- Keep the primary GNSS EFS item mandatory.
- Repair known `0x4905` values to `0x5905` with read-back verification.
- Recheck after subscription configuration settles.
- Restart only Android `gnss_service` after a successful settled repair.
- Add singleton watcher protection.
- Remove the ineffective vendor GNSS library patch experiment.
