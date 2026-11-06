# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# west build -t run (and twister, simulation "custom") runs the image on the
# Verilator model of the SoC (sim/zephyr/sim.py)
set(SUPPORTED_EMU_PLATFORMS custom)

add_custom_target(run_custom
  COMMAND ${PYTHON_EXECUTABLE} ${BOARD_DIR}/../../../../../sim/zephyr/sim.py
          ${APPLICATION_BINARY_DIR}/zephyr/zephyr.elf
  WORKING_DIRECTORY ${APPLICATION_BINARY_DIR}
  DEPENDS ${logical_target_for_zephyr_elf}
  USES_TERMINAL
  )
