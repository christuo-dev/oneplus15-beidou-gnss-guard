[简体中文](CHANGELOG_ZH.md) | [English](CHANGELOG.md)

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
