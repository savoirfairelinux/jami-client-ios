# UI Design

- **Colors:** use the Jami asset catalog or color extensions — never hardcode literals or hex. New colors go in the catalog with light + dark variants.
- **Fonts:** default to Dynamic Type text styles; use a fixed size only when the design genuinely requires it.
- **Strings:** never hardcode user-facing text — add new strings to `Ring/Ring/Resources/en.lproj/Localizable.strings`.
- **Accessibility:** every meaningful or interactive element needs a VoiceOver label and correct traits; hide decorative elements from VoiceOver; interactive elements need a ≥44×44pt target.
- **RTL:** Jami ships RTL languages — use `.leading`/`.trailing`
