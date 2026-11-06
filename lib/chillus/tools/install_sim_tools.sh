#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# Install the simulation reference tools sim/run.py and sim/conformance/run_act.py
# need, at pinned versions, under one prefix (default ~/simtools), and print
# the environment variables that point the scripts at them. The top-level
# tools/setup.sh runs it, with OSS CAD Suite (Verilator, Yosys) and the cross
# compiler (apt gcc-riscv64-unknown-elf), which do not come from here.
#
#   tools/install_sim_tools.sh [prefix]        install what is missing
#   eval "$(tools/install_sim_tools.sh --env [prefix])"
#
# Spike is built from source (needs g++, device-tree-compiler, libboost-regex-dev,
# libboost-system-dev); the rest are clones, a release binary and a venv.
# Bump a pin by editing it here.
set -euo pipefail

SPIKE_REV=17e8a69fb75546dea445cfc0fb78769d2510f339        # riscv-isa-sim master 2026-10
RISCV_TESTS_REV=7b68f7b91f827f8d94cc1c57ff123752c5c8f704  # riscv-tests master 2026-10
COREMARK_REV=1f483d5                                      # eembc/coremark (as ChiliSoC-S CI)
ARCH_TEST_REV=9bceaf5c02fa1131625bc6228b834e9e884c5801    # riscv-arch-test old-framework-3.x
RISCOF_REV=90ebd1bf48bc7928a5f6a7b0b4993f9fbc944f47       # riscv/riscof master 2026-10 (evaluates "verify":
RISCV_ISAC_REV=777d2b47623d7eebdb8bbed06dbddedc33722346   #   PMP tests); riscv-isac master (PyPI 0.18 is too old)
RISCV_CONFIG_REV=23b030765662aa777a11076a8b0991dc4fec1259 # riscv-config dev 3.20.0 (the ISA yaml's PMP node; PyPI 3.18 has none)
SAIL_VERSION=0.15                                         # riscv/sail-riscv release binary

ENV_ONLY=0
if [ "${1:-}" = "--env" ]; then ENV_ONLY=1; shift; fi
P="$(realpath -m "${1:-$HOME/simtools}")"

print_env() {
  echo "export PATH=\"$P/spike/bin:\$PATH\""
  echo "export RISCV_TESTS=\"$P/riscv-tests\""
  echo "export COREMARK=\"$P/coremark\""
  echo "export ARCH_TEST=\"$P/riscv-arch-test\""
  echo "export RISCOF=\"$P/riscof-venv/bin/riscof\""
  echo "export SAIL_RISCV=\"$P/sail-riscv/bin/sail_riscv_sim\""
}
if [ "$ENV_ONLY" = 1 ]; then print_env; exit 0; fi

mkdir -p "$P"
log() { echo "install_sim_tools: $*" >&2; }

# clone <url> <dir> <rev> [--recursive]: shallow fetch of one commit
clone() {
  local url=$1 dir=$2 rev=$3
  [ -f "$dir/.rev" ] && [ "$(cat "$dir/.rev")" = "$rev" ] && return 0
  rm -rf "$dir"
  git clone -q "$url" "$dir"
  git -C "$dir" checkout -q "$rev"
  if [ "${4:-}" = --recursive ]; then git -C "$dir" submodule update -q --init --recursive; fi
  echo "$rev" > "$dir/.rev"
}

if [ "$(cat "$P/spike/.rev" 2>/dev/null)" != "$SPIKE_REV" ]; then
  log "Spike $SPIKE_REV (build)"
  src="$P/spike-src"
  clone https://github.com/riscv-software-src/riscv-isa-sim "$src" "$SPIKE_REV"
  rm -rf "$P/spike" "$src/build" && mkdir -p "$src/build"
  (cd "$src/build" && ../configure -q --prefix="$P/spike" >/dev/null && make -s -j"$(nproc)" >/dev/null && make -s install >/dev/null 2>&1)
  rm -rf "$src"
  echo "$SPIKE_REV" > "$P/spike/.rev"
fi

log "riscv-tests, CoreMark, riscv-arch-test"
clone https://github.com/riscv-software-src/riscv-tests "$P/riscv-tests" "$RISCV_TESTS_REV" --recursive
clone https://github.com/eembc/coremark "$P/coremark" "$COREMARK_REV"
clone https://github.com/riscv-non-isa/riscv-arch-test "$P/riscv-arch-test" "$ARCH_TEST_REV"

if [ "$(cat "$P/sail-riscv/.rev" 2>/dev/null)" != "$SAIL_VERSION" ]; then
  log "Sail $SAIL_VERSION"
  rm -rf "$P/sail-riscv" && mkdir -p "$P/sail-riscv"
  curl -fsSL "https://github.com/riscv/sail-riscv/releases/download/$SAIL_VERSION/sail-riscv-Linux-x86_64.tar.gz" \
    | tar xz -C "$P/sail-riscv" --strip-components=1
  echo "$SAIL_VERSION" > "$P/sail-riscv/.rev"
fi

if [ "$(cat "$P/riscof-venv/.rev" 2>/dev/null)" != "$RISCOF_REV-$RISCV_ISAC_REV-$RISCV_CONFIG_REV" ]; then
  log "RISCOF $RISCOF_REV"
  rm -rf "$P/riscof-venv"
  python3 -m venv "$P/riscof-venv"
  "$P/riscof-venv/bin/pip" install -q "git+https://github.com/riscv/riscof@$RISCOF_REV" \
    "git+https://github.com/riscv-software-src/riscv-isac@$RISCV_ISAC_REV" \
    "git+https://github.com/riscv-software-src/riscv-config@$RISCV_CONFIG_REV"
  echo "$RISCOF_REV-$RISCV_ISAC_REV-$RISCV_CONFIG_REV" > "$P/riscof-venv/.rev"
fi

log "done: $P"
