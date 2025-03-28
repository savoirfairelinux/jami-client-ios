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

// MARK: - Enums

/// Represents the type of media in a call
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

// MARK: - Service Implementation

/// Service responsible for managing media aspects of calls
final class MediaManagementService: MediaManaging {
    // MARK: - Dependencies

    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let callUpdates: ReplaySubject<CallModel>
    private let callsQueue: DispatchQueue

    /// Initialize the media management service
    /// - Parameters:
    ///   - callsAdapter: The adapter for interacting with the native call service
    ///   - calls: The behavior relay containing all calls
    ///   - callUpdates: The subject for publishing call updates
    ///   - callsQueue: The shared dispatch queue for thread-safe call operations
    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        callUpdates: ReplaySubject<CallModel>,
        callsQueue: DispatchQueue
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.callUpdates = callUpdates
        self.callsQueue = callsQueue
    }

    /// Get the video codec for a call
    /// - Parameter call: The call to get the video codec for
    /// - Returns: The video codec if available, nil otherwise
    func getVideoCodec(call: CallModel) -> String? {
        let callDetails = callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId)
        return callDetails?[CallDetailKey.videoCodec.rawValue]
    }

    /// Handles audio muting state changes
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - mute: Whether audio is muted
    func audioMuted(call callId: String, mute: Bool) {
        // Need queue because we're modifying a call property
        callsQueue.async(flags: .barrier) {
            guard let call = self.getCall(with: callId) else { return }

            call.audioMuted = mute
            self.notifyCallUpdated(call)
        }
    }

    /// Handles video muting state changes
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - mute: Whether video is muted
    func videoMuted(call callId: String, mute: Bool) {
        // Need queue because we're modifying a call property
        callsQueue.async(flags: .barrier) {
            guard let call = self.getCall(with: callId) else { return }

            call.videoMuted = mute
            self.notifyCallUpdated(call)
        }
    }

    /// Updates a call's media information
    /// - Parameter call: The call to update
    func callMediaUpdated(call: CallModel) {
        // Need queue because we're modifying call properties
        callsQueue.async(flags: .barrier) {
            var mediaList = call.mediaList

            // Fetch media list if not available
            if mediaList.isEmpty {
                guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
                call.update(withDictionary: [:], withMedia: attributes)
                mediaList = call.mediaList
            }

            //TODO: need to update callDetails?

            // Update call with latest details
            if let callDictionary = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId) {
                call.update(withDictionary: callDictionary, withMedia: mediaList)
                self.notifyCallUpdated(call)
            }
        }
    }

    /// Updates a call's media if needed
    /// - Parameter call: The call to update
    func updateCallMediaIfNeeded(call: CallModel) {
        // Need queue because we're modifying call properties
        callsQueue.async(flags: .barrier) {
            var mediaList = call.mediaList

            if mediaList.isEmpty {
                guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
                call.update(withDictionary: [:], withMedia: attributes)
                mediaList = call.mediaList
            }

            call.mediaList = mediaList
        }
    }

    /// Handles remote recording state changes
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - record: Whether recording is active
    func handleRemoteRecordingChanged(callId: String, record: Bool) {
        // Need queue because we're modifying a call property
        callsQueue.async(flags: .barrier) {
            guard let call = self.getCall(with: callId) else { return }

            call.callRecorded = record
            self.notifyCallUpdated(call)
        }
    }

    /// Handles when a call is placed on hold
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - holding: Whether the call is on hold
    func handleCallPlacedOnHold(callId: String, holding: Bool) {
        // Need queue because we're modifying a call property
        callsQueue.async(flags: .barrier) {
            guard let call = self.getCall(with: callId) else { return }

            call.peerHolding = holding
            self.notifyCallUpdated(call)
        }
    }

    /// Handles media negotiation status updates
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - event: The event type
    ///   - media: The media information
    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]]) {
        // Need queue because we're modifying call properties
        callsQueue.async(flags: .barrier) {
            //TODO: handle event
            guard let call = self.getCall(with: callId),
                  let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: call.accountId) else { return }

            call.update(withDictionary: callDictionary, withMedia: media)
            self.notifyCallUpdated(call)
        }
    }

    /// Handles media change requests
    /// - Parameters:
    ///   - accountId: The account ID
    ///   - callId: The call ID
    ///   - media: The requested media information
    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]]) {
        // Don't need a barrier here since we're only reading the call object
        // and call adapter operations don't require queue protection
        guard let call = self.getCall(with: callId) else { return }

        let answerMedias = self.processMediaChangeRequest(call: call, requestedMedia: media)
        self.callsAdapter.answerMediaChangeResquest(callId, accountId: accountId, withMedia: answerMedias)
    }

    // MARK: - Private Helpers

    /// Gets a call by ID
    /// - Parameter callId: The ID of the call
    /// - Returns: The call if found, nil otherwise
    private func getCall(with callId: String) -> CallModel? {
        // Reading from BehaviorRelay is thread-safe
        return calls.value[callId]
    }

    /// Notifies that a call has been updated
    /// - Parameter call: The updated call
    private func notifyCallUpdated(_ call: CallModel) {
        callUpdates.onNext(call)
    }

    /// Processes a media change request
    /// - Parameters:
    ///   - call: The call to process the request for
    ///   - requestedMedia: The requested media information
    /// - Returns: The processed media information
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

// MARK: - Media Attribute Factory

/// Factory for creating media attributes
final class MediaAttributeFactory {
    /// Creates audio media attributes
    /// - Returns: The audio media attributes
    static func createAudioMedia() -> [String: String] {
        [
            MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
            MediaAttributeKey.label.rawValue: "audio_0",
            MediaAttributeKey.enabled.rawValue: "true",
            MediaAttributeKey.muted.rawValue: "false"
        ]
    }

    /// Creates video media attributes
    /// - Parameter source: The video source
    /// - Returns: The video media attributes
    static func createVideoMedia(source: String) -> [String: String] {
        [
            MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue,
            MediaAttributeKey.label.rawValue: "video_0",
            MediaAttributeKey.source.rawValue: source,
            MediaAttributeKey.enabled.rawValue: "true",
            MediaAttributeKey.muted.rawValue: "false"
        ]
    }

    /// Creates a default media list
    /// - Parameters:
    ///   - isAudioOnly: Whether the call is audio-only
    ///   - videoSource: The video source
    /// - Returns: The default media list
    static func createDefaultMediaList(isAudioOnly: Bool, videoSource: String) -> [[String: String]] {
        var mediaList = [createAudioMedia()]

        if !isAudioOnly {
            mediaList.append(createVideoMedia(source: videoSource))
        }

        return mediaList
    }
}
