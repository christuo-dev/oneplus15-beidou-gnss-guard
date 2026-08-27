[简体中文](SAFETY.md) | [English](SAFETY_EN.md)

# 安全、兼容性与免责声明

## 这是特定设备研究，不是通用模块

唯一完成实机验证的目标是：

```text
OnePlus 15 NA CPH2749 / OP611FL1
Project 24863
Qualcomm Kaanapali modem
Android 16 / OxygenOS 16.0.5.703
```

其他地区版、其他系统版本和其他 Qualcomm 手机均不能自动视为兼容。

## 无需解锁 BL 的边界

模块不刷分区、不修改 boot 镜像，因此模块自身不要求解锁 Bootloader。但它仍需要
已经工作的 KernelSU root。如何在锁 BL 状态下取得 root 不属于本仓库保证范围。

## 模块明确不会做的事

- 不刷 boot/vendor/modem；
- 不关闭 AVB；
- 不替换 MCFG；
- 不修改 RF 频段或发射参数；
- 不重启 MPSS/modem/radio；
- 不强建缺失的订阅 EFS 项；
- 不写入 `4905`/`5905` 之外的未知值；
- 不使用 vendor GNSS 二进制 patch。

## 仍然存在的风险

modem EFS 属于底层配置。即使写入范围很小，OEM firmware 更新、路径变化、DIAG
实现差异或错误机型仍可能带来定位异常、耗电、服务崩溃或其他未知后果。

使用者应自行承担风险，并在操作前保留可恢复备份。本项目不保证适销性、特定用途
适用性或数据安全，具体法律条款见 MIT License。

## 报告问题时的隐私

日志和截图可能包含运营商、位置、SIM 状态等信息。公开 Issue 前请移除：

- IMEI/MEID；
- ICCID/EID；
- 手机号；
- 精确经纬度；
- Wi‑Fi 名称和其他账户信息。
