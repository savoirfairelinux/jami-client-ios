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

// MARK: - Protocols

protocol MediaManaging {
    func getVideoCodec(call: CallModel) -> String?
    func audioMuted(call callId: String, mute: Bool)
    func videoMuted(call callId: String, mute: Bool)
    func callMediaUpdated(call: CallModel)
    func updateCallMediaIfNeeded(call: CallModel)
    func handleRemoteRecordingChanged(callId: String, record: Bool)
    func handleCallPlacedOnHold(callId: String, holding: Bool)
    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]])
    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]])
}


final class MediaManagementService: MediaManaging {
    // MARK: - Dependencies

    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let callUpdates: ReplaySubject<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>

    private let queueHelper: ThreadSafeQueueHelper

    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        callUpdates: ReplaySubject<CallModel>,
        responseStream: PublishSubject<ServiceEvent>,
        queueHelper: ThreadSafeQueueHelper
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.callUpdates = callUpdates
        self.queueHelper = queueHelper
        self.responseStream = responseStream
    }

    func getVideoCodec(call: CallModel) -> String? {
        let callDetails = callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId)
        return callDetails?[CallDetailKey.videoCodec.rawValue]
    }


    func audioMuted(call callId: String, mute: Bool) {
        guard let call = self.getCall(with: callId) else { return }
        queueHelper.barrierAsync {

            call.audioMuted = mute
            
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            self.notifyCallUpdated(call)
        }
        self.notifyMediaStateChanged(call: call, mediaType: "audio", muted: mute)
    }

    private func notifyMediaStateChanged(call: CallModel, mediaType: String, muted: Bool) {
        var event = ServiceEvent(withEventType: .mediaStateChanged)
        event.addEventInput(.peerUri, value: call.participantUri)
        event.addEventInput(.callUUID, value: call.callUUID.uuidString)
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.callId, value: call.callId)
        event.addEventInput(.mediaType, value: mediaType)
        event.addEventInput(.mediaState, value: muted ? "muted" : "unmuted")
        self.responseStream.onNext(event)
    }

    func videoMuted(call callId: String, mute: Bool) {
        guard let call = self.getCall(with: callId) else { return }
        queueHelper.barrierAsync {

            call.videoMuted = mute
            
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            self.notifyCallUpdated(call)
        }
        notifyMediaStateChanged(call: call, mediaType: "video", muted: mute)
    }

    func callMediaUpdated(call: CallModel) {
        queueHelper.barrierAsync {
            guard let call = self.getCall(with: call.callId) else { return }
            var mediaList = call.mediaList

            if mediaList.isEmpty {
                guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
                mediaList = attributes
            }

            if let callDictionary = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId) {
                call.update(withDictionary: callDictionary, withMedia: mediaList)

                var updatedCalls = self.calls.value
                updatedCalls[call.callId] = call
                self.calls.accept(updatedCalls)
                
                self.notifyCallUpdated(call)
            }
        }
    }

    func updateCallMediaIfNeeded(call: CallModel) {
        queueHelper.barrierAsync {
            guard let call = self.getCall(with: call.callId) else { return }
            var mediaList = call.mediaList

            if mediaList.isEmpty {
                guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
                mediaList = attributes
                
                // Only update if media list has changed
                if !self.compareMediaLists(call.mediaList, mediaList) {
                    call.mediaList = mediaList

                    var updatedCalls = self.calls.value
                    updatedCalls[call.callId] = call
                    self.calls.accept(updatedCalls)
                    
                    self.notifyCallUpdated(call)
                }
            }
        }
    }

    func handleRemoteRecordingChanged(callId: String, record: Bool) {
        queueHelper.barrierAsync {
            guard let call = self.getCall(with: callId) else { return }

            call.callRecorded = record
            
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            self.notifyCallUpdated(call)
        }
    }

    func handleCallPlacedOnHold(callId: String, holding: Bool) {
        queueHelper.barrierAsync {
            guard let call = self.getCall(with: callId) else { return }

            call.peerHolding = holding
            
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            self.notifyCallUpdated(call)
        }
    }

    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]]) {
        queueHelper.barrierAsync {
            guard let call = self.getCall(with: callId),
                  let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: call.accountId) else { return }

            call.update(withDictionary: callDictionary, withMedia: media)
            
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            self.notifyCallUpdated(call)
        }
    }

    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]]) {
        guard let call = self.getCall(with: callId) else { return }

        let answerMedias = self.processMediaChangeRequest(call: call, requestedMedia: media)
        self.callsAdapter.answerMediaChangeResquest(callId, accountId: accountId, withMedia: answerMedias)
        
        queueHelper.barrierAsync {
            guard let updatedCall = self.getCall(with: callId) else { return }

            updatedCall.mediaList = answerMedias
            
            var updatedCalls = self.calls.value
            updatedCalls[callId] = updatedCall
            self.calls.accept(updatedCalls)
            
            self.notifyCallUpdated(updatedCall)
        }
    }

    // MARK: - Private Helpers

    private func getCall(with callId: String) -> CallModel? {
        return calls.value[callId]
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

    private func processMediaChangeRequest(call: CallModel, requestedMedia: [[String: String]]) -> [[String: String]] {
        let mediaLabels = call.mediaList.compactMap { media -> (String, [String: String])? in
            guard let label = media[MediaAttributeKey.label.rawValue] else { return nil }
            return (label, media)
        }
        let currentMediaMap: [String: [String: String]] = Dictionary(uniqueKeysWithValues: mediaLabels)

        return requestedMedia.map { media in
            var newMedia = media

            if let label = media[MediaAttributeKey.label.rawValue],
               let existingMedia = currentMediaMap[label] {
                newMedia[MediaAttributeKey.muted.rawValue] = existingMedia[MediaAttributeKey.muted.rawValue]
                newMedia[MediaAttributeKey.enabled.rawValue] = existingMedia[MediaAttributeKey.enabled.rawValue]
            } else {
                newMedia[MediaAttributeKey.muted.rawValue] = "true"
                newMedia[MediaAttributeKey.enabled.rawValue] = "true"
            }

            return newMedia
        }
    }
}

final class MediaAttributeFactory {
    static func createAudioMedia() -> [String: String] {
        [
            MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
            MediaAttributeKey.label.rawValue: "audio_0",
            MediaAttributeKey.enabled.rawValue: "true",
            MediaAttributeKey.muted.rawValue: "false"
        ]
    }

    static func createVideoMedia(source: String) -> [String: String] {
        [
            MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue,
            MediaAttributeKey.label.rawValue: "video_0",
            MediaAttributeKey.source.rawValue: source,
            MediaAttributeKey.enabled.rawValue: "true",
            MediaAttributeKey.muted.rawValue: "false"
        ]
    }

    static func createDefaultMediaList(isAudioOnly: Bool, videoSource: String) -> [[String: String]] {
        var mediaList = [createAudioMedia()]

        if !isAudioOnly {
            mediaList.append(createVideoMedia(source: videoSource))
        }

        return mediaList
    }
}
