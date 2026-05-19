# Clean Code — Details & Examples

This file expands `base/rules/clean-code.md`. The rule defines the
bar; this doc shows worked examples for splitting an over-sized
file, extracting a magic number, pulling an inline prompt out to
its own `.md` file, and the anti-pattern of bundling unrelated
helpers into a single dumping-ground.

## Early returns

Flatten nested conditionals with early returns. The goal is one
visual column for the happy path.

### Good

```text
function validateToken(token):
  if token is empty:        return error "empty"
  if not startsWith("v4."): return error "bad prefix"
  claims = decrypt(token)
  if isExpired(claims):     return error "expired"
  return ok(claims)
```

### Bad — pyramid

```text
function validateToken(token):
  if token is not empty:
    if startsWith("v4."):
      claims = decrypt(token)
      if not isExpired(claims):
        return ok(claims)
      else:
        return error "expired"
    else:
      return error "bad prefix"
  else:
    return error "empty"
```

The Bad version has the same logic, but the happy path is buried
four levels deep. Six months from now an agent reading it has to
mentally pop the stack to figure out what success looks like.

## Worked example: splitting a 450-LOC file by responsibility

### Before — `payment.ts` (450 LOC)

```text
payment.ts
├── parseCard(input)                    // 40 LOC — input parsing
├── validateCardNumber(card)            // 25 LOC — input parsing
├── validateExpiry(card)                // 20 LOC — input parsing
├── chargeCard(card, amount)            // 60 LOC — provider calls
├── refundCharge(chargeId)              // 45 LOC — provider calls
├── retryWithBackoff(fn)                // 30 LOC — provider calls
├── recordChargeInLedger(charge)        // 50 LOC — persistence
├── recordRefundInLedger(refund)        // 40 LOC — persistence
├── reconcileDailyLedger()              // 80 LOC — persistence
└── helpers, types                      // 60 LOC
```

The file does THREE things: input parsing, provider calls, and
persistence. The line-count alarm fired at 250; the responsibility
audit confirms the smoke.

### After — three files of ~150 LOC each

```text
payment-input.ts (~110 LOC)
├── parseCard
├── validateCardNumber
└── validateExpiry

payment-provider.ts (~150 LOC)
├── chargeCard
├── refundCharge
└── retryWithBackoff

payment-ledger.ts (~190 LOC)   // still allowed; under 300
├── recordChargeInLedger
├── recordRefundInLedger
└── reconcileDailyLedger
```

Each file's name fits the three-word rule. Each can be reviewed in
isolation. An agent rewriting the provider integration does not
need to load 450 lines to make a 60-line change.

### Reasoning

The split is by AXIS of change, not by line count. Input parsing
changes when the card form changes. Provider calls change when
the upstream API changes. Ledger calls change when the schema
changes. These rates are independent, so the files are
independent.

## Worked example: extracting a magic number

### Before

```text
// in session-manager.ts
if (now - session.createdAt > 3600 * 1000) {
  session.expire();
}
```

A reader has to mentally compute `3600 * 1000 = 3_600_000 ms = 1
hour` and then guess whether "1 hour" is policy or accident.

### After

```text
// at top of file, or in a shared constants module
const SECONDS_PER_HOUR = 3600;
const MS_PER_SECOND = 1000;
const SESSION_TTL_MS = SECONDS_PER_HOUR * MS_PER_SECOND;

// in session-manager.ts
if (now - session.createdAt > SESSION_TTL_MS) {
  session.expire();
}
```

### Reasoning

`SESSION_TTL_MS` is a policy decision; `3600 * 1000` is a riddle.
When the policy changes from 1 hour to 30 minutes, the diff is
`SESSION_TTL_MS = 30 * MS_PER_SECOND * SECONDS_PER_MINUTE` — one
line, one named change, easy to review. The previous form would
have asked the reviewer to recompute and re-verify the units.

The exempt literals (`0`, `1`, `-1`) are universal idioms (empty,
unit, sentinel) and do not benefit from naming.

## Worked example: extracting an inline prompt to its own `.md`

### Before — `agent-handler.ts` (380 LOC)

```text
// agent-handler.ts (excerpt — 200-line system prompt inlined)
const SYSTEM_PROMPT = `You are a careful agent operating on behalf
of a user. You may call tools when appropriate. When you call a
tool, you MUST...
[... 198 more lines of carefully-tuned prose ...]
`;

export async function handleTurn(input) {
  const reply = await model.chat({
    system: SYSTEM_PROMPT,
    messages: [...input.history, input.message],
  });
  return reply;
}
```

