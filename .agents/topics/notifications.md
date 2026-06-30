# Notifications, Push & Connectivity

Read before any push / notification / peer-connection / sync work.

## How connectivity works (DHT proxy)

Jami is peer-to-peer over a **DHT**: peers publish and look up
**values** at keys derived from identities. Most values are *connection requests* used to
establish a connection; some are *device presence announcements*. An always-on client keeps its
own DHT node and **listens** on its keys for them.

iOS can't hold a live connection in the background, so it delegates to a **DHT proxy server**:

- The device registers a **push token** and asks the proxy to **listen** on its keys.
- When a peer publishes a value, the proxy's listen fires and it pushes the device.
- A push carries only an **encrypted connection request** — routing, not content. The device
  wakes, decrypts it, and opens a **peer-to-peer connection to the sender** to fetch the real
  content. The request comes via the proxy; the content comes from the peer.
- A subscription is time-limited: before it expires the proxy sends a **resubscribe** push so the
  device renews; otherwise pushes stop.

## Push types

- **Value notification** — connection requests waiting at a key.
- **Resubscribe** — a renewal prompt (no values) telling the device to refresh its subscription.

## Push routing

- **Notification extension** — new connection-request values and resubscribes.
- **App directly** — device presence announcements and expired values.

## Core invariant: one active process at a time

"Account active" = the **account** is registered/online on the DHT. The app, notification
extension, and share extension can each run the daemon, but **only one target may have an account
active at a time**. They coordinate over cross-process (Darwin) notifications: the app deactivates
accounts on background so an extension can take over, and reactivates on foreground.

The app and extensions all reach the daemon through target-specific adapters, but use it
differently:

- **Notification extension** — lazy: loads nothing at startup; for a push, loads the account and
  only the needed conversation, then stops quickly (its budget is tight — a few seconds and little
  memory).
- **Share extension** — starts a short-lived daemon for the compose/send flow; lists
  accounts/conversations, then activates the selected account only when sending.
- **App** — full client: loads all accounts/conversations at startup and owns normal foreground
  state.

## Message flow (extension)

1. A push wakes the extension.
2. If main app is active → bail; the foreground app handles it.
3. If not → stream the connection-request values from the proxy and decrypt each → classify as
   message / call / clone / unknown.
4. **Message / clone** → load the account on demand, register it on the DHT, and load **only** the
   named conversation; the daemon then connects to the **sender** and git-fetches the new commits
   to sync it → present a **local notification**.

## Call flow

The notification extension does not own media or the final call lifecycle. It decrypts the value,
stops its daemon if needed, and uses CallKit's VoIP-push handoff API to wake the app.

1. Extension decrypts the value → a call.
2. Extension **stops its daemon** and reports a **VoIP push** to the app.
3. The app receives the VoIP push and **reports the call to CallKit immediately**.
4. The app then activates the account (its daemon registers) and forwards the push, so the
   **daemon negotiates the actual call** (ICE/media). The user answers via CallKit → media connects.

## App ↔ extension handoff

- App **foreground** → owns the account (active); the extension defers to it.
- App **background** → deactivates the account so the extension can take over (skipped if there's
  an active call).
- While suspended, the extension syncs into the **shared on-disk store** and records each changed
  conversation in a shared list.
- App **foreground** → reactivates the account and **reloads from disk** the conversations/messages
  the extension changed, because the app's in-memory state went stale while suspended. The
  pending-call (VoIP) path does the same.

## Shared state

- An **App Group** container gives the app and extensions a shared on-disk directory (account keys,
  message-dedup state, proxy cache).
- A shared user-defaults suite carries the stashed-push queue, the badge count, and the
  changed-conversation list.
- **Cross-process (Darwin) notifications** coordinate the three targets (app, notification
  extension, share extension).
