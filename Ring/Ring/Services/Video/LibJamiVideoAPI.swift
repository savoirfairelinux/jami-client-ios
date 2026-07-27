/*
 * Copyright (C) 2018-2026 Savoir-faire Linux Inc.
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
import CoreVideo

protocol LibJamiVideoAPI: AnyObject {
    // Sinks (incoming decoded video)
    func registerSink(_ sinkId: SinkId, width: Int, height: Int, hasListeners: Bool)
    func removeSink(_ sinkId: SinkId)
    func setHasListeners(_ hasListeners: Bool, sinkId: SinkId)
    func renderSize(_ sinkId: SinkId) -> CGSize

    // Outgoing frames / capture devices
    func writeOutgoingFrame(_ buffer: CVImageBuffer, angle: Int, videoInputId: String)
    func addVideoDevice(name: String, info: [String: Any])
    func setDefaultDevice(_ name: String)
    func defaultDevice() -> String
    func openVideoInput(_ path: String)
    func closeVideoInput(_ path: String)

    // Hardware acceleration
    func setDecodingAccelerated(_ state: Bool)
    func setEncodingAccelerated(_ state: Bool)
    func decodingAccelerated() -> Bool
    func encodingAccelerated() -> Bool

    // Local recorder (media messages / future call recording)
    func startLocalRecording(videoInputId: String, path: String) -> String?
    func stopLocalRecording(path: String)

    // Media player
    func createMediaPlayer(path: String) -> String?
    func pausePlayer(playerId: String, pause: Bool)
    func closePlayer(playerId: String)
    func mutePlayerAudio(playerId: String, mute: Bool)
    func playerSeek(to time: Int, playerId: String)
    func playerPosition(playerId: String) -> Int64
}

final class LibJamiVideoClient: LibJamiVideoAPI {

    private let adapter: VideoAdapter

    init(adapter: VideoAdapter) {
        self.adapter = adapter
    }

    func registerSink(_ sinkId: SinkId, width: Int, height: Int, hasListeners: Bool) {
        adapter.registerSinkTarget(withSinkId: sinkId.raw, withWidth: width,
                                   withHeight: height, hasListeners: hasListeners)
    }

    func removeSink(_ sinkId: SinkId) {
        adapter.removeSinkTarget(withSinkId: sinkId.raw)
    }

    func setHasListeners(_ hasListeners: Bool, sinkId: SinkId) {
        adapter.setHasListeners(hasListeners, forSinkId: sinkId.raw)
    }

    func renderSize(_ sinkId: SinkId) -> CGSize {
        return adapter.getRenderSize(sinkId.raw)
    }

    func writeOutgoingFrame(_ buffer: CVImageBuffer, angle: Int, videoInputId: String) {
        adapter.writeOutgoingFrame(with: buffer, angle: Int32(angle),
                                   videoInputId: videoInputId)
    }

    func addVideoDevice(name: String, info: [String: Any]) {
        adapter.addVideoDevice(withName: name, withDevInfo: info)
    }

    func setDefaultDevice(_ name: String) {
        adapter.setDefaultDevice(name)
    }

    func defaultDevice() -> String {
        return adapter.getDefaultDevice() ?? ""
    }

    func openVideoInput(_ path: String) {
        adapter.openVideoInput(path)
    }

    func closeVideoInput(_ path: String) {
        adapter.closeVideoInput(path)
    }

    func setDecodingAccelerated(_ state: Bool) {
        adapter.setDecodingAccelerated(state)
    }

    func setEncodingAccelerated(_ state: Bool) {
        adapter.setEncodingAccelerated(state)
    }

    func decodingAccelerated() -> Bool {
        return adapter.getDecodingAccelerated()
    }

    func encodingAccelerated() -> Bool {
        return adapter.getEncodingAccelerated()
    }

    func startLocalRecording(videoInputId: String, path: String) -> String? {
        let name = adapter.startLocalRecording(videoInputId, path: path)
        guard let name = name, !name.isEmpty else { return nil }
        return name
    }

    func stopLocalRecording(path: String) {
        adapter.stopLocalRecording(path)
    }

    func createMediaPlayer(path: String) -> String? {
        let playerId = adapter.createMediaPlayer(path)
        guard let playerId = playerId, !playerId.isEmpty else { return nil }
        return playerId
    }

    func pausePlayer(playerId: String, pause: Bool) {
        adapter.pausePlayer(playerId, pause: pause)
    }

    func closePlayer(playerId: String) {
        adapter.closePlayer(playerId)
    }

    func mutePlayerAudio(playerId: String, mute: Bool) {
        adapter.mutePlayerAudio(playerId, mute: mute)
    }

    func playerSeek(to time: Int, playerId: String) {
        adapter.playerSeek(toTime: Int32(time), playerId: playerId)
    }

    func playerPosition(playerId: String) -> Int64 {
        return adapter.getPlayerPosition(playerId)
    }
}
