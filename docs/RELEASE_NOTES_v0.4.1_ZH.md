[简体中文](RELEASE_NOTES_v0.4.1_ZH.md) | [English](RELEASE_NOTES_v0.4.1.md)

# v0.4.1 — 首个公开版本

这是为在中国使用的 OnePlus 15 北美版 CPH2749 制作并完成实机验证的首个北斗守护版本。

主要内容：

- 模块本身无需解锁 Bootloader，也不刷写分区；
- 需要已经可用的 KernelSU root 环境；
- 只修复两个已知 Qualcomm GNSS EFS 项；
- 拒绝未知值，并对每次写入进行回读验证；
- 兼容不创建订阅专用项的 eSIM profile；
- 只重启 Android `gnss_service`，不重启 modem 或 radio；
- 已通过实际 eSIM 切换测试，北斗保持可见。

安装前请阅读 `README.md`、`docs/INSTALL.md` 和 `docs/SAFETY.md`。
