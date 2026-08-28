[简体中文](README_ZH.md) | [English](README.md)

# OnePlus 15 BeiDou GNSS Guard

Target: OnePlus 15 CPH2749, project 24863, Qualcomm Kaanapali modem.

The module uses the phone's stock `diag_socket_log` bridge and a small static
arm64 client. It touches only these two 4-byte modem EFS item files:

- `/nv/item_files/gps/cgps/me/gnss_config`
- `/nv/item_files/gps/cgps/me/gnss_config_Subscription01`

Some eSIM profiles legitimately remove `gnss_config_Subscription01`. The main
item is mandatory; the subscription item is repaired only when it exists and
is never created by the module.

It accepts only the known values `05 49 00 00` and `05 59 00 00`, writes the EU
value, and verifies every write by reading it back. Any unexpected value causes
an immediate refusal. It does not replace MCFG images or alter radio/RF items.

The service enforces a singleton watcher. After boot, a SIM/eSIM operator
change, a Wi-Fi toggle, a VoWiFi registration/disconnection or call-state change,
or mobile service recovery from no service, it enters a 180-second guard window
and checks the live EFS items every `1` second. It restarts only Android's
`gnss_service` after the configuration settles. Failed Wi-Fi reads do not trigger
the window. After the window, it polls only event state every 2 seconds and does
not perform periodic GNSS EFS checks. It never restarts the modem or radio.

The KernelSU action button performs a manual EFS repair. Logs are under
`/data/adb/oneplus15_bds_guard/`.

Uninstall attempts to restore both items to the original NA value
`05 49 00 00`. The full modemst/fsg/fsc backups remain the emergency fallback.

Changing an EFS item alone does not replace a value already cached by the GNSS
stack. On this device, the verified recovery sequence is to make both items
`05 59 00 00` and then restart `gnss_service`; this restored BeiDou without a
full device reboot.

To roll it back, disable or uninstall the module and reboot. If GNSS fails to start, create
`/data/adb/modules/oneplus15_bds_guard/disable` from a root shell and reboot;
the stock vendor library is never modified on disk.

If you redistribute or adapt this module or its research, prominently credit
`christuo-dev` and the original OnePlus 15 BeiDou GNSS Guard repository.
