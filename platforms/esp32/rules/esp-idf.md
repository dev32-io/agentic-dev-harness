---
description: ESP-IDF -- pinned version, idf.py build in CI, versioned partitions, OTA pre-flight checks.
paths: "**/CMakeLists.txt,**/*.c,**/*.cpp,**/*.h"
---

# ESP-IDF

ESP-IDF is Espressif's official framework for ESP32-family
chips. Treating it as an IDE-defined "whatever the dev environment
loaded" toolchain produces builds that work on one laptop and
fail on another. When a rule is unclear, see
`platforms/esp32/docs/esp-idf-details.md`.

## Pin the IDF version in the repo

- An `idf-version.txt` file (or equivalent in the container
  spec) at the repo root names the exact IDF release the project
  targets, e.g. `v5.3.1`.
- The CI container image is derived from that version
  (`espressif/idf:v5.3.1` or a custom image FROM that base).
- Local developer setup follows the same pin -- the README's
  setup section says "install IDF v5.3.1," not "install the
  latest." Drift between contributors is the cause of "builds
  for me, fails for you."

## `idf.py build` in CI -- not an IDE build

- CI runs `idf.py set-target esp32s3` (or the project's target)
  and `idf.py build`. NOT VS Code's Espressif extension, NOT
  Eclipse, NOT a custom CMake wrapper.
- `idf.py` is the supported entry point; everything else is a
  convenience over it. The build reproduces from the same
  command that any contributor runs locally.
- Build artifacts (`.bin`, `.elf`, partition table, bootloader)
  are uploaded as CI artifacts -- those are what flash to a
  device.

## Partition layout is versioned

- A custom `partitions.csv` is checked in next to the project,
  selected via `sdkconfig.defaults`
  (`CONFIG_PARTITION_TABLE_CUSTOM=y`).
- The partition layout is a contract with the bootloader, the
  app, and OTA -- changing it without a coordinated bootloader
  update bricks devices in the field.
- A layout change MUST come with a migration plan documented in
  the commit (and in `docs/decisions/`): how do existing devices
  receive the new layout? Usually: they do not; the change
  ships only to new devices, OR via a multi-step OTA that
  rewrites the table.

## OTA pre-flight checks before flashing

Before applying an OTA, the device verifies:

1. **Firmware signature.** Signed images only;
   `CONFIG_SECURE_BOOT_V2_ENABLED=y` and the signing key is
   provisioned. Unsigned firmware is rejected.
2. **Version skew.** The incoming version is greater than the
   running version (anti-rollback), and the incoming version is
   compatible with the bootloader (a major-version jump may
   require a separate path).
3. **Partition fits.** The image size fits the OTA slot. Refuse
   to start flashing if not.
4. **Power state.** Battery above a configured threshold; if on
   USB power, that is acceptable. Refuse to OTA on critical
   battery.

A failed pre-flight does NOT enter the partial-flash state. The
device stays on the working firmware and reports the failure
reason via whatever telemetry channel the project uses.

## `sdkconfig` is generated; `sdkconfig.defaults` is checked in

- `sdkconfig` (the resolved Kconfig output) is gitignored.
- `sdkconfig.defaults` (the project's overrides) IS checked in.
  That is the source of truth -- every contributor regenerates
  `sdkconfig` from those defaults via `idf.py reconfigure`.
- Per-target overrides go in `sdkconfig.defaults.esp32s3`,
  `sdkconfig.defaults.esp32c3`, etc.

## Why this discipline matters

Embedded code that "compiles" is not the same as embedded code
that runs. Pinning IDF, building via `idf.py`, versioning
partitions, and gating OTA at the device boundary are how a
fleet of devices in the field keeps running. The alternative is
discovering at OTA-rollout time that "the laptop that built v2
had a different IDF."
