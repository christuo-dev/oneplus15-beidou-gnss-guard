[简体中文](RELEASE_NOTES_v0.4.1_ZH.md) | [English](RELEASE_NOTES_v0.4.1.md)

# v0.4.1 — Initial public release

This release packages the first device-verified BeiDou guard for the North American
OnePlus 15 CPH2749 used in China.

Highlights:

- No bootloader unlock or partition flashing required by the module.
- Requires an existing KernelSU root environment.
- Repairs only two known Qualcomm GNSS EFS items.
- Refuses unknown values and verifies every write.
- Handles eSIM profiles that omit the subscription-specific item.
- Restarts only Android's `gnss_service`, not the modem or radio.
- Tested through a live eSIM switch with BeiDou remaining visible.

Read `README_EN.md`, `docs/INSTALL_EN.md`, and `docs/SAFETY_EN.md` before installing.
