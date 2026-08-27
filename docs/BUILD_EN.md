[简体中文](BUILD.md) | [English](BUILD_EN.md)

# Build and verification

macOS or Linux, Zig, and `zip` are required. From the repository root:

```sh
./scripts/build.sh
```

The script builds a static arm64 client with
`zig cc -target aarch64-linux-musl -static -Os -s`, packages the KernelSU module, and
generates `dist/SHA256SUMS`. Verify with:

```sh
unzip -t dist/oneplus15_bds_guard-v0.4.1.zip
shasum -a 256 -c dist/SHA256SUMS
```

The static program links musl libc; see `third_party/musl-COPYRIGHT` for notices.
