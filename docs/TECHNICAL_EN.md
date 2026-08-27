[简体中文](TECHNICAL.md) | [English](TECHNICAL_EN.md)

# Technical mechanism and research record

## 1. Symptom

The North American OnePlus 15 CPH2749 can receive BeiDou in China, but BeiDou may
disappear after an eSIM switch, carrier re-registration, a call, or a network-state
change. Root, VPN, and soft reboot initially looked causal; later evidence narrowed
the trigger to subscription/MCFG updates.

## 2. Firmware and hardware findings

- The GNSS HAL reports BDS signal types, and real tests show B1I/B1C satellites.
- EU and NA builds use the same Kaanapali GEN_PACK modem base package; flashing the
  complete EU modem is neither necessary nor appropriate.
- The regional difference is runtime MCFG/EFS configuration, not the antenna or
  missing BeiDou firmware code.

Located in hardware MCFG:

```text
NA mcfg_hw: gnss_config = 0x4905
EU mcfg_hw: gnss_config = 0x5905
```

## 3. Runtime EFS items

```text
/nv/item_files/gps/cgps/me/gnss_config
/nv/item_files/gps/cgps/me/gnss_config_Subscription01
```

`gnss_efs_fix` uses the Qualcomm DIAG EFS protocol through the phone's stock
`/vendor/bin/diag_socket_log` bridge. Its accepted values are deliberately narrow:

```c
const uint8_t eu[4] = {0x05, 0x59, 0x00, 0x00};
const uint8_t na[4] = {0x05, 0x49, 0x00, 0x00};
```

A write is allowed only when the current content exactly matches one of those values.
Unknown structures fail closed so data from another firmware cannot be mistaken for
the same NV item.

## 4. Why writing 5905 alone is insufficient

After an eSIM switch, the modem may update EFS while the GNSS HAL/engine retains the
old constellation policy in memory. Early versions restored `5905` without restoring
BeiDou immediately. MPSS-only SSR also failed and has a much larger impact surface.

The verified sequence is:

1. Require the primary item to be `5905`.
2. If the subscription item exists, repair it to `5905` too.
3. Wait for the eSIM/carrier update to settle and check again.
4. Run `setprop ctl.restart gnss_service`.
5. The reinitialized GNSS HAL exposes or retains BeiDou.

Only the Android GNSS service is restarted; radio and modem remain running.

## 5. Why Subscription01 is optional

When switching to operator/profile `45403`, the modem removed
`gnss_config_Subscription01`. The primary item remained `5905`, and BeiDou remained
available. Therefore v0.4.1 requires the primary item, repairs the second item only
when present, treats its absence as `OPTIONAL_MISSING`, and never creates it.

## 6. Watcher state machine

`module/service.sh` watches `gsm.sim.state`, `gsm.sim.operator.numeric`, and
`persist.radio.multisim.config`.

```text
State change
  ├─ early repair after 5 seconds
  ├─ wait another 10 seconds
  ├─ settled repair
  └─ restart gnss_service on success
```

A low-frequency safety check runs about every ten minutes. It repairs and reloads only
when `--check` identifies a known value mismatch. A singleton lock prevents multiple
watchers from competing for the DIAG port.

## 7. Verified evidence

```text
repair end rc=0
restarting gnss_service
gnss_service running pid=22866
```

The user then confirmed that BeiDou appeared. With the optional item absent:

```text
/nv/item_files/gps/cgps/me/gnss_config = 05 59 00 00
OPTIONAL_MISSING: /nv/item_files/gps/cgps/me/gnss_config_Subscription01
repair end rc=0
restarting gnss_service
gnss_service running pid=18490
```

BeiDou remained after the eSIM switch.

## 8. Rejected approaches

- **chmod read-only:** ineffective because modem DIAG EFS is not governed by Android
  filesystem permissions.
- **MPSS-only SSR:** did not restore BeiDou and carries more risk than a GNSS HAL restart.
- **AP-side qcril/PDC/MCFG tracing:** probes worked, but the expected path was not hit
  during eSIM switching; the decisive update appears internal to UIM/MPSS.
- **Vendor AIDL constellation API:** discovered transactions appeared to have no useful
  server-side effect.
- **`libloc_api_v02.so` patch:** magic mount was unavailable in the manual-root setup,
  and bind mounts did not propagate into the init-restarted service. Inspection proved
  that the stock library remained loaded even when BeiDou recovered, so the patch was
  removed entirely.

## 9. Scope of the evidence

The tests establish that this hardware receives BeiDou, subscription/EFS refresh is
strongly associated with its disappearance, and `5905` plus a `gnss_service` restart
restores or retains it on the test device, including one live eSIM switch.

They do not prove compatibility with every regional variant or firmware, that every
visible satellite participates in every position fix, or that the method applies to
other Qualcomm phones.
