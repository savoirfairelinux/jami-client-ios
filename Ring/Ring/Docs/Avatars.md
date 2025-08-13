## Avatar architecture

This document explains how avatars are produced, stored, cached, and consumed across the app.

### Components and responsibilities

- ProfilesService
  - Source of truth for profile data (name, photo) via database/adapter.
  - Decodes avatar image data and holds the only image cache.
  - Caching policy:
    - Key: SHA256(data) + requested decode size.
    - NSCache stores only decodes whose requested size equals primarySize * 2 (primarySize = 55 pt → 110 pt decode).
    - Small avatars (15/30/40/50/55) all decode to 110 and share a single cached image.
    - Large avatars (e.g., 150 pt → 300 pt decode) are produced on demand and not cached by default.

- MessagesListVM (acts as Avatar/Name store)
  - Provides per-`jamiId` relays used throughout SwiftUI:
    - `avatarRelay(for:) -> BehaviorRelay<Data?>`
    - `nameRelay(for:) -> BehaviorRelay<String>`
  - Fetches profile info via `ProfilesService.getProfile(...)` and updates the relays when photo/name is available.
  - Also supplies small derived images for “last read” and location-sharing overlays by decoding the current data at tiny sizes.

### MessagesListVM deep dive

- Creation and scope
  - Instantiated by `ConversationViewModel` as the SwiftUI model for a conversation screen.
  - It is per-conversation; when `conversation` is set, it re-subscribes to conversation streams.

- Lifecycle and triggers
  - `conversation` didSet → `invalidateAndSetupConversationSubscriptions()` which (re)subscribes to new messages, updates, and reactions.
  - Relays are lazy: `avatarRelay(for:)`/`nameRelay(for:)` create a `BehaviorRelay` on first access and then call `getInformationForContact(id:)` to fetch.
  - `getInformationForContact(id:)`:
    - Resolves the `jamiId` to a URI based on account type (RING/SIP).
    - Subscribes to `ProfilesService.getProfile(uri:, createIfNotexists:, accountId:)`.
    - On each `Profile`, updates the name relay if `alias` is present and updates the avatar relay if `photo` is present.
    - If no alias, it triggers a background `nameService.lookupAddress(...)` and updates the name relay with the result.

- What uses MessagesListVM
  - SwiftUI avatar views: obtain an `AvatarProviderFactory` via `MessagesListVM.makeAvatarFactory()`, then `factory.provider(for:size:)` for a given `jamiId`.
    - Views using this include: message rows, contact message chips, reactions list, conversations lists, calls/conference participants (direct providers).
  - “Last read” indicators: read `avatars[jamiId]` to build tiny 15-pt bubbles for participants of the last-read message.
  - Location sharing UI: reads the contact’s current avatar relay and decodes a small image for overlay.

- Message info bus (MessageInfo)
  - SwiftUI view models post requests through `messageInfoState` to retrieve data.
  - Handled cases:
    - `updateRead(messageId:, message:)` → MessagesListVM updates the `lastRead` avatars map for that message.
    - `updateDisplayname(jamiId:, message:)` → MessagesListVM ensures the name relay is populated (profile or lookup).
  - The previous `updateAvatar` path was removed in favor of using `AvatarProvider` fed by `avatarRelay(for:)`.

- Why keep avatar/name in MessagesListVM
  - Central place tied to the lifetime of the conversation screen; avoids duplicating fetch logic in views.
  - Provides a simple relay interface for both SwiftUI providers and auxiliary UI (last read, location).
  - Future: this can be extracted to a dedicated `AvatarStore` if needed across more screens.

- AvatarProvider and AvatarProviderFactory (SwiftUI)
  - `AvatarProvider` is an `ObservableObject` for a single avatar view: subscribes to avatar data and name streams and exposes a decoded `UIImage?` (or monogram fallback).
  - Decoding size: `decodeSize = max(viewSize * 2, primarySize * 2)` so small views reuse the 110-pt cached decode.
  - `AvatarProviderFactory` caches provider instances per `(jamiId|size)` to:
    - Maintain stable object identity for SwiftUI (avoid flicker, lost updates).
    - Avoid duplicate Rx subscriptions and reduce churn in scrolling lists.
  - The factory caches providers only (lightweight objects) — images are cached centrally by `ProfilesService`.

