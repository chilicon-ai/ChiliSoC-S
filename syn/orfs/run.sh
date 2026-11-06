#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# Run an ORFS design from syn/orfs/<platform>/<design> in the pinned ORFS
# image: under Apptainer when the machine has its .sif, else under Docker.
#
#   syn/orfs/run.sh [platform/]design [make args...]
#   syn/orfs/run.sh chilisocs                      full flow, Nangate45
#   syn/orfs/run.sh chilisocs CLK_PERIOD=3.0        other clock period
#   syn/orfs/run.sh chilisocs synth                 one stage (make target)
#   syn/orfs/run.sh chilisocs MEM_WAIT=0           top parameter (config.mk)
#
# The repository is mounted read-only at /soc; results, logs and reports
# go to syn/orfs/out/<design>[_<tag>]/ (WORK_HOME). TAG=<name> keeps runs
# apart, e.g. TAG=p3.0 syn/orfs/run.sh chilisocs CLK_PERIOD=3.0.
# ORFS_NAME=<name> names a Docker container (docker kill <name> stops the run).
#
# Engine: Apptainer when ORFS_SIF names an image file of the pinned ORFS
# image and apptainer is on PATH; else Docker. ORFS_ENGINE=docker|apptainer
# forces one. ORFS_APPTAINER_ARGS / ORFS_DOCKER_ARGS: extra options, default
# an 8 GB memory cap ("" for none).
set -euo pipefail

IMAGE=${ORFS_IMAGE:-openroad/orfs:26Q4-71-g9b26ff8ff}
SIF=${ORFS_SIF:-}
engine=${ORFS_ENGINE:-}
if [[ -z $engine ]]; then
  if [[ -n $SIF && -f $SIF ]] && command -v apptainer >/dev/null; then engine=apptainer; else engine=docker; fi
fi
ROOT=$(cd "$(dirname "$0")/../.." && pwd)

spec=${1:?usage: run.sh [platform/]design [make args...]}
shift
case $spec in
  */*) platform=${spec%/*}; design=${spec#*/} ;;
  *)   platform=nangate45;  design=$spec ;;
esac
cfg=syn/orfs/$platform/$design/config.mk
[[ -f $ROOT/$cfg ]] || { echo "run.sh: no $cfg" >&2; exit 1; }

work=$design${TAG:+_$TAG}
name=${ORFS_NAME:-orfs_${work}_$$}

mkdir -p "$ROOT/syn/orfs/out/$work"

if [[ $engine == apptainer ]]; then
  app_args=${ORFS_APPTAINER_ARGS---memory 8000M --memory-swap 8000M}
  # /tmp and $HOME of the container: on disk (Apptainer's default is 64 MB of memory)
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/orfs_${work}_XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
else
  docker_args=${ORFS_DOCKER_ARGS---memory=8000m --memory-swap=8000m}
fi

# orfs [-n <container name>] <bash command> [VAR=value...]: the command in the image, from
# /OpenROAD-flow-scripts, the repository read-only at /soc and syn/orfs/out at /work
orfs() {
  local cname= cmd e a=()
  if [[ $1 == -n ]]; then cname=$2; shift 2; fi
  cmd=$1; shift
  if [[ $engine == apptainer ]]; then
    for e in "$@"; do a+=(--env "$e"); done
    # shellcheck disable=SC2086
    apptainer exec --containall --workdir "$tmp" "${a[@]}" $app_args \
      --bind "$ROOT:/soc:ro" --bind "$ROOT/syn/orfs/out:/work" "$SIF" \
      bash -c "cd /OpenROAD-flow-scripts && $cmd"
  else
    for e in "$@"; do a+=(-e "$e"); done
    [[ -n $cname ]] && a+=(--name "$cname")
    # shellcheck disable=SC2086
    docker run --rm --init "${a[@]}" $docker_args -u "$(id -u):$(id -g)" -e HOME=/tmp \
      -v "$ROOT:/soc:ro" -v "$ROOT/syn/orfs/out:/work" "$IMAGE" bash -c "$cmd"
  fi
}

orfs -n "$name" "source env.sh >/dev/null && cd flow && make DESIGN_CONFIG=/soc/$cfg WORK_HOME=/work/$work $*"