The file is 380 LOC. ~200 of those are prose, not logic. Code
review of `handleTurn` requires scrolling past prose. A prompt
edit looks like a code change in diffs. The file's responsibility
("handle a turn") is buried under "be the home for the system
prompt."

### After — `agent-handler.ts` (~50 LOC) + `prompts/agent-system.md`

```text
// agent-handler.ts
import { readFile } from "fs/promises";
import { join } from "path";

const PROMPT_PATH = join(__dirname, "../prompts/agent-system.md");
let cachedPrompt: string | null = null;

async function getSystemPrompt(): Promise<string> {
  if (cachedPrompt === null) {
    cachedPrompt = await readFile(PROMPT_PATH, "utf-8");
  }
  return cachedPrompt;
}

export async function handleTurn(input) {
  const system = await getSystemPrompt();
  const reply = await model.chat({
    system,
    messages: [...input.history, input.message],
  });
  return reply;
}
```

```text
prompts/agent-system.md
────────────────────────
You are a careful agent operating on behalf of a user. You may call
tools when appropriate. When you call a tool, you MUST...
[... 198 more lines ...]
```

### Reasoning

The code file is now ~50 LOC of actual logic. A prompt edit lives
in a `.md` file, so it diffs cleanly as prose. Operators can swap
prompts without rebuilding code (e.g. by overriding the file path
or mounting an override directory). Reviewers reviewing logic do
not have to scroll past 200 lines of prose; reviewers reviewing
the prompt do not have to read TypeScript.

The same pattern applies to persona docs, agent instructions,
long output templates, and any other prose-shaped content.

## Anti-pattern: the "utils" dumping ground

A file named `audio-utils.ts` accumulates whatever audio-adjacent
helpers a contributor needs that day. After six months it looks
like this:

```text
audio-utils.ts (340 LOC)
├── playSample(buffer)                  // playback
├── pauseAll()                          // playback
├── crossfade(a, b, ms)                 // playback
├── encodePCM(samples)                  // encoding
├── decodeOpus(bytes)                   // encoding
├── resample(buffer, fromHz, toHz)      // encoding
├── listInputDevices()                  // device detection
├── listOutputDevices()                 // device detection
└── getDefaultDevice(kind)              // device detection
```

The name "utils" admits the file has no coherent identity. The
file has three concerns (playback, encoding, device detection)
fused together. Any consumer that needs playback also loads the
encoding code. Anyone editing one helper sees the full 340 lines.

### Fix — split by axis

```text
audio-playback.ts (~110 LOC)
├── playSample
├── pauseAll
└── crossfade

audio-encoding.ts (~130 LOC)
├── encodePCM
├── decodeOpus
└── resample

audio-devices.ts (~80 LOC)
├── listInputDevices
├── listOutputDevices
└── getDefaultDevice
```

Each file's name fits the three-word rule. Each consumer imports
only the axis it needs. Each file can grow independently to its
own 300-line cap without dragging the others.

### General lesson

`*-utils.*` and `*-helpers.*` filenames are smoke. They almost
always mean "I had three things and didn't want to think about
where to put them." Think about where to put them. The name of
the file is a unit test for whether the file has a single
responsibility.

## Naming patterns

### Booleans as questions

```text
isReady               // not: ready
hasError              // not: error
canTransition         // not: transition
shouldRetry           // not: retry
isInFlight            // not: inFlight (ambiguous — value? state?)
```

### Functions as actions

```text
createSession         // not: session()
validateToken         // not: token()
parseFrame            // not: frame() or frameParse()
recordCharge          // not: chargeRecorder()
```

### Avoid empty nouns

`data`, `info`, `manager`, `handler`, `util`, `helper`, `service`,
`processor`, `engine`, `module` as bare names describe everything
and nothing. They almost always mean "I have not yet named this."

```text
// Bad
const data = await fetch(url);
class UserManager { ... }
function handleStuff(info) { ... }

// Good
const userRecord = await fetch(url);
class UserDirectory { ... }   // it directs lookups
function applyPendingEdits(edits) { ... }
```

If you genuinely cannot find a more specific name, the underlying
concept may not be carved out cleanly yet. Split or refactor
until the names fall out.
