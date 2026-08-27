[简体中文](CHANGELOG_ZH.md) | [English](CHANGELOG.md)

# 更新日志

## v0.4.1 — 2026-08-28

- 将 `gnss_config_Subscription01` 作为可选项，因为部分 eSIM profile 会合法删除它；
- 主 GNSS EFS 项仍为必需项；
- 仅将已知 `0x4905` 修复为 `0x5905`，并回读验证；
- 订阅配置稳定后再次检查；
- settled repair 成功后只重启 Android `gnss_service`；
- 增加 watcher 单实例保护；
- 删除无效的 vendor GNSS 库补丁实验。
