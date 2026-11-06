#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# Installs what sim/zephyr/run.py (Zephyr on the simulated SoC) needs, at
# pinned versions: west, a Zephyr workspace in $ZEPHYR_WS (default
# ~/zephyrproject) with the Zephyr tree at ZEPHYR_REV and no modules (the
# SDK's picolibc is enough), Zephyr's base Python requirements, and the
# Zephyr SDK (minimal plus the RISC-V GNU toolchain) in
# $ZEPHYR_SDK_INSTALL_DIR (default ~/zephyr-sdk-<version>), registered as a
# CMake package, and the Python packages twister imports. Steps already at
# their pin are skipped. Then applies sw/zephyr/patches/*.patch to the Zephyr
# tree (fixes not yet upstream). Needs gperf (userspace builds): apt install gperf.
set -euo pipefail

ZEPHYR_REV=v4.4.2                     # latest Zephyr release (2026-10-17)
SDK_VER=1.0.1                         # Zephyr v4.4.2 SDK_VERSION
SDK_SHA_MIN=ca9bc0ff66fafca1dac9d592a36d953cf16d096a9d09b1c0357f021cf9f6a7eb
SDK_SHA_RV=01750834c471fbdb335c1b8b8aee17010a1968938957db85640c366235771a38
SDK_URL=https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v$SDK_VER
ZEPHYR_WS=${ZEPHYR_WS:-$HOME/zephyrproject}
SDK=${ZEPHYR_SDK_INSTALL_DIR:-$HOME/zephyr-sdk-$SDK_VER}

python3 -m pip install -q "west==1.5.0"

if [ ! -d "$ZEPHYR_WS/.west" ]; then
  west init -m https://github.com/zephyrproject-rtos/zephyr --mr "$ZEPHYR_REV" "$ZEPHYR_WS"
fi
if [ "$(git -C "$ZEPHYR_WS/zephyr" describe --tags --exact-match 2>/dev/null)" != "$ZEPHYR_REV" ]; then
  git -C "$ZEPHYR_WS/zephyr" fetch -q origin tag "$ZEPHYR_REV"
  git -C "$ZEPHYR_WS/zephyr" checkout -q "$ZEPHYR_REV"
fi
(cd "$ZEPHYR_WS" && west config file list.project-filter -- '-.*' && west -q update)
python3 -m pip install -q -r "$ZEPHYR_WS/zephyr/scripts/requirements-base.txt"
python3 -m pip install -q "pytest==9.1.1" "natsort==8.4.0" "psutil==7.2.2" "tabulate==0.10.0" \
  "colorama==0.4.6" "ply==3.11" "junitparser==5.0.3" "python-dotenv==1.2.4" "pyserial==3.5"
command -v gperf > /dev/null || echo "install_zephyr.sh: gperf is missing (apt install gperf)" >&2
for p in "$(dirname "$0")"/../sw/zephyr/patches/*.patch; do
  if ! git -C "$ZEPHYR_WS/zephyr" apply --reverse --check "$(realpath "$p")" 2> /dev/null; then
    git -C "$ZEPHYR_WS/zephyr" apply "$(realpath "$p")"
  fi
done
echo "Zephyr: $ZEPHYR_WS/zephyr at $ZEPHYR_REV with $(ls "$(dirname "$0")"/../sw/zephyr/patches | wc -l) patch(es)"

if [ "$(cat "$SDK/sdk_version" 2>/dev/null)" != "$SDK_VER" ] || [ ! -d "$SDK/gnu/riscv64-zephyr-elf" ]; then
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/min.tar.xz" "$SDK_URL/zephyr-sdk-${SDK_VER}_linux-x86_64_minimal.tar.xz"
  curl -sSL -o "$tmp/rv.tar.xz" "$SDK_URL/toolchain_gnu_linux-x86_64_riscv64-zephyr-elf.tar.xz"
  echo "$SDK_SHA_MIN  $tmp/min.tar.xz" | sha256sum -c --quiet
  echo "$SDK_SHA_RV  $tmp/rv.tar.xz" | sha256sum -c --quiet
  rm -rf "$SDK" && mkdir -p "$SDK/gnu"
  tar xJf "$tmp/min.tar.xz" --strip-components=1 -C "$SDK"
  tar xJf "$tmp/rv.tar.xz" -C "$SDK/gnu"
  rm -rf "$tmp"
fi
(cd "$SDK" && ./setup.sh -c > /dev/null)
echo "Zephyr SDK: $("$SDK/gnu/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc" --version | head -1)"
