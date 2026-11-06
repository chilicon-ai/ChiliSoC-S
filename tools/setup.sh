#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# One-step setup of everything ChiliSoC-S, ChillU-S, ChiliMix and BaseChiliSV
# need on a fresh Ubuntu 24.04 (x86-64): system packages, Python packages,
# Yosys / Verilator (OSS CAD Suite), the RISC-V cross compiler and the
# simulation reference tools, at pinned versions, under one prefix.
#
#   tools/setup.sh                 install what is missing (asks sudo for apt)
#   tools/setup.sh --list          show what would be installed, change nothing
#   tools/setup.sh --with openocd,debug,zephyr   also the optional extras
#   tools/setup.sh --prefix DIR    install under DIR (default ~/chilisocs-tools)
#   tools/setup.sh --no-apt        skip apt (packages already installed)
#
# Then:  source ~/chilisocs-tools/env.sh && python tools/check.py
# Rerunning is safe: each step checks its version and skips what is in place.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="$HOME/chilisocs-tools"
LIST=0
APT=1
WITH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list) LIST=1 ;;
    --no-apt) APT=0 ;;
    --prefix) PREFIX="$2"; shift ;;
    --with) WITH="$2"; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "setup: unknown option $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done
PREFIX="$(realpath -m "$PREFIX")"
want() { case ",$WITH," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

OCS_DATE=2026-10-10   # OSS CAD Suite release: Yosys + yosys-slang, Verilator 5, SymbiYosys
OCS_DIR="$PREFIX/oss-cad-suite"
VENV="$PREFIX/venv"
SIM="$PREFIX/simtools"
APT_PKGS=(
  python3 python3-pip python3-venv git curl ca-certificates xz-utils make g++
  device-tree-compiler libboost-regex-dev libboost-system-dev
  gcc-riscv64-unknown-elf picolibc-riscv64-unknown-elf
)

if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; D=$'\e[2m'; N=$'\e[0m'; else B=""; G=""; D=""; N=""; fi
STEP=0
TOTAL=5
for x in openocd debug zephyr; do if want $x; then TOTAL=$((TOTAL + 1)); fi; done
T0=$SECONDS
# step <title> <purpose>: one numbered header per install
step() { STEP=$((STEP + 1)); printf '\n%s[%d/%d] %s%s\n      %s%s%s\n' "$B" "$STEP" "$TOTAL" "$1" "$N" "$D" "$2" "$N"; }
done_() { printf '      %sdone%s %s(%ds)%s\n' "$G" "$N" "$D" "$((SECONDS - S0))" "$N"; }
skip() { printf '      %salready installed%s: %s\n' "$G" "$N" "$1"; }
run() { if [ "$LIST" = 1 ]; then printf '      %swould run:%s %s\n' "$D" "$N" "$*"; else "$@"; fi; }

printf '%sChiliSoC-S setup%s: tools under %s\n' "$B" "$N" "$PREFIX"
[ "$LIST" = 1 ] && echo "(--list: nothing is changed)"

# 1. System packages
step "System packages (apt)" \
     "Python, git, a C++ compiler and Boost to build Spike, and the RISC-V GCC with picolibc for the test programs and CoreMark."
S0=$SECONDS
if [ "$APT" = 0 ]; then
  echo "      skipped (--no-apt): ${APT_PKGS[*]}"
else
  missing=()
  for p in "${APT_PKGS[@]}"; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "ok installed" || missing+=("$p"); done
  if [ ${#missing[@]} = 0 ]; then skip "all ${#APT_PKGS[@]} packages"
  else
    echo "      installing: ${missing[*]}"
    SUDO=""; [ "$(id -u)" = 0 ] || SUDO=sudo
    if [ "$LIST" = 1 ]; then
      run $SUDO apt-get install -y --no-install-recommends "${missing[@]}"
    else
      mkdir -p "$PREFIX/logs"; log="$PREFIX/logs/apt.log"
      echo "      log: $log"
      if ! { $SUDO apt-get update -q && $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
               --no-install-recommends "${missing[@]}"; } > "$log" 2>&1; then
        tail -20 "$log"; echo "setup: apt failed (full log: $log)" >&2; exit 1
      fi
      done_
    fi
  fi
fi

# 2. Python packages
step "Python packages (venv $VENV)" \
     "The packages pinned in tools/requirements.txt (pyslang: slang for the lint and RTL rule checks); in a venv, as Ubuntu 24.04 keeps the system Python read-only."
S0=$SECONDS
req="$ROOT/tools/requirements.txt"
stamp="$VENV/.req"
if [ -f "$stamp" ] && cmp -s "$stamp" "$req"; then skip "$(grep -vE '^\s*(#|$)' "$req" | sed 's/[[:space:]]*#.*//' | paste -sd, - | sed 's/,/, /g')"
else
  run python3 -m venv "$VENV"
  run "$VENV/bin/pip" install -q --upgrade pip
  run "$VENV/bin/pip" install -q -r "$req"
  [ "$LIST" = 1 ] || { cp "$req" "$stamp"; done_; }
fi

# 3. OSS CAD Suite
step "OSS CAD Suite $OCS_DATE ($OCS_DIR)" \
     "Yosys with the slang plugin (synthesis checks), Verilator 5 (all simulation) and SymbiYosys; one prebuilt download, about 600 MB unpacked."
S0=$SECONDS
if [ "$(cat "$OCS_DIR/VERSION" 2>/dev/null)" = "${OCS_DATE//-/}" ]; then skip "OSS CAD Suite ${OCS_DATE}"
else
  url="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/$OCS_DATE/oss-cad-suite-linux-x64-${OCS_DATE//-/}.tgz"
  echo "      download: $url"
  if [ "$LIST" = 0 ]; then
    rm -rf "$OCS_DIR" && mkdir -p "$PREFIX"
    curl -fsSL "$url" | tar xz -C "$PREFIX"
    done_
  fi
fi

# 4. Simulation reference tools
step "Simulation reference tools ($SIM)" \
     "Spike (the reference the core's trace is compared with, built from source, a few minutes), riscv-tests, CoreMark, riscv-arch-test, the Sail model and RISCOF (conformance), at pinned commits."
S0=$SECONDS
if [ "$LIST" = 1 ]; then
  run bash "$ROOT/lib/chillus/tools/install_sim_tools.sh" "$SIM"
else
  mkdir -p "$PREFIX/logs"; log="$PREFIX/logs/simtools.log"
  echo "      log: $log"
  if ! bash "$ROOT/lib/chillus/tools/install_sim_tools.sh" "$SIM" > "$log" 2>&1; then
    tail -20 "$log"; echo "setup: simulation tools failed (full log: $log)" >&2; exit 1
  fi
  built=$( { grep -E '^install_sim_tools: (Spike|Sail|RISCOF)' "$log" || true; } | sed 's/^install_sim_tools: //; s/\([0-9a-f]\{7\}\)[0-9a-f]*/\1/' | paste -sd, - | sed 's/,/, /g')
  if [ -z "$built" ]; then skip "Spike, riscv-tests, CoreMark, riscv-arch-test, Sail, RISCOF"
  else echo "      installed: $built; riscv-tests, CoreMark, riscv-arch-test at their pins"; done_; fi
fi

# 5. Optional extras
if want openocd; then
  step "OpenOCD (optional)" "Built from a pinned commit for the openocd test (a real OpenOCD + GDB session on the model's JTAG pins)."
  S0=$SECONDS; run bash "$ROOT/tools/install_openocd.sh"; [ "$LIST" = 1 ] || done_
fi
if want debug; then
  step "riscv-tests debug suite (optional)" "The debug suite's checkout and the xPack toolchain for python sim/debug/run.py."
  S0=$SECONDS; run bash "$ROOT/tools/install_debug_tests.sh"; [ "$LIST" = 1 ] || done_
fi
if want zephyr; then
  step "Zephyr (optional)" "Zephyr, its SDK and twister at pinned versions, for python sim/zephyr/run.py (several GB)."
  S0=$SECONDS; run bash "$ROOT/tools/install_zephyr.sh"; [ "$LIST" = 1 ] || done_
fi

# 6. Environment file
step "Environment ($PREFIX/env.sh)" \
     "One file to source: the venv's python, the OSS CAD Suite tools (after the system ones, so they never shadow the system Python) and the simulation tool paths."
S0=$SECONDS
if [ "$LIST" = 0 ]; then
  {
    echo "# ChiliSoC-S tools (written by tools/setup.sh)"
    echo "source \"$VENV/bin/activate\""
    echo "export YOSYS=\"$OCS_DIR/bin/yosys\""
    echo "export PATH=\"\$PATH:$OCS_DIR/bin\""
    bash "$ROOT/lib/chillus/tools/install_sim_tools.sh" --env "$SIM"
  } > "$PREFIX/env.sh"
  done_
else
  echo "      would write $PREFIX/env.sh"
fi

# Summary: what is installed, where, and what for
if [ "$LIST" = 0 ]; then
  # shellcheck disable=SC1091
  source "$PREFIX/env.sh"
  ver() { "$@" 2>/dev/null | head -1 || true; }
  printf '\n%sInstalled%s\n' "$B" "$N"
  row() { printf '  %-30s %-24s %s\n      %s%s%s\n' "$1" "${2:-MISSING}" "$3" "$D" "$4" "$N"; }
  rev() { if [ -f "$1" ]; then cut -c1-7 "$1"; fi; }
  row "Python + packages" "$(python --version 2>&1 | cut -d' ' -f2), pyslang $(python -c 'import pyslang; print(pyslang.__version__)' 2>/dev/null)" "$VENV" "lint, RTL rules, all the Python tools"
  row "Yosys + slang" "$(ver "$YOSYS" -V | cut -d' ' -f2)" "$OCS_DIR" "synthesis checks"
  row "Verilator" "$(ver verilator --version | cut -d' ' -f2)" "$OCS_DIR" "every simulation (SoC, core, testbenches)"
  row "RISC-V GCC" "$(riscv64-unknown-elf-gcc -dumpversion 2>/dev/null)" "/usr (apt)" "test programs, boot ROM, CoreMark"
  row "Spike" "$(rev "$SIM/spike/.rev")" "$SIM/spike" "reference simulator the core's trace is compared with"
  row "riscv-tests" "$(rev "$SIM/riscv-tests/.rev")" "$SIM/riscv-tests" "ISA tests run on the core"
  row "CoreMark" "$(rev "$SIM/coremark/.rev")" "$SIM/coremark" "benchmark sources (EEMBC)"
  row "riscv-arch-test" "$(rev "$SIM/riscv-arch-test/.rev")" "$SIM/riscv-arch-test" "conformance tests: sim/conformance/run_act.py"
  row "Sail RISC-V model" "$(cat "$SIM/sail-riscv/.rev" 2>/dev/null)" "$SIM/sail-riscv" "conformance reference model"
  row "RISCOF" "$(rev "$SIM/riscof-venv/.rev")" "$SIM/riscof-venv" "conformance test runner"
fi

printf '\n%sSetup complete%s in %ds. In each new shell:\n\n    source %s/env.sh\n\nthen, from %s:\n\n    python tools/check.py\n\n' \
  "$B" "$N" "$((SECONDS - T0))" "$PREFIX" "$ROOT"
