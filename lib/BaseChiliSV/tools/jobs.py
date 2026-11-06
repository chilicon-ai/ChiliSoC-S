# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Job hook: the tools pass each heavy command (synthesis, simulator build,
simulation) through job() before running it.

Here it returns the command unchanged. To run them under a scheduler (a
batch queue, a core / memory budget), return the command wrapped in its
submit command, e.g. ["srun", "-c", "4", "--", *cmd].
"""

from __future__ import annotations


def job(kind: str, cmd: list[str], cores: int | None = None, quiet: bool = False,
        name: str | None = None) -> list[str]:
    """cmd as it runs. kind: synth, build, sim or other; cores: the cores it
    needs; quiet: nothing may be added to its stderr; name: a stable label."""
    return cmd


def runner() -> str | None:
    """The command a tool would resubmit itself through as one job (None: run here)."""
    return None
