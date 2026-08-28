[简体中文](README.md) | [English](README_EN.md)

# OnePlus 15 BeiDou GNSS Guard

> 在中国使用 OnePlus 15 国际版时，修复 eSIM/运营商配置刷新后北斗消失的问题。
> **无需解锁 Bootloader，不刷 modem，不替换 vendor。**

[技术原理](docs/TECHNICAL.md) · [安装与回退](docs/INSTALL.md) · [安全说明](docs/SAFETY.md) · [构建](docs/BUILD.md) · [署名要求](ATTRIBUTION.md)

## 为什么做这个项目

北斗在中国不是一个“有没有都无所谓”的卫星系统。它在本地覆盖、可见卫星数量、
定位可用性和复杂城市环境中都很重要。

我的 OnePlus 15 北美版硬件本身可以接收北斗，但系统会在 eSIM 切换、运营商配置
刷新等场景下让北斗消失。除了实际使用上的损失，硬件明明支持、功能却因为区域配置
被限制，这种“被阉割”的感觉也很不舒服。

这个项目记录了完整排查过程，并提供一个尽量小、可验证、可回退的 KernelSU 模块。

## 为什么更新到 v0.5.1

早期测试发现，北美版 OnePlus 15 冷重启后可以看到北斗，但切换 eSIM、运营商重新注册、
Wi-Fi/VoWiFi 状态变化或移动网络恢复后，北斗可能消失。对比事件发生前后的状态后，问题
逐渐从“GNSS HAL 是否支持北斗”收敛到 modem 在订阅或区域配置刷新时重新生成 GNSS 策略。

运行时检查确认，关键配置位于两个 Qualcomm modem EFS 项：

```text
/nv/item_files/gps/cgps/me/gnss_config
/nv/item_files/gps/cgps/me/gnss_config_Subscription01
```

在部分切换场景中，modem 会把已知的 `05 59 00 00`（`0x5905`）重新写成
`05 49 00 00`（`0x4905`）。因此 v0.5.1 将守护触发扩展到 SIM/eSIM、Wi-Fi、VoWiFi
和移动信号恢复，并在触发后的 180 秒内每 1 秒检查。它仍然只能在写入发生后快速恢复，
不能从 Android AP 侧阻止 modem 内部重新生成配置。

### 最新 MBN/MCFG 扫描结论

进一步扫描和对比 NA、NA/TMO 相关软件模板与 EU 硬件 MCFG 后，已经定位到源头差异：

| 对比模板 | GNSS 配置 |
|---|---|
| NA `mcfg_hw` | `gnss_config = 0x4905`（`05 49 00 00`） |
| EU `mcfg_hw` | `gnss_config = 0x5905`（`05 59 00 00`） |

需要修改的位置已经在 NA MBN/MCFG 模板中定位到对应的 GNSS 区域配置字段。这个结果
解释了为什么运行时 EFS 修复能够恢复北斗，却不能保证 modem 下一次订阅刷新后仍保持
欧版配置。当前还不能安全地断言只改某一个 `NA` 后的字段、把 `4` 改成 `5` 就足够；
必须同时确认字段校验、长度、签名和整份 MBN 的封装关系。

目前本项目没有发布修改后的 MBN。现有环境缺少能够正确完成 MBN 加密、签名或封装的
工具，无法生成可被 modem/PDC 安全接受的修改文件。v0.5.1 因此继续采用可回退的运行时
EFS 守护，不修改 MBN、MCFG 分区、PDC 或 modem 固件。

如果你熟悉 Qualcomm MBN/MCFG 解析与重封装、PDC 配置流程、签名校验或 NA/NA-TMO 与 EU
模板差异分析，欢迎通过 Issue 或 Pull Request 协助验证这个字段并提供安全的工具链。
尤其需要能够保留原有结构和校验、在不触碰 RF 配置的前提下生成可恢复的测试样本。

## 一句话结论

问题不在天线，也不需要刷欧版 modem。关键是 Qualcomm modem 的两个 GNSS EFS
配置项，以及 GNSS HAL 对旧配置的内存缓存。

有效恢复流程是：

```text
检测 SIM/eSIM、Wi-Fi、VoWiFi 状态变化或移动信号恢复
        ↓
进入 180 秒高频守护窗口，每 1 秒检查并修复已存在的 GNSS EFS 项为 0x5905
        ↓
两个值连续稳定 12 秒
        ↓
只重启 Android gnss_service
        ↓
北斗保持或恢复
```

## 不需要解锁 BL，但需要 root

本模块：

- 不要求解锁 Bootloader；
- 不刷写 `boot`、`vendor`、`modem`；
- 不关闭 AVB；
- 不替换或修改 MCFG MBN；
- 不重启 MPSS、modem 或 radio；
- 不修改 RF 频段或射频配置。

但它需要一个已经可用的 **KernelSU root 环境**，因为需要通过手机原厂
`diag_socket_log` 访问 Qualcomm modem EFS，并重启 `gnss_service`。

“无需解锁 BL”指模块本身不依赖 BL 解锁或刷机；它不会自动替你取得 root，也不保证
所有系统版本都能在锁 BL 状态下获得 KernelSU。

## 适用手机

