#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MODULE_DIR="$PROJECT_ROOT/module"
SOURCE_FILE="$PROJECT_ROOT/src/gnss_efs_fix.c"
DIST_DIR="$PROJECT_ROOT/dist"
VERSION=$(sed -n 's/^version=//p' "$MODULE_DIR/module.prop")
ZIP_FILE="$DIST_DIR/oneplus15_bds_guard-v$VERSION.zip"

command -v zig >/dev/null 2>&1 || {
    echo "ERROR: zig is required" >&2
    exit 1
}
command -v zip >/dev/null 2>&1 || {
    echo "ERROR: zip is required" >&2
    exit 1
}

mkdir -p "$DIST_DIR"

ZIG_GLOBAL_CACHE_DIR=${ZIG_GLOBAL_CACHE_DIR:-/private/tmp/oneplus-bds-zig-global}
ZIG_LOCAL_CACHE_DIR=${ZIG_LOCAL_CACHE_DIR:-/private/tmp/oneplus-bds-zig-local}
export ZIG_GLOBAL_CACHE_DIR ZIG_LOCAL_CACHE_DIR

zig cc -target aarch64-linux-musl -static -Os -s \
    "$SOURCE_FILE" -o "$MODULE_DIR/bin/gnss_efs_fix"
chmod 0755 "$MODULE_DIR/bin/gnss_efs_fix"

rm -f "$ZIP_FILE"
(
    cd "$MODULE_DIR"
    zip -qr "$ZIP_FILE" .
)

(
    cd "$PROJECT_ROOT"
    shasum -a 256 \
        module/bin/gnss_efs_fix \
        src/gnss_efs_fix.c \
        module/service.sh \
        "dist/$(basename "$ZIP_FILE")" > dist/SHA256SUMS
)

unzip -t "$ZIP_FILE"
echo "Built $ZIP_FILE"
cat "$DIST_DIR/SHA256SUMS"

