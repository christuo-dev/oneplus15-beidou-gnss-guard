[简体中文](BUILD.md) | [English](BUILD_EN.md)

# 构建与校验

需要 macOS/Linux、Zig 和 `zip`。在仓库根目录执行：

```sh
./scripts/build.sh
```

脚本使用 `zig cc -target aarch64-linux-musl -static -Os -s` 构建 arm64 静态客户端，
打包 KernelSU 模块，并生成 `dist/SHA256SUMS`。校验：

```sh
unzip -t dist/oneplus15_bds_guard-v0.4.1.zip
shasum -a 256 -c dist/SHA256SUMS
```

静态程序链接 musl libc，许可声明见 `third_party/musl-COPYRIGHT`。
