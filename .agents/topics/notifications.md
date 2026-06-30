# Notifications, Push & Connectivity

Read before any push / notification / peer-connection / sync work.

## How connectivity works (DHT proxy)

Jami is peer-to-peer over a DHT: peers publish and look up values at keys derived
from identities. To establish a connection, peers exchange connection-request
values through the DHT.

iOS can't hold a live connection in the background, so it delegates to a DHT proxy
server:

- The device registers a push token and asks the proxy to listen on its keys.
- When a peer publishes a value, the proxy's listen fires and it pushes the device.
- A push carries only an encrypted value, not content.
- A subscription is time-limited: before it expires the proxy sends a resubscribe
  push so the device renews.

## Push types

- Value notification — DHT values are waiting at a key. The push contains the key and value IDs.
- Resubscribe — a `timeout` push telling the device to renew its DHT proxy subscription.
- Expired value — a value-expiration notification, marked with `exp`.

## Push routing

- Notification extension — high-priority pushes: connection-request values and resubscribes.
- App directly — low-priority pushes: device-presence announcements and expired values.

## Core invariant: one active process at a time

Between the app, notification extension, and share extension, only one target may
have an account active at a time.

## App ↔ extension handoff

- App foreground → owns the account (active); the extension defers to it.
- App background → deactivates the account so the extension can take over.

## Message flow (extension)

1. A push wakes the extension.
2. If the main app is active → bail; the foreground app handles it.
3. If not → stream the connection-request values from the proxy and decrypt each → classify as
   message / call / clone / unknown.
4. Message / clone → load the account on demand, register, and load only the
   named conversation, connect to the sender and git-fetch the new commits.

## Call flow (extension → app)

1. Extension decrypts the value → a call.
2. Extension stops its daemon and reports a VoIP push to the app.
3. The app receives the VoIP push and reports the call to CallKit immediately.
4. The app then activates the account, loads conversations, and connects to the sender.
