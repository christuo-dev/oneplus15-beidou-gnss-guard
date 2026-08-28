[简体中文](CHANGELOG_ZH.md) | [English](CHANGELOG.md)

## v0.5.1 — 2026-08-29

- 将高频守护窗口内的检测间隔调整为 `1` 秒；
- 将 Android `global wifi_on` 的开关变化加入高频守护触发条件；
- 将 VoWiFi WLAN 注册/断连及通话状态变化加入高频守护触发条件；
- 将移动网络从无服务恢复到已注册加入高频守护触发条件；
- Wi-Fi 状态读取失败时不触发守护，避免误报；
- 删除 10 分钟一次的低频 EFS 检查；窗口外仅保留每 2 秒一次的状态轮询。

## v0.5.0 — 2026-08-29

- eSIM/SIM 属性变化后进入 180 秒高频 GNSS EFS 守护窗口；
- 持续检查两个实际 NV 项，发现 `0549` 立即带校验回写 `0559`；
- 两项稳定 12 秒后才重启一次 `gnss_service`；
- 保留 `Subscription01` 可选规则，不创建 modem 未提供的项目；
- 平时改为每 10 分钟低频检查，减少 DIAG 访问。

# 更新日志

## v0.4.1 — 2026-08-28

- 将 `gnss_config_Subscription01` 作为可选项，因为部分 eSIM profile 会合法删除它；
- 主 GNSS EFS 项仍为必需项；
- 仅将已知 `0x4905` 修复为 `0x5905`，并回读验证；
- 订阅配置稳定后再次检查；
- settled repair 成功后只重启 Android `gnss_service`；
- 增加 watcher 单实例保护；
- 删除无效的 vendor GNSS 库补丁实验。
