/*
 *  Copyright (C) 2017-2025 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import RxRelay
import RxSwift

enum MediaType: String, CustomStringConvertible {
    case audio = "MEDIA_TYPE_AUDIO"
    case video = "MEDIA_TYPE_VIDEO"

    var description: String {
        return self.rawValue
    }
}

final class MediaManagementService {

    private let callsAdapter: CallsAdapter
    private let calls: SynchronizedRelay<[String: CallModel]>
    private let callUpdates: ReplaySubject<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>

    init(
        callsAdapter: CallsAdapter,
        calls: SynchronizedRelay<[String: CallModel]>,
        callUpdates: ReplaySubject<CallModel>,
        responseStream: PublishSubject<ServiceEvent>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.callUpdates = callUpdates
        self.responseStream = responseStream
    }

    func getVideoCodec(call: CallModel) -> String? {
        let callDetails = callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId)
        return callDetails?[CallDetailKey.videoCodec.rawValue]
    }

    func audioMuted(call callId: String, mute: Bool) async {
        guard let call = self.getCall(with: callId) else { return }

        call.audioMuted = mute
        self.updateCall(call)
    }

    func videoMuted(call callId: String, mute: Bool) async {
        guard let call = self.getCall(with: callId) else { return }

        call.videoMuted = mute
        self.updateCall(call)
    }

    func callMediaUpdated(call: CallModel) async {
        guard let call = self.getCall(with: call.callId) else { return }
        var mediaList = call.mediaList

        if mediaList.isEmpty {
            guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
            mediaList = attributes
        }

        if let callDictionary = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId) {
            call.update(withDictionary: callDictionary, withMedia: mediaList)
            self.updateCall(call)
        }
    }

    func updateCallMediaIfNeeded(call: CallModel) async {
        guard let call = self.getCall(with: call.callId) else { return }
        var mediaList = call.mediaList

        if mediaList.isEmpty {
            guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
            mediaList = attributes

            // Only update if media list has changed
            if !self.compareMediaLists(call.mediaList, mediaList) {
                call.mediaList = mediaList
                self.updateCall(call)
            }
        }
    }

    func handleRemoteRecordingChanged(callId: String, record: Bool) async {
        guard let call = self.getCall(with: callId) else { return }

        call.callRecorded = record
        self.updateCall(call)
    }

    func handleCallPlacedOnHold(callId: String, holding: Bool) async {
        guard let call = self.getCall(with: callId) else { return }

        call.peerHolding = holding
        self.updateCall(call)
    }

    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]]) async {
        guard let call = self.getCall(with: callId),
              let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: call.accountId) else { return }

        call.update(withDictionary: callDictionary, withMedia: media)
        self.updateCall(call)
    }

    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]]) async {
        guard let call = self.getCall(with: callId) else { return }

        let answerMedias = self.processMediaChangeRequest(call: call, requestedMedia: media)
        self.callsAdapter.answerMediaChangeResquest(callId, accountId: accountId, withMedia: answerMedias)

        guard let updatedCall = self.getCall(with: callId) else { return }

        updatedCall.mediaList = answerMedias
        self.updateCall(updatedCall)
    }

    func processMediaChangeRequest(call: CallModel, requestedMedia: [[String: String]]) -> [[String: String]] {
        var answerMedias = [[String: String]]()

        for media in requestedMedia {
            var answerMedia = media

            // Keep existing values for muted and enabled states if this is an existing media type
            if let mediaType = media[MediaAttributeKey.mediaType.rawValue],
               let mediaLabel = media[MediaAttributeKey.label.rawValue],
               let existingMedia = call.mediaList.first(where: { $0[MediaAttributeKey.label.rawValue] == mediaLabel && $0[MediaAttributeKey.mediaType.rawValue] == mediaType }) {

                answerMedia[MediaAttributeKey.muted.rawValue] = existingMedia[MediaAttributeKey.muted.rawValue] ?? "false"
                answerMedia[MediaAttributeKey.enabled.rawValue] = existingMedia[MediaAttributeKey.enabled.rawValue] ?? "true"
            } else {
                // For new media types, set defaults
                if media[MediaAttributeKey.mediaType.rawValue] == MediaAttributeValue.video.rawValue {
                    answerMedia[MediaAttributeKey.muted.rawValue] = "true"
                } else {
                    answerMedia[MediaAttributeKey.muted.rawValue] = "false"
                }

                answerMedia[MediaAttributeKey.enabled.rawValue] = "true"
            }

            answerMedias.append(answerMedia)
        }

        return answerMedias
    }

    private func getCall(with callId: String) -> CallModel? {
        return calls.get()[callId]
    }

    private func updateCall(_ call: CallModel, notify: Bool = true) {
        self.calls.update { calls in
            calls[call.callId] = call
        }
        if notify {
            self.notifyCallUpdated(call)
        }
    }

    private func notifyCallUpdated(_ call: CallModel) {
        callUpdates.onNext(call)
    }

    private func compareMediaLists(_ list1: [[String: String]], _ list2: [[String: String]]) -> Bool {
        guard list1.count == list2.count else { return false }

        for (index, media1) in list1.enumerated() {
            let media2 = list2[index]
            if media1.count != media2.count { return false }

            for (key, value) in media1 {
                if media2[key] != value { return false }
            }
        }

        return true
    }
}

final class MediaAttributeFactory {
    static func createAudioMedia() -> [String: String] {
        [
            MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
            MediaAttributeKey.label.rawValue: "audio_0",
            MediaAttributeKey.source.rawValue: "",
            MediaAttributeKey.enabled.rawValue: "true",
            MediaAttributeKey.muted.rawValue: "false"
        ]
    }

    static func createVideoMedia(source: String, muted: Bool = false) -> [String: String] {
        [
            MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue,
            MediaAttributeKey.label.rawValue: "video_0",
            MediaAttributeKey.source.rawValue: muted ? "" : source,
            MediaAttributeKey.enabled.rawValue: "true",
            MediaAttributeKey.muted.rawValue: muted.toString()
        ]
    }

    static func createCompleteMediaList(isVideoMuted: Bool, videoSource: String) -> [[String: String]] {
        var mediaList = [createAudioMedia()]

        mediaList.append(createVideoMedia(source: videoSource, muted: isVideoMuted))

        return mediaList
    }

    static func createDefaultMediaList(isAudioOnly: Bool, videoSource: String) -> [[String: String]] {
        var mediaList = [createAudioMedia()]

        if !isAudioOnly {
            mediaList.append(createVideoMedia(source: videoSource))
        }

        return mediaList
    }
}
