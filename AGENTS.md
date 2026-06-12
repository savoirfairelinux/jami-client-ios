# AGENTS.md

Jami is a secure, distributed (peer-to-peer) messaging and audio/video calling client for iOS. The protocol is handled by a C++ daemon (the `jami-daemon` submodule) that this Swift/UIKit/SwiftUI app drives through an ObjC++ bridge (`DRingAdapter` and the per-domain adapters in `Ring/Ring/Bridging/`). Minimum deployment target: **iOS 14.5**.

## General rules

- Use the relevant skill or topic file before starting work
- Prefer small, focused changes over large sweeping ones
- For behavior changes, add/update tests first.

## Skills

- Committing changes → [commit](.agents/skills/commit/SKILL.md)

## Topics

- Build/test workflow → [build-test.md](.agents/topics/build-test.md).
- UI / view work → [ui-design.md](.agents/topics/ui-design.md).
- App logic — services, view models, or navigation → [architecture.md](.agents/topics/architecture.md).
