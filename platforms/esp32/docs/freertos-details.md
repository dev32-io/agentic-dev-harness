# FreeRTOS -- Details & Examples

This file expands `platforms/esp32/rules/freertos.md`.

## A canonical `docs/tasks.md` table

```markdown
# Task table

| Name              | Priority | Stack | Core | HWM   | Notes                            |
| ----------------- | -------- | ----- | ---- | ----- | -------------------------------- |
| wifi_handler      | 23       | 4096  | 0    | ~2.8K | reserved by IDF; do not preempt  |
| net_supervisor    | 12       | 4096  | 0    | ~2.4K | reconnect, DHCP, NTP             |
| sensor_sampler    | 10       | 3072  | 1    | ~1.8K | 100 Hz IMU sampling              |
| ui_renderer       | 8        | 4096  | 1    | ~3.1K | LVGL render loop                 |
| ota_supervisor    | 6        | 8192  | 1    | ~5.4K | only active during OTA           |
| telemetry_uploader| 4        | 4096  | 0    | ~2.6K | batches and uploads logs         |
| idle              | 0        | --    | 0/1  | --    | system                           |
```

Each row carries a high-water mark (`uxTaskGetStackHighWaterMark`)
measured under representative load. The stack column was chosen
by measuring HWM and adding headroom -- not by copy-paste.

Adding `bluetooth_handler` to the firmware means adding its row
to this table BEFORE merging. The table is the priority spec.

## A correct `xTaskCreate` call site

```c
#define SENSOR_SAMPLER_STACK_BYTES   3072
#define SENSOR_SAMPLER_PRIORITY      10
#define SENSOR_SAMPLER_CORE          1

static TaskHandle_t s_sensor_task = NULL;

void start_sensor_sampler(void) {
    BaseType_t r = xTaskCreatePinnedToCore(
        sensor_task,
        "sensor_sampler",
        SENSOR_SAMPLER_STACK_BYTES,
        NULL,
        SENSOR_SAMPLER_PRIORITY,
        &s_sensor_task,
        SENSOR_SAMPLER_CORE);
    if (r != pdPASS) {
        ESP_LOGE(TAG, "failed to create sensor_sampler");
        abort();   // unrecoverable; better to reset than silently miss
    }
}

static void sensor_task(void *arg) {
    esp_task_wdt_add(NULL);                 // subscribe to TWDT

    const TickType_t period = pdMS_TO_TICKS(10);    // 100 Hz
    TickType_t last = xTaskGetTickCount();
    for (;;) {
        sample_imu_once();
        esp_task_wdt_reset();               // feed the watchdog
        vTaskDelayUntil(&last, period);
    }
}
```

Properties:

- The stack size is a named constant; reviewer can find it.
- The priority is a named constant; matches the table.
- Core affinity is explicit.
- Task subscribes to TWDT and feeds it on every cycle.
- `vTaskDelayUntil` gives a periodic (not "delay since I woke
  up") schedule, which is what you want for sampling.

## Watchdog -- short-running tasks opt out explicitly

```c
static void one_shot_init_task(void *arg) {
    // Not adding to TWDT; this task ends within ~50 ms.
    do_initialization();
    vTaskDelete(NULL);
}
```

A comment names the choice. Without it, the next maintainer
assumes someone forgot.

## ISR -- the canonical shape

```c
static void IRAM_ATTR button_isr_handler(void *arg) {
    BaseType_t higher_woke = pdFALSE;
    uint32_t event = BUTTON_PRESSED;

    // ONLY *FromISR APIs in this context.
    xQueueSendFromISR(s_button_queue, &event, &higher_woke);

    if (higher_woke == pdTRUE) {
        portYIELD_FROM_ISR();
    }
}
```

```c
// FORBIDDEN -- non-ISR API from an ISR. First time this fires under load:
//   "Guru Meditation Error: ... InstrFetchProhibited"
static void IRAM_ATTR bad_isr_handler(void *arg) {
    xQueueSend(s_q, &event, 0);          // WRONG
    ESP_LOGI(TAG, "pressed");            // WRONG (logging is not ISR-safe)
    do_floating_point_math();            // also problematic on some chips
}
```

The ISR is `IRAM_ATTR` (lives in IRAM, callable when flash
cache is suspended), it is short, it only signals a task, and
it uses `portYIELD_FROM_ISR` to switch immediately if the
notification woke a higher-priority task.

The actual work happens in the task that consumes the queue:

```c
static void button_task(void *arg) {
    uint32_t event;
    for (;;) {
        if (xQueueReceive(s_button_queue, &event, portMAX_DELAY) == pdTRUE) {
            ESP_LOGI(TAG, "button event %u", (unsigned)event);
            handle_button_event(event);
        }
    }
}
```

## Task notifications -- the cheap signal path

For one-to-one signaling (one notifier, one notified), use task
notifications -- they avoid the queue allocation:

```c
// Notifier (e.g. an ISR or another task).
xTaskNotifyFromISR(s_consumer_task, 0x01, eSetBits, NULL);

// Consumer.
for (;;) {
    uint32_t bits = 0;
    xTaskNotifyWait(0, ULONG_MAX, &bits, portMAX_DELAY);
    if (bits & 0x01) handle_event_a();
    if (bits & 0x02) handle_event_b();
}
```

Faster than a queue, and the bitfield carries up to 32
distinguishable events.

## Mutex with priority inheritance

```c
static SemaphoreHandle_t s_state_mutex;

void init_state(void) {
    s_state_mutex = xSemaphoreCreateMutex();
    configASSERT(s_state_mutex != NULL);
}

void update_state(const new_state_t *next) {
    if (xSemaphoreTake(s_state_mutex, pdMS_TO_TICKS(50)) == pdTRUE) {
        memcpy(&g_state, next, sizeof(g_state));
        xSemaphoreGive(s_state_mutex);
    } else {
        ESP_LOGW(TAG, "state mutex contention");
    }
}
```

`xSemaphoreCreateMutex()` is the priority-inheriting form; a
lower-priority task holding it gets a temporary priority bump
while a higher-priority task is waiting. Use this whenever the
"ownership of a resource" concept fits.

## Measuring stack high-water marks

```c
void log_stack_marks(void) {
    char buf[256];
    UBaseType_t n = uxTaskGetNumberOfTasks();
    TaskStatus_t *snap = pvPortMalloc(n * sizeof(TaskStatus_t));
    n = uxTaskGetSystemState(snap, n, NULL);
    for (UBaseType_t i = 0; i < n; ++i) {
        ESP_LOGI(TAG, "%s: hwm=%u",
            snap[i].pcTaskName,
            (unsigned)snap[i].usStackHighWaterMark);
    }
    vPortFree(snap);
}
```

Call this periodically during stress testing; record the
worst-case numbers; size the stack to that + headroom.

## Core affinity decision

- Network stack tasks (WiFi, BT, lwIP): core 0 by default.
- CPU-bound application tasks: core 1 to keep them out of the
  network stack's way.
- Anything that interacts heavily with WiFi (e.g. throughput
  benchmarks): core 0, alongside it, to avoid cross-core
  cache misses.

The choice is per-task and documented in the priority table.

(PRs welcome to deepen this platform.)
