---
description: FreeRTOS -- documented priorities, deliberate stack sizes, watchdogs enabled, ISR-safe APIs.
paths: "**/*.c,**/*.cpp,**/*.h"
---

# FreeRTOS

ESP-IDF runs on FreeRTOS. Tasks, priorities, and stack sizes are
not "ambient" -- every choice has consequences for jitter,
preemption, and crash modes. When a rule is unclear, see
`platforms/esp32/docs/freertos-details.md`.

## Task priorities are documented in `tasks.md`

- The project owns a `docs/tasks.md` (or similar) priority
  table: every long-lived task is listed with its name,
  priority, stack size, core affinity, and a one-sentence
  description.
- Adding a new task means adding a row to that table. A task
  whose priority is "whatever the example used" is a future
  jitter bug.
- Priority numbers are NOT magic. The table makes the order
  explicit: who preempts whom, and why.

## Stack sizes are deliberate -- no defaults

```c
// FORBIDDEN -- no stack size, copy-pasted "this worked once."
xTaskCreate(my_task, "my_task", 4096, NULL, 5, NULL);
```

- Every `xTaskCreate` call site MUST specify a stack size chosen
  for the task -- not "4096 because every example uses 4096."
- Choose by measuring: run the task under a representative load,
  call `uxTaskGetStackHighWaterMark()`, add headroom (typically
  ~25%), and document the value alongside the priority table.
- A stack overflow in FreeRTOS is silent corruption, then a hard
  fault. The compiler will not help; the measurement is the
  only safety.

## Watchdogs enabled on all tasks

- The Task Watchdog Timer (TWDT) is enabled in `sdkconfig`
  (`CONFIG_ESP_TASK_WDT_INIT=y`) with a sensible timeout (5-10
  seconds typical).
- Every long-lived task either:
  1. Subscribes to the TWDT (`esp_task_wdt_add(NULL)` in its
     setup) and feeds it (`esp_task_wdt_reset()`) at least once
     per cycle, OR
  2. Is short-running by design and explicitly opts out.
- A task that blocks indefinitely without feeding the watchdog
  is a watchdog-reset waiting to happen -- and the reset is the
  correct behavior; the bug is that the task hung.

## ISR-safe APIs only inside ISRs

- Interrupt service routines run in a special context. Most
  FreeRTOS APIs are NOT safe to call from an ISR.
- The `*FromISR` variants are the legal subset: `xQueueSendFromISR`,
  `xSemaphoreGiveFromISR`, `xTaskNotifyFromISR`, etc.
- An ISR that calls a non-ISR API is a CPU panic the first time
  it fires under load. The compiler will not catch this; code
  review must.
- ISRs are SHORT. The pattern is "ISR signals a task; task does
  the work." An ISR that does I/O or floating-point math is the
  wrong shape -- promote the work to a task.

## Inter-task communication -- queues and notifications

- Shared mutable state across tasks goes through a queue, a
  task notification, or a mutex-protected struct -- NOT through
  a global variable read and written ad-hoc.
- Task notifications are the cheapest signal-and-data path:
  one-to-one, no queue allocation.
- Mutexes (`xSemaphoreCreateMutex`) include priority-inheritance
  on ESP-IDF; prefer them over binary semaphores when "ownership
  of a resource" is the concept.

## Core affinity -- pin deliberately on dual-core targets

- On ESP32 and ESP32-S3 (dual-core), use `xTaskCreatePinnedToCore`
  to assign a task to core 0 or core 1 when the choice matters
  (e.g. WiFi stack runs on core 0 by default; UI tasks often
  run on core 1).
- The priority table records the affinity choice alongside the
  priority.

## Why this discipline matters

A FreeRTOS application's failure modes are timing-dependent and
hard to reproduce. The disciplines above -- documented
priorities, measured stacks, watchdog coverage, ISR-safe APIs --
turn "it crashed once last week and we couldn't reproduce it"
from a folklore bug into a diagnosable one with an obvious next
step.
