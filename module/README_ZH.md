[简体中文](README_ZH.md) | [English](README.md)

# OnePlus 15 北斗 GNSS 守护模块

目标设备：OnePlus 15 CPH2749，项目 24863，Qualcomm Kaanapali modem。

模块通过手机原厂 `diag_socket_log` 桥和一个小型 arm64 静态客户端，只处理两个 4 字节
modem EFS 项：

- `/nv/item_files/gps/cgps/me/gnss_config`
- `/nv/item_files/gps/cgps/me/gnss_config_Subscription01`

部分 eSIM profile 会合法删除第二项。主项必须存在；订阅项仅在存在时修复，模块永远
不会创建它。

模块只接受 `05 49 00 00` 与 `05 59 00 00`，写入目标值后立即回读验证。任何未知值
都会被拒绝。它不替换 MCFG、不修改 radio/RF、不刷分区，也不需要解锁 Bootloader，
但需要已经工作的 KernelSU root。

service 使用单实例 watcher。开机、SIM/eSIM 运营商状态变化、Wi-Fi 开关变化、VoWiFi
连接/断连或通话状态变化，或移动网络从无服务恢复到已注册后，进入 180 秒高频守护窗口，
窗口内每 `1` 秒检查一次实际 EFS 项；等待配置稳定后，才只重启 Android `gnss_service`。
它不重启 modem/radio。Wi-Fi 状态读取失败不会触发窗口。VoWiFi 状态来自 telephony、IMS
dump 和 IMS/WFC 属性。窗口结束后不再主动访问 GNSS EFS，仅保留每 2 秒一次的状态轮询。

KernelSU 操作按钮可手动修复 EFS。日志位于：

```text
/data/adb/oneplus15_bds_guard/
```

卸载时会尝试把仍存在的已知项恢复为 `05 49 00 00`；modemst/fsg/fsc 备份仍是紧急
恢复手段。单独修改 EFS 不会刷新 GNSS 栈已经缓存的值，因此本机验证的恢复顺序是：
两项变为 `05 59 00 00`，再重启 `gnss_service`。

需要回退时，在 KernelSU 中禁用或卸载后重启。GNSS 无法启动时，可在 root shell 创建
`/data/adb/modules/oneplus15_bds_guard/disable` 后重启；原厂 vendor 库不会在磁盘上被修改。

重新分发、移植或借鉴本模块及其研究时，必须显著注明 `christuo-dev` 和原始
OnePlus 15 BeiDou GNSS Guard 仓库。
