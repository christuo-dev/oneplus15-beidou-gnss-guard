[简体中文](INSTALL.md) | [English](INSTALL_EN.md)

# 安装、验证与回退

## 前提

- 已确认设备是 OnePlus 15 NA CPH2749 / OP611FL1，项目 24863；
- 已有可用 KernelSU root；
- 无需解锁 Bootloader；
- 保持 Wi‑Fi/ADB 连接；
- 建议先备份 modemst/fsg/fsc 或相关 NV。

## 安装模块

在 KernelSU 管理器选择 Release 中的：

```text
oneplus15_bds_guard-v0.5.1.zip
```

或使用 root shell：

```sh
cp oneplus15_bds_guard-v0.5.1.zip /data/local/tmp/
su -c '/data/adb/ksu/bin/ksud module install /data/local/tmp/oneplus15_bds_guard-v0.5.1.zip'
su -c '/data/adb/ksu/bin/ksud module enable oneplus15_bds_guard'
```

本测试机使用手动 KernelSU root。若安装后 service 没有启动，取得 root 后做一次 Android
软重启，不需要冷重启或解锁 BL。

## 检查模块

```sh
su -c 'cat /data/adb/modules/oneplus15_bds_guard/module.prop'
su -c '/data/adb/ksu/bin/ksud module list'
su -c 'ps -A -o PID,PPID,USER,ARGS | grep oneplus15_bds_guard/service.sh'
```

预期版本：

```text
version=0.5.1
versionCode=10
```

## 检查 GNSS EFS

只读检查：

```sh
su -c '/data/adb/modules/oneplus15_bds_guard/bin/gnss_efs_fix --check'
```

可能的正常输出：

```text
/nv/item_files/gps/cgps/me/gnss_config = 05 59 00 00
OPTIONAL_MISSING: /nv/item_files/gps/cgps/me/gnss_config_Subscription01
```

`OPTIONAL_MISSING` 并非错误；部分 eSIM profile 不创建订阅项。

## 手动恢复

```sh
su -c '/data/adb/modules/oneplus15_bds_guard/bin/gnss_efs_fix --repair'
su -c 'setprop ctl.restart gnss_service'
```

等待约 5–15 秒，再用 GNSS 工具观察北斗。

## 自动测试 eSIM

1. 确认 watcher 正在运行；
2. 切换 eSIM；
3. 等待至少 25 秒；
4. 检查北斗；
5. 查看日志：

```sh
su -c 'tail -150 /data/adb/oneplus15_bds_guard/service.log'
```

预期至少出现：

```text
subscription state changed
restarting gnss_service
gnss_service running
```

如果检测到已知的 `0549` 偏差，日志还会出现 `check mismatch` 和
`repair start reason=subscription_change`。配置本来就是 `0559` 时不会执行写入。
窗口结束后不再进行周期性 GNSS EFS 检查，仅保留状态轮询。

## 禁用与卸载

KernelSU 管理器中禁用，或：

```sh
su -c '/data/adb/ksu/bin/ksud module disable oneplus15_bds_guard'
```

紧急禁用：

```sh
su -c 'touch /data/adb/modules/oneplus15_bds_guard/disable'
```

然后重启。卸载脚本会尝试将仍存在的已知项恢复为 `4905`。

## 故障反馈需要提供

- 精确型号、项目号、系统版本、baseband 版本；
- `module.prop`；
- `service.log` 中问题前后约 150 行；
- eSIM 切换前后 `gsm.sim.operator.numeric`；
- `gnss_efs_fix --check` 输出；
- GNSS 工具截图。

请删除 IMEI、ICCID、手机号、个人位置等敏感内容后再公开提交。
