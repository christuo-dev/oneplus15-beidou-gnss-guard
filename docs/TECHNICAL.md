[简体中文](TECHNICAL.md) | [English](TECHNICAL_EN.md)

# 技术原理与研究记录

## 1. 现象

测试机 OnePlus 15 NA CPH2749 在中国能够接收北斗信号，但北斗状态不稳定：冷启动
后可能出现，切换 eSIM、运营商重新注册、通话或网络状态变化后可能消失。早期测试中，
单纯 root、VPN 或软重启看似是触发条件，后续证据把问题收敛到了订阅/MCFG 更新。

## 2. 固件与硬件结论

- GNSS HAL 能上报 BDS 信号类型，硬件具备接收能力。
- 实测 GNSS 工具能够显示北斗 B1I/B1C 等卫星。
- 欧版与 NA 使用同一 Kaanapali GEN_PACK modem 基础包；完整刷欧版 modem 不是合理
  解法。
- 地区差异落在运行时 MCFG/EFS 配置，而不是天线或缺失的 BDS 固件代码。

已定位到硬件 MCFG 中：

```text
NA mcfg_hw: gnss_config = 0x4905
EU mcfg_hw: gnss_config = 0x5905
```

## 3. 运行时 EFS 项

决定性路径：

```text
/nv/item_files/gps/cgps/me/gnss_config
/nv/item_files/gps/cgps/me/gnss_config_Subscription01
```

`gnss_efs_fix` 使用 Qualcomm DIAG EFS 协议，经设备原厂
`/vendor/bin/diag_socket_log` 读取这些项目。

写入策略刻意保守：

```c
const uint8_t eu[4] = {0x05, 0x59, 0x00, 0x00};
const uint8_t na[4] = {0x05, 0x49, 0x00, 0x00};
```

只有当前内容严格等于上述两个值之一时才允许修改。任何未知结构都返回错误，避免把
不同 firmware 的数据误当成同一 NV 项。

## 4. 为什么只写 5905 不够

eSIM 切换后，modem 会更新 EFS，但 GNSS HAL/引擎可能已经把旧的星座策略缓存在
内存中。早期模块能把 `4905` 回写为 `5905`，北斗却不会立即回来。

MPSS-only SSR 也没有恢复北斗，说明不应通过更重的基带重启解决。

最终实测有效顺序：

1. 确认主项为 `5905`；
2. 若订阅项存在，也修复为 `5905`；
3. 等待 eSIM/运营商写入稳定并复查；
4. `setprop ctl.restart gnss_service`；
5. GNSS HAL 重新初始化后北斗出现或保持。

这里只重启 Android GNSS HAL，不重启 radio 或 modem。

## 5. Subscription01 为什么是可选项

实测切到运营商/profile `45403` 时，modem 删除了
`gnss_config_Subscription01`。主项仍为 `5905`，北斗仍然存在。

因此 v0.4.1 的规则是：

- 主项读不到：失败并停止；
- 第二项存在：检查/修复；
- 第二项不存在：输出 `OPTIONAL_MISSING` 并成功退出；
- 永远不由模块创建第二项。

这避免了用 AP userspace 猜测 modem 的订阅文件生命周期。

## 6. Watcher 状态机

`module/service.sh` 观察：

```text
gsm.sim.state
gsm.sim.operator.numeric
persist.radio.multisim.config
settings get global wifi_on
dumpsys telephony.registry
dumpsys ims
getprop（IMS/WFC/VoWiFi 状态）
```

流程：

```text
SIM/eSIM、Wi-Fi 开关、VoWiFi WLAN 注册/断连或通话状态变化，或移动信号从无服务恢复
  ├─ 进入 180 秒窗口
  ├─ 窗口内每 1 秒检测/修复
  ├─ 两项稳定 12 秒
  └─ 成功后 restart gnss_service
```

Wi-Fi 读取不到 `0/1` 时不会触发窗口。移动信号只在明确经历
`no_service -> in_service` 时触发；普通网络制式变化不会触发。窗口外保持 2 秒状态轮询，
不再主动访问 GNSS EFS。只有进入高频窗口后，`--check` 返回“已知值存在偏差”时才修复并重载。

VoWiFi 快照由 IMS 是否使用 WLAN 传输和通话状态组成，因此 WLAN 注册、断连、通话开始
和结束都会触发高频窗口。相关 `dumpsys` 和 `getprop` 读取也在窗口内执行；它们只用于
事件识别，不会写入 modem。

单实例锁避免 KernelSU 手动加载或软重启后出现多个 watcher，同时争用 DIAG 端口。

## 7. 已验证证据

关键日志：

```text
repair end rc=0
restarting gnss_service
gnss_service running pid=22866
```

用户随后确认北斗出现。

v0.4.1 在第二项缺失时：

```text
/nv/item_files/gps/cgps/me/gnss_config = 05 59 00 00
OPTIONAL_MISSING: /nv/item_files/gps/cgps/me/gnss_config_Subscription01
repair end rc=0
restarting gnss_service
gnss_service running pid=18490
```

用户在 eSIM 切换后确认北斗仍在。

## 8. 排除和失败路线

### chmod 只读

对 EFS 项做 `chmod 0444` 无效。modem DIAG EFS 并不受 Android 文件权限模型直接
约束，仍可写入。

### MPSS-only SSR

未恢复北斗，且风险和影响面比 GNSS HAL restart 更大，最终方案不使用。

### qcril/PDC/MCFG AP 侧追踪

uprobes 自测有效，但 eSIM 切换没有命中预期的 qcril MBN/PDC 路径。说明关键更新位于
UIM/MPSS 内部，不应只在 AP qcril 上拦截。

### Vendor AIDL 星座接口

发现 `setGnssSvTypeConfig` 等事务，但设备服务端对应实现疑似空槽/无实际行为，未采用。

### `libloc_api_v02.so` 二进制补丁

曾尝试强制保留 BDS enabled bit。由于本机 KernelSU 是手动加载，magic mount 未生效；
手动 bind 的 mount namespace 也没有传播到 init 重启的 GNSS 服务。最终通过
`/proc/<pid>/root/vendor/...` 证明 GNSS 进程仍使用原厂库，而北斗可以恢复。

因此最终模块完全删除二进制 patch。

## 9. 能证明什么，不能证明什么

已证明：

- 测试硬件能接收北斗；
- EFS/订阅刷新与北斗消失高度相关；
- `5905 + gnss_service restart` 能在测试机热恢复/保持北斗；
- 一次 eSIM 切换后北斗保持。

尚不能普遍证明：

- 所有 OnePlus 15 地区型号都使用相同路径；
- 所有系统版本都安全兼容；
- 每颗可见北斗卫星都会参与每次 position fix；
- 该方法适用于其他 Qualcomm 手机。
