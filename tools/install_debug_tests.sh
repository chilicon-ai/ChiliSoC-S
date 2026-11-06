#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# Installs what sim/debug/run.py (the riscv-tests debug suite) needs, at the
# versions riscv-tests' own CI uses: riscv-tests at a pinned commit (with its
# env submodule) in $RISCV_TESTS (default ~/riscv-tests), the xPack RISC-V
# toolchain in $XPACK_RISCV (default ~/xpack-riscv), and Python pexpect /
# PyYAML. OpenOCD comes from tools/install_openocd.sh. Steps already at their
# pin are skipped.
set -euo pipefail

RISCV_TESTS_REV=d7e86f701b929b5d801f8cda1a4871ab05f452bb    # riscv-tests master 2026-10-14
XPACK_VER=15.2.0-1                                          # riscv-tests CI (spike-openocd-tests.yml)
XPACK_URL=https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v$XPACK_VER/xpack-riscv-none-elf-gcc-$XPACK_VER-linux-x64.tar.gz
RISCV_TESTS=${RISCV_TESTS:-$HOME/riscv-tests}
XPACK_RISCV=${XPACK_RISCV:-$HOME/xpack-riscv}

if [ ! -d "$RISCV_TESTS/.git" ]; then
  git clone -q https://github.com/riscv-software-src/riscv-tests.git "$RISCV_TESTS"
fi
if [ "$(git -C "$RISCV_TESTS" rev-parse HEAD)" != "$RISCV_TESTS_REV" ]; then
  git -C "$RISCV_TESTS" fetch -q origin
  git -C "$RISCV_TESTS" checkout -q "$RISCV_TESTS_REV"
fi
git -C "$RISCV_TESTS" submodule update -q --init env
echo "riscv-tests: $RISCV_TESTS at $RISCV_TESTS_REV"

if [ "$(cat "$XPACK_RISCV/.ver" 2>/dev/null)" != "$XPACK_VER" ]; then
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/xpack.tgz" "$XPACK_URL"
  rm -rf "$XPACK_RISCV" && mkdir -p "$XPACK_RISCV"
  tar zxf "$tmp/xpack.tgz" --strip-components=1 -C "$XPACK_RISCV"
  rm -rf "$tmp"
  echo "$XPACK_VER" > "$XPACK_RISCV/.ver"
fi
echo "xPack toolchain: $("$XPACK_RISCV/bin/riscv-none-elf-gdb" --version | head -1)"

python3 -m pip install -q "pexpect==4.9.0" "PyYAML==6.0.3"
