# ESP-IDF -- Details & Examples

This file expands `platforms/esp32/rules/esp-idf.md`.

## Repo layout for a typical IDF project

```text
my-firmware/
    idf-version.txt           # "v5.3.1"
    sdkconfig.defaults        # project-wide Kconfig overrides
    sdkconfig.defaults.esp32s3
    partitions.csv            # custom partition table
    CMakeLists.txt
    main/
        CMakeLists.txt
        app_main.c
    components/
        net/
            CMakeLists.txt
            net.c
            include/net.h
    .github/workflows/ci.yml
    docs/
        decisions/
            0003-partition-layout-v2.md
```

`sdkconfig` itself is in `.gitignore` -- it's the generated
output of `defaults + target + Kconfig`, not the source.

## Example `partitions.csv` -- dual-app OTA layout

```csv
# Name,    Type, SubType,  Offset,   Size,    Flags
nvs,      data, nvs,      0x9000,   0x6000,
otadata,  data, ota,      0xf000,   0x2000,
phy_init, data, phy,      0x11000,  0x1000,
factory,  app,  factory,  ,         1M,
ota_0,    app,  ota_0,    ,         1500K,
ota_1,    app,  ota_1,    ,         1500K,
storage,  data, spiffs,   ,         512K,
```

The two `ota_*` slots are the "current" and "next" firmware
during an OTA; `otadata` records which is active.

Changing this layout in an existing fleet is the highest-risk
change in embedded code. Any commit that modifies
`partitions.csv` MUST link to an ADR describing the migration
strategy:

```markdown
# 0003 -- Partition layout v2

Status: ACCEPTED
Date:   2025-04-10

## Context
We need 256K more for the model assets in `storage`. Reducing
`ota_*` from 1500K to 1400K and bumping `storage` to 768K.

## Migration
- New devices: shipped with the v2 layout.
- Existing devices: v1 layout retained; new model is fetched
  on-demand to RAM instead of installed to flash. A future v3
  layout will unify the two.

## Rollback
- v2 layout is forward-compatible: a v1 bootloader can boot a
  v2-compiled app provided the app stays within v1's `ota_*`
  size envelope. We will verify this in QA before rollout.

## Owner
@firmware-team
```

## A minimal `sdkconfig.defaults`

```text
# Project name and target.
CONFIG_IDF_TARGET="esp32s3"

# Partition table -- custom.
CONFIG_PARTITION_TABLE_CUSTOM=y
CONFIG_PARTITION_TABLE_CUSTOM_FILENAME="partitions.csv"

# Secure boot v2 -- signed firmware only.
CONFIG_SECURE_BOOT_V2_ENABLED=y
CONFIG_SECURE_BOOT_SIGNING_KEY="keys/secure_boot_signing_key.pem"

# Anti-rollback.
CONFIG_APP_ANTI_ROLLBACK=y

# Watchdog defaults.
CONFIG_ESP_TASK_WDT_INIT=y
CONFIG_ESP_TASK_WDT_TIMEOUT_S=10
CONFIG_ESP_TASK_WDT_CHECK_IDLE_TASK_CPU0=y
CONFIG_ESP_TASK_WDT_CHECK_IDLE_TASK_CPU1=y

# Console -- USB Serial JTAG on s3.
CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG=y
```

Per-target overrides go in `sdkconfig.defaults.esp32s3` if they
diverge.

## A CI workflow

```yaml
# .github/workflows/ci.yml
name: firmware-ci
on: [push, pull_request]

jobs:
    build:
        runs-on: ubuntu-latest
        container:
            image: espressif/idf:v5.3.1
        steps:
            - uses: actions/checkout@v4
              with:
                  submodules: recursive

            - name: configure target
              run: idf.py set-target esp32s3

            - name: build
              run: idf.py build

            - name: artifacts
              uses: actions/upload-artifact@v4
              with:
                  name: firmware
                  path: |
                      build/*.bin
                      build/*.elf
                      build/partition_table/partition-table.bin
                      build/bootloader/bootloader.bin
```

The build runs in the same container any contributor can pull
locally. Artifact paths are exactly what `esptool.py` will flash
to a device.

## OTA pre-flight -- the code shape

```c
typedef enum {
    OTA_PREFLIGHT_OK,
    OTA_PREFLIGHT_SIGNATURE_INVALID,
    OTA_PREFLIGHT_VERSION_SKEW,
    OTA_PREFLIGHT_PARTITION_TOO_SMALL,
    OTA_PREFLIGHT_LOW_BATTERY,
} ota_preflight_result_t;

ota_preflight_result_t ota_preflight(const ota_descriptor_t *desc) {
    if (!secure_boot_verify_signature(desc)) {
        return OTA_PREFLIGHT_SIGNATURE_INVALID;
    }
    if (desc->version <= current_app_version() || desc->version > MAX_KNOWN_VERSION) {
        return OTA_PREFLIGHT_VERSION_SKEW;
    }
    const esp_partition_t *target = esp_ota_get_next_update_partition(NULL);
    if (target == NULL || desc->image_size > target->size) {
        return OTA_PREFLIGHT_PARTITION_TOO_SMALL;
    }
    if (power_source() == POWER_BATTERY && battery_percent() < MIN_OTA_BATTERY_PCT) {
        return OTA_PREFLIGHT_LOW_BATTERY;
    }
    return OTA_PREFLIGHT_OK;
}
```

The flash itself does NOT begin until `ota_preflight` returns
`OK`. A failed pre-flight is reported via telemetry; the device
keeps running its current firmware.

## Secure boot keys -- where they live

Signing keys are NOT in the repo. They live in:

- A secrets manager for the production signing pipeline.
- A test-only key checked in under `keys/test_signing_key.pem`
  is acceptable for development builds; production firmware
  uses a different key, never the dev key.

The CI workflow injects the real key for release builds via a
GitHub Actions secret.

## When the IDF pin bumps

Bumping the pin is a real change:

1. Update `idf-version.txt`.
2. Update the CI container image tag.
3. Run `idf.py reconfigure` -- new Kconfig defaults may have
   appeared; review and adopt or override.
4. Build + flash to a real device; run the OTA smoke test.
5. Commit, PR, code review by an embedded peer.

The change is its own commit ("build: bump IDF to v5.4.0") so
the diff is reviewable in isolation from feature work.

(PRs welcome to deepen this platform.)
