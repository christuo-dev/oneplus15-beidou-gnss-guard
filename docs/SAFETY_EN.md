[简体中文](SAFETY.md) | [English](SAFETY_EN.md)

# Safety, compatibility, and disclaimer

## Device-specific research, not a universal module

The only fully verified target is:

```text
OnePlus 15 NA CPH2749 / OP611FL1
Project 24863
Qualcomm Kaanapali modem
Android 16 / OxygenOS 16.0.5.703
```

Other regional variants, firmware versions, and Qualcomm devices must not be assumed
compatible.

## Meaning of “no bootloader unlock required”

The module does not flash partitions or alter the boot image, so it does not itself
require an unlocked bootloader. It still requires an existing working KernelSU root.
Obtaining root with a locked bootloader is outside this repository's guarantees.

## Actions the module explicitly does not perform

- no boot/vendor/modem flashing or AVB disabling;
- no MCFG replacement;
- no RF-band or transmit-parameter changes;
- no MPSS/modem/radio restart;
- no forced creation of a missing subscription EFS item;
- no write when content is not known `4905` or `5905`;
- no vendor GNSS binary patch.

## Remaining risk

Modem EFS is low-level configuration. Even with a narrow write surface, OEM firmware
updates, changed paths, DIAG implementation differences, or an incorrect model may
cause positioning problems, battery drain, service crashes, or unknown behavior.

Use at your own risk and preserve a recoverable backup first. The project provides no
warranty of merchantability, fitness for a particular purpose, or data safety; the
controlling legal terms are in the MIT License.

## Privacy when reporting an issue

Logs and screenshots may expose carrier, location, or SIM information. Remove IMEI,
MEID, ICCID, EID, phone number, precise coordinates, Wi-Fi names, and account data
before opening a public issue.
