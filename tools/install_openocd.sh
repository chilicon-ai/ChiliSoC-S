#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# Builds OpenOCD from a pinned upstream commit into $PREFIX (default
# ~/openocd), with only the remote_bitbang adapter (the simulation's). The last
# OpenOCD release (0.12.0, 2023) predates the RISC-V trigger and debug fixes
# of upstream master; sim/run.py prefers $OPENOCD, then ~/openocd/bin/openocd,
# then openocd on PATH. Needs git, autoconf, automake, libtool, pkg-config and
# jimtcl (Debian / Ubuntu: libjim-dev).
#
#   tools/install_openocd.sh            build (skipped when already at the pin)
set -euo pipefail

OPENOCD_REV=bb5a52da599c3dac61ddc51d2fa8c1166ee795d0     # openocd-org/openocd master 2026-10-16
PREFIX=${PREFIX:-$HOME/openocd}
SRC=${SRC:-$HOME/openocd-src}

if [ "$(cat "$PREFIX/.rev" 2>/dev/null)" = "$OPENOCD_REV" ]; then
  echo "openocd: $PREFIX already at $OPENOCD_REV"
  exit 0
fi
if [ ! -d "$SRC/.git" ]; then
  git clone -q https://github.com/openocd-org/openocd.git "$SRC"
fi
git -C "$SRC" fetch -q origin
git -C "$SRC" checkout -q "$OPENOCD_REV"
cd "$SRC"
./bootstrap nosubmodule >/dev/null
./configure -q --prefix="$PREFIX" --disable-werror --disable-doxygen-html --disable-internal-libjaylink \
  --enable-remote-bitbang --disable-ftdi --disable-stlink --disable-ti-icdi --disable-ulink --disable-angie \
  --disable-usb-blaster-2 --disable-ft232r --disable-vsllink --disable-xds110 --disable-cmsis-dap-v2 \
  --disable-osbdm --disable-opendous --disable-armjtagew --disable-rlink --disable-usbprog \
  --disable-esp-usb-jtag --disable-cmsis-dap --disable-nulink --disable-kitprog --disable-usb-blaster \
  --disable-presto --disable-openjtag --disable-buspirate --disable-jlink --disable-parport \
  --disable-jtag_vpi --disable-vdebug --disable-jtag_dpi --disable-linuxgpiod --disable-sysfsgpio
make -s -j"$(nproc)" >/dev/null
make -s install >/dev/null
echo "$OPENOCD_REV" > "$PREFIX/.rev"
"$PREFIX/bin/openocd" --version 2>&1 | head -1
