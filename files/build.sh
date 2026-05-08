#!/usr/bin/env bash
# build.sh — cross-compile exp.c statically for x86_64, aarch64, armv7, i386
# using zig cc + musl. Produces fully static binaries with no libc dependency.
#
# Requirements:
#   - zig (>= 0.11): https://ziglang.org/download/  (or: snap install zig --classic --beta)
#   - linux-libc-dev (provides /usr/include/linux/*): apt install linux-libc-dev
#
# Usage:
#   ./build.sh                # build all targets into ./files/
#   ./build.sh x86_64         # build a single target
#
# Output: files/exp-linux-<arch>

set -euo pipefail

SRC="files/exp.c"
OUT_DIR="files"

if ! command -v zig >/dev/null 2>&1; then
    echo "error: zig not found. Install from https://ziglang.org/download/" >&2
    exit 1
fi

if [[ ! -f "$SRC" ]]; then
    echo "error: $SRC not found" >&2
    exit 1
fi

# Pull in the host's Linux UAPI headers (linux/xfrm.h, linux/rtnetlink.h, etc.)
# in case zig's bundled copy is missing newer structs/constants.
EXTRA_INCLUDES=()
if [[ -d /usr/include/linux ]]; then
    EXTRA_INCLUDES+=(-isystem /usr/include)
fi
# Arch-generic kernel headers live here on Debian/Ubuntu
if [[ -d /usr/include/x86_64-linux-gnu ]]; then
    EXTRA_INCLUDES+=(-isystem /usr/include/x86_64-linux-gnu)
fi

# target-triple : output-suffix
declare -A TARGETS=(
    [x86_64]="x86_64-linux-musl"
    [aarch64]="aarch64-linux-musl"
    [armv7]="arm-linux-musleabihf"
    [i386]="x86-linux-musl"
)

build_one() {
    local arch="$1"
    local triple="${TARGETS[$arch]:-}"
    if [[ -z "$triple" ]]; then
        echo "error: unknown arch '$arch' (valid: ${!TARGETS[*]})" >&2
        return 1
    fi

    local out="$OUT_DIR/exp-linux-$arch"
    echo ">> building $arch ($triple) -> $out"

    zig cc \
        -target "$triple" \
        -O2 -s -static \
        -fno-stack-protector \
        "${EXTRA_INCLUDES[@]}" \
        "$SRC" -o "$out"

    # Strip again for good measure (zig cc -s already does this, but harmless)
    if command -v strip >/dev/null 2>&1; then
        strip --strip-all "$out" 2>/dev/null || true
    fi

    local size
    size=$(stat -c%s "$out" 2>/dev/null || stat -f%z "$out")
    printf "   ok: %s (%s bytes)\n" "$out" "$size"
}

mkdir -p "$OUT_DIR"

if [[ $# -gt 0 ]]; then
    for arch in "$@"; do
        build_one "$arch"
    done
else
    for arch in "${!TARGETS[@]}"; do
        build_one "$arch"
    done
fi

echo
echo "done. binaries:"
ls -lh "$OUT_DIR"/exp-linux-* 2>/dev/null || true
