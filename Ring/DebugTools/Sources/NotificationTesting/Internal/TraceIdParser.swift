/*
 * Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation

#if DEBUG_TOOLS_ENABLED

/// Extracts correlation payloads from test messages for end-to-end notification tracing.
///
/// Supported embeds:
/// - `[TRACE:{uuid}]` — legacy; substring may appear inside a longer line.
/// - `[TP:{w3c-traceparent}]` — full W3C traceparent (`version-traceid-spanid-flags`),
///   used by `IntervalSender` so foreground and extension spans share the sender trace.
enum TraceIdParser {
    /// Extract the trace_id from a message body, if present. Returns `nil`
    /// if the message does not contain a `[TRACE:...]` substring.
    static func extract(from content: String) -> String? {
        substringBetween(prefix: "[TRACE:", in: content)
    }

    /// Extract a W3C traceparent from `[TP:...]` in the body, if present.
    static func extractTraceparent(from content: String) -> String? {
        substringBetween(prefix: "[TP:", in: content)
    }

    private static func substringBetween(prefix: String, in content: String) -> String? {
        guard let start = content.range(of: prefix) else { return nil }
        guard let end = content[start.upperBound...].firstIndex(of: "]") else { return nil }
        guard start.upperBound < end else { return nil }
        let inner = String(content[start.upperBound..<end])
        let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#endif