| 设备 | 状态 |
|---|---|
| OnePlus 15 NA，CPH2749 / OP611FL1，项目 24863 | 已实机验证 |
| Android 16，OxygenOS/ColorOS V16.0.5.703 | 已实机验证 |
| Qualcomm Kaanapali modem | 已验证 |
| OnePlus 15 EU CPH2747 | 未验证，通常也不需要此修复 |
| OnePlus 15 India CPH2745 | 未验证，请勿直接安装 |
| OnePlus 15 中国版 PLK110 | 未验证，请勿直接安装 |
| 其他 OnePlus/OPPO/Qualcomm 手机 | 不支持，路径和结构可能不同 |

仅凭“也是骁龙平台”不能判断兼容。模块会访问 modem EFS，错误机型不要尝试。

## 安装

1. 从 [Releases](https://github.com/christuo-dev/oneplus15-beidou-gnss-guard/releases) 下载 `oneplus15_bds_guard-v0.5.1.zip`。
2. 在 KernelSU 管理器中安装模块。
3. 确认模块处于启用状态。
4. 取得 root 后，必要时做一次 Android 软重启，让模块 service 正式运行。
5. 打开 GPSTest、GnssLogger 等工具检查北斗卫星。

模块安装后会自动工作，不需要保持前台应用。

详细命令见 [安装与回退](docs/INSTALL.md)。

## 模块会做什么

它只处理两个路径：

```text
/nv/item_files/gps/cgps/me/gnss_config
/nv/item_files/gps/cgps/me/gnss_config_Subscription01
```

已观察到的值：

```text
NA：05 49 00 00（0x4905）
目标：05 59 00 00（0x5905）
```

安全策略：

- 只接受 `4905` 或 `5905`；
- 任何未知值都拒绝写入；
- 写入后立即回读验证；
- 主项必须存在；
- `Subscription01` 只在存在时修复；
- 某些 eSIM profile 会合法删除第二项，模块不会强行创建它。

SIM/eSIM、Wi-Fi 开关、VoWiFi 连接/断连或通话状态变化，或移动网络从无服务恢复到有服务
后，模块会在 180 秒窗口内每 1 秒读取真实 NV 项。发现 modem
回写 `0549` 时立即带校验恢复为 `0559`；两个值连续稳定 12 秒后，只重启一次
`gnss_service`，让 GNSS HAL 重新读取配置。窗口结束后不再主动访问 GNSS EFS，仅保留
每 2 秒一次的状态轮询。

VoWiFi 通过 `dumpsys telephony.registry`、`dumpsys ims` 和 IMS/WFC 属性识别 WLAN 注册
与通话状态；连接、断连、通话开始和结束都会触发窗口。

模块不能从 AP 侧阻止 modem 内部瞬时写入北美值；它的作用是在写入发生后尽快检测、
恢复并重新加载 GNSS。这样覆盖 modem 延迟回写或订阅切换晚于 SIM 属性变化的情况。

## 已验证现象

- 冷启动后北斗未出现时，两项已经是 `5905`；重启 `gnss_service` 后北斗出现。
- root 和 Android 软重启没有再次弄丢北斗。
- 实测切换 eSIM 后，北斗仍然存在。
- `45403` profile 下第二项被删除，主项保持 `5905`，北斗仍在。
- GNSS 进程仍加载原厂 `libloc_api_v02.so`，不需要二进制 patch。

这里的“北斗恢复”以 Android GNSS 工具能观察、跟踪北斗卫星为实测依据。是否参与
每一次定位解算，还会受到天空可见度、信号强度、测量状态和 GNSS 引擎策略影响。

## 手动检查

```sh
su -c '/data/adb/modules/oneplus15_bds_guard/bin/gnss_efs_fix --check'
```

手动修复并热重载：

```sh
su -c '/data/adb/modules/oneplus15_bds_guard/bin/gnss_efs_fix --repair'
su -c 'setprop ctl.restart gnss_service'
```

日志：

```text
/data/adb/oneplus15_bds_guard/service.log
```

## 回退

在 KernelSU 中禁用或卸载模块，然后重启。模块不修改只读分区，禁用后不会再运行。

紧急禁用：

```sh
su -c 'touch /data/adb/modules/oneplus15_bds_guard/disable'
```

卸载脚本会尝试把仍存在且值已知的 GNSS EFS 项恢复为 `4905`。建议操作前保留自己
设备的 modemst/fsg/fsc 或相关 NV 备份。

## 风险提示

这是面向特定设备的底层研究项目，不是通用“北斗解锁器”。错误机型、不同 modem
版本或 OEM 改动可能导致行为不同。使用前请完整阅读 [安全说明](docs/SAFETY.md)。

## 项目结构

```text
module/                 KernelSU 模块内容
src/gnss_efs_fix.c      Qualcomm DIAG/EFS 客户端源码
scripts/build.sh        可复现编译与打包脚本
docs/TECHNICAL.md       原理、证据和失败路线
docs/INSTALL.md         安装、验证和回退
docs/SAFETY.md          安全边界与兼容性
dist/                   已构建发布包
```

## License

项目代码使用 [MIT License](LICENSE)，另有[非正式中文说明](LICENSE.zh-CN.md)。静态客户端使用 musl libc 构建，相关许可见
[`third_party/musl-COPYRIGHT`](third_party/musl-COPYRIGHT)。

研究文档、原理、EFS 路径整理和实现思路的引用/借鉴必须署名。制作衍生模块、文章、
视频、教程或移植时，请显著注明项目名、作者 `christuo-dev` 和原仓库链接。完整格式见
[署名要求](ATTRIBUTION.md)。

研究与实机验证：[@christuo-dev](https://github.com/christuo-dev)。分析和工程整理过程中
使用了 OpenAI Codex 协助。
