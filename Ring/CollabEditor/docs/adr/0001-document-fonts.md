# ADR 0001: Fonts in collaborative documents

## Context

A run of text in a collaborative document can carry a font and a size, through two inline attributes shared by all clients:

- `font`: an id naming a font;
- `size`: a size in points (1–400).

The font id is part of the shared document format. Every client has to agree on the list of ids, or a font chosen on one client is drawn in the default font on the others.

The editor reconciles whole documents. A client that doesn't know an attribute must therefore leave it untouched when it edits, or its first keystroke removes that attribute from the whole document, for everyone.

## Decision drivers

1. **Same document format on every client:** the font ids must match everywhere.
2. **App size:** the cost is paid by every user, including those who never open a collaborative document.
3. **Visual fidelity:** a chosen font should look the same, or at least similar, on every client.
4. **License:** bundled fonts come with license obligations; some reserve their names.
5. **Simplicity:** little code and few build steps to maintain.

## Considered options

### Option 1: bundle a set of specific fonts (TTF)

Ship the font files, e.g. 10 open-licensed fonts × 4 styles (Regular, Bold, Italic, Bold Italic), and serve them to the editor.

- ✅ Identical typeface on every client that ships the same files.
- ✅ Simple: the files are copied as they are.
- ❌ Large size cost: about 12 MB for 10 fonts, roughly +10% of the app.
  - iOS unpacks the app at install, so the fonts sit on the phone uncompressed.
  - Android keeps assets compressed inside the APK, so there the cost is about half.
- ❌ Each font added later increases the size again.

### Option 2: bundle the same fonts, compressed

Compress the font files at build time (e.g. LZMA/XZ) and decompress one in memory when the editor asks for it.

- ✅ Identical typeface: the decompressed file is the original, byte for byte.
- ✅ No license question, because the font itself is never modified.
- ✅ Memory use after loading is the same as Option 1. Only the styles a document shows are decompressed, and never to disk.
- ❌ Still a real size cost: about 4.9 MB for the same 10 fonts, roughly +4%.
- ❌ More moving parts: a build step, decompression code, and a short CPU cost the first time a font is shown.

### Option 3: generic font families, the platform chooses

The document stores a **category**, not a specific font:

| Id | Menu label | What it means |
|---|---|---|
| `sans-serif` | Sans Serif | plain letters without "feet" |
| `serif` | Serif | letters with "feet", like in books |
| `monospace` | Monospace | every letter the same width |
| `cursive` | Cursive | handwriting style |

The editor draws each one with the plain CSS keyword (`font-family: serif`), and each platform picks its own font for that category.

- ✅ No size cost, no license, no build step.
- ✅ The simplest code.
- ❌ The style is the same everywhere, but not necessarily the exact typeface: "serif" may look a little different on Android and on iOS.
- ❌ Fewer choices: 4 instead of a list of specific fonts.

## Decision

**Option 3, with plain category keywords.** A document stores a generic family, and each platform draws it in the font it chooses for that family.

In addition, each client changes only the attributes it knows when it edits a document. Anything written by a newer client stays in place.

### Why

- It keeps one simple, shared format that every client can support without shipping anything (driver 1).
- It removes the size cost entirely (driver 2).
- It raises no license or build questions (drivers 4–5).
- It gives up an identical typeface across platforms (driver 3). The style is preserved (serif stays serif), and that is enough for a document edited together.

## Consequences

- **Every client must use the same four ids.** A client still offering other ids draws them in the default font elsewhere. Nothing is lost, because ids a client doesn't know are kept.
- **The actual font depends on each platform's web engine.** For example, WebKit on iOS currently draws sans-serif in Helvetica and serif in Times. If a platform lacks its usual font, it still draws a font of the same category rather than failing.
- **New attributes can be added safely later.** Older clients keep attributes they don't know instead of removing them.
