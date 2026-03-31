# DebugTools — Jami iOS Testing Harness

`DebugTools` is a local framework embedded into the Ring iOS app and the
notification extension for the sole purpose of test/debug instrumentation. It
is opt-in — activated only when you deliberately select the
**Jami-TestingTools** scheme in Xcode — and is physically absent from any
production (Debug/Release/Distribution) build.

`DebugTools` hosts a tool, `NotificationTesting`, which
validates iOS push notifications end-to-end across the full Jami pipeline:

```
Sender (iOS app)  → ios Notification Extension
```

The harness lets you reproduce push delivery on demand, attach a unique
`trace_id` to every test message, and view a merged timeline of every step
the message took in one place.

---

## TL;DR

```bash
# 1. Push proxy infrastructure

# 2. Log collector
```

In Xcode:

1. Select the **Jami-TestingTools** scheme.
2. Build and run on your sender (Simulator or real iPhone) and receiver
   (real iPhone — APNs does not deliver to Simulators).
3. Open a swarm conversation click debug button. Configur for sender and receiver

---

## Architecture at a glance

```
Ring/
├── Ring.xcodeproj
│   └── xcshareddata/xcschemes/
│       ├── Ring.xcscheme                       ← normal dev/archive scheme
│       └── Jami-TestingTools.xcscheme          ← opt-in test scheme
│
├── DebugTools/                                 ← the framework target
│
├── Ring/                                       ← main app target
└── jamiNotificationExtension/                  ← notification extension target
```

---

## What the Jami-TestingTools scheme activates

The `Jami-TestingTools` scheme builds with the **Debug Testing** build
configuration, which differs from regular `Debug` in exactly one way:

| Setting | `Debug` | `Debug Testing` |
|---|---|---|
| `DEBUG_TOOLS_ENABLED` (Swift compilation condition) | not set | **set** |
| `DEBUG_TOOLS_ENABLED=1` (GCC preprocessor define) | not set | **set** |

That single flag controls everything. Signing, optimizations, debug symbols,
Swift version, pods — all inherited from `Debug`, all identical.

When `DEBUG_TOOLS_ENABLED` is **on**, the framework compiles with its full
content and the host code's inline `#if DEBUG_TOOLS_ENABLED` blocks light up.

**Sender and Receiver** (main app)

- **Debug view**

**Sender** (main app)
- **Periodic sender** — `NotificationTesting.startIntervalSender(...)` drives
  a `DispatchSourceTimer` that calls a host-supplied closure on each tick
  with a freshly generated message:
  ```
  [TRACE:<uuid>] ping <sequence> <ISO8601 timestamp>
  ```
- **One-shot sender** — `NotificationTesting.sendTestMessageNow(...)` fires
  the same kind of message once, independent of the timer. Uses the same
  trace_id mechanism so the event lands in the timeline alongside any
  ongoing periodic traffic.
- **Daemon log forwarding** — the main app already registers libjami's
  `MessageSend` signal in `SystemAdapter.mm`. In test mode, `SystemService`
  auto-enables streaming and forwards every `JAMI_LOG` line into the logger,
  auto-tagged with trace IDs extracted from message bodies.

**Receiver side** (notification extension)
- **Logger calls** throughout `NotificationService` (14 call sites) and
  `AdapterService` — `received`, `streamStarted`, `lineReceived`,
  `decryptedCall`/`decryptedGitMessage`/`decryptedClone`, `eventMessage`,
  `notificationPresented`, `timeout`, `finished`, `daemonLog`.
- **Trace ID correlation** — incoming message bodies are parsed for a
  `[TRACE:<uuid>]` prefix and the trace ID is attached to the extension's
  events, tying sender and receiver timelines together.
- **Daemon log forwarding** — the extension's `Adapter.mm` registers the
  same libjami `MessageSend` callback and routes daemon logs through the
  shared logger.

---
