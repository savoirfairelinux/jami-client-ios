/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

/// A place the user can send call audio to.
enum AudioOutput: Hashable, Sendable {
    case iPhone
    case speaker
    case wired
    case bluetooth(id: String, name: String)

    var isHeadset: Bool {
        switch self {
        case .iPhone, .speaker: return false
        case .wired, .bluetooth: return true
        }
    }
}

/// An audio session port reduced to what call routing needs.
struct AudioPort: Equatable, Sendable {
    enum Kind: Sendable {
        case receiver, speaker, wired, bluetooth, other
    }

    let kind: Kind
    let id: String
    let name: String
}

/// The audio session as seen at one moment: the ports in use and the
/// inputs it could switch to.
struct AudioRouteSnapshot: Equatable, Sendable {
    var outputs: [AudioPort]
    var availableInputs: [AudioPort]
    /// False on devices without an earpiece (iPad).
    var hasReceiver: Bool
}

enum AudioOutputs {

    /// Outputs to offer, in display order: iPhone, Speaker, headsets.
    /// iOS can't play through the earpiece while wired headphones are
    /// plugged in, so iPhone is left out then.
    static func available(in snapshot: AudioRouteSnapshot) -> [AudioOutput] {
        let ports = snapshot.outputs + snapshot.availableInputs
        var headsets: [AudioOutput] = []
        for port in ports {
            guard let output = headset(for: port),
                  !headsets.contains(where: { same(output, $0) }) else { continue }
            headsets.append(output)
        }
        var result: [AudioOutput] = []
        if snapshot.hasReceiver && !headsets.contains(.wired) {
            result.append(.iPhone)
        }
        result.append(.speaker)
        return result + headsets
    }

    /// The output audio is playing through, matched to `available`.
    static func current(in snapshot: AudioRouteSnapshot) -> AudioOutput? {
        guard let port = snapshot.outputs.first else { return nil }
        switch port.kind {
        case .receiver: return .iPhone
        case .speaker: return .speaker
        case .wired, .bluetooth:
            guard let output = headset(for: port) else { return nil }
            return available(in: snapshot).first { same(output, $0) } ?? output
        case .other: return nil
        }
    }

    /// Whether `output` is where the call would go without the user's
    /// choice: a headset when one is connected, otherwise the earpiece
    /// for audio calls and the speaker for video calls or on iPad.
    static func isDefault(_ output: AudioOutput,
                          among available: [AudioOutput],
                          callHasVideo: Bool) -> Bool {
        if output.isHeadset { return true }
        if available.contains(where: \.isHeadset) { return false }
        let builtIn: AudioOutput = callHasVideo || !available.contains(.iPhone)
            ? .speaker : .iPhone
        return output == builtIn
    }

    /// With exactly two outputs a tap switches to the other one; with
    /// more, the user picks from the list.
    static func toggleTarget(from current: AudioOutput?,
                             among available: [AudioOutput]) -> AudioOutput? {
        guard available.count == 2 else { return nil }
        return available.first { $0 != current }
    }

    private static func headset(for port: AudioPort) -> AudioOutput? {
        switch port.kind {
        case .wired: return .wired
        case .bluetooth: return .bluetooth(id: port.id, name: port.name)
        case .receiver, .speaker, .other: return nil
        }
    }

    /// The same device can report a different port id as an output and
    /// as an input, so Bluetooth ports also match by name.
    private static func same(_ lhs: AudioOutput, _ rhs: AudioOutput) -> Bool {
        switch (lhs, rhs) {
        case let (.bluetooth(lhsID, lhsName), .bluetooth(rhsID, rhsName)):
            return lhsID == rhsID || lhsName == rhsName
        default:
            return lhs == rhs
        }
    }
}