- AvatarSwiftUIView (SwiftUI view)
  - Renders either the decoded image or a monogram fallback.
  - Monogram color is derived from an MD5 hash of the display text.
  - Monogram font size is proportional to the avatar size (≈ 0.44×, clamped), for consistent letter-to-circle ratio.
  - For non-name fallbacks (e.g., group), an SF Symbol is rendered at the same computed font size.
  - A subtle circular border is drawn to make the monogram edge crisp.

### Data flow at a glance

1) MessagesListVM observes profiles via `ProfilesService.getProfile(...)` and updates:
   - `avatars[jamiId] : BehaviorRelay<Data?>`
   - `names[jamiId] : BehaviorRelay<String>`

2) UI requests a provider:
   - `let provider = avatarProviderFactory.provider(for: jamiId, size: X)`
   - Provider subscribes to the `avatars` and `names` relays.

3) Provider decodes on updates:
   - Requests an image from `ProfilesService.getAvatarFor(data, decodeSize)`.
   - If `decodeSize == 110`, the result is cached and reused across small views.

4) SwiftUI renders `AvatarSwiftUIView(source: provider)`.

### Sizes and caching behavior

- Primary size: 55 pt (AvatarSizing.primarySize).
- Decode size: `max(viewSize * 2, 110 pt)`.
  - 15/30/40/50/55 pt views decode to 110 pt and hit the cache.
  - 150 pt views decode to 300 pt and are not cached by default.
- Memory (approx., 32-bit RGBA):
  - 110 pt @3x ≈ 330×330×4 bytes ≈ 0.43 MB per image.
  - 300 pt @3x ≈ 900×900×4 bytes ≈ 3.2 MB per image.
  - `ProfilesService` cache limit is 8 MB; many small avatars reuse the same cached decode.

### When to add more caches

Only consider caching big decodes (e.g., 300 pt) if you frequently display many large avatars and observe repeated decodes or jank. If you do:
- Add a 300-pt caching tier in `ProfilesService.getAvatarFor`.
- Consider increasing `avatarsCache.totalCostLimit` accordingly.

### Where avatars are used

- Conversation list and message rows (SwiftUI): via `AvatarProviderFactory` → `AvatarProvider` → `AvatarSwiftUIView`.
- Reactions list (SwiftUI): via the same provider path.
- Conference/call participants (SwiftUI): via static builders that construct `AvatarProvider` directly from participant view models.
- Last-read indicators and location sharing overlays: read current `avatars[jamiId]` relay and decode small images on demand.

### Monogram fallback details

- Display text: prefers `profileName`, else `registeredName`, else empty.
- If display text is non-empty and not a SHA1 and not a group:
  - Show first grapheme letter.
  - Font size ≈ 0.44 × avatar size, clamped to 8–50.
- Else show SF Symbol (`person.fill` or `person.2.fill`) at the same computed size.
- Background color is selected from a palette using an MD5-based index; a thin darker circle stroke sharpens the boundary.

### Threading considerations

- Providers currently observe on the main thread and then decode. If you see jank on cache misses, consider moving decode work off main and delivering the result on main.

### Rationale for provider caching

- Stable `@ObservedObject` identity for SwiftUI avoids flicker and repeated binding churn.
- Single subscription per `(jamiId, size)`, even if multiple views show the same avatar.
- Providers are lightweight; image memory is shared via the central cache.

### Adding new usages

- SwiftUI view in a conversation context:
  - Access the factory from the environment, then request a provider: `factory.provider(for:size:)`.
  - Render with `AvatarSwiftUIView(source: provider)`.

- Outside conversation contexts:
  - Use `AvatarProvider.provider(profileService:size:avatar:displayName:isGroup:)` to build a provider with custom streams.

### Future improvements

- Extract a dedicated `AvatarStore` (wrapping the current relays) to decouple from `MessagesListVM`.
- Optionally add a cache tier for large decodes.
- Offload decode to a background scheduler and marshal results to the main thread for rendering.


