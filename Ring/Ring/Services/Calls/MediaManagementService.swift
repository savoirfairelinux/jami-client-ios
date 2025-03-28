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

/*
 * MediaManagementService Thread Safety Contract:
 *
 * This service uses ThreadSafeQueueHelper to ensure thread safety when dealing with call media:
 *
 * 1. Read operations:
 *    - Direct access to BehaviorRelay.value is used for thread-safe reads
 *    - No synchronization needed for reading from BehaviorRelay
 *
 * 2. Write operations:
 *    - Use queueHelper.barrierAsync { ... } when modifying shared state
 *    - Call updates are published after modifications are complete
 *
 * 3. Low-contention operations:
 *    - For operations that only read state before calling the adapter,
 *      direct access to BehaviorRelay.value is used
 */

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
    
    // Thread safety
    private let queueHelper: ThreadSafeQueueHelper

    /// Initialize the media management service
    /// - Parameters:
    ///   - callsAdapter: The adapter for interacting with the native call service
    ///   - calls: The behavior relay containing all calls
    ///   - callUpdates: The subject for publishing call updates
    ///   - queueHelper: The thread-safe queue helper
    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        callUpdates: ReplaySubject<CallModel>,
        queueHelper: ThreadSafeQueueHelper
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.callUpdates = callUpdates
        self.queueHelper = queueHelper
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
        queueHelper.barrierAsync {
            // Read-modify-write operation requires thread safety
            guard var call = self.getCall(with: callId) else { return }

            call.audioMuted = mute
            
            // Update the calls relay
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            // Notify observers
            self.notifyCallUpdated(call)
        }
    }

    /// Handles video muting state changes
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - mute: Whether video is muted
    func videoMuted(call callId: String, mute: Bool) {
        queueHelper.barrierAsync {
            // Read-modify-write operation requires thread safety
            guard var call = self.getCall(with: callId) else { return }

            call.videoMuted = mute
            
            // Update the calls relay
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            // Notify observers
            self.notifyCallUpdated(call)
        }
    }

    /// Updates a call's media information
    /// - Parameter call: The call to update
    func callMediaUpdated(call: CallModel) {
        queueHelper.barrierAsync {
            // Make a copy of the call to modify
            guard var callCopy = self.getCall(with: call.callId) else { return }
            var mediaList = callCopy.mediaList

            // Fetch media list if not available
            if mediaList.isEmpty {
                guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
                mediaList = attributes
            }

            // Update call with latest details
            if let callDictionary = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId) {
                callCopy.update(withDictionary: callDictionary, withMedia: mediaList)
                
                // Update the calls relay
                var updatedCalls = self.calls.value
                updatedCalls[call.callId] = callCopy
                self.calls.accept(updatedCalls)
                
                // Notify observers
                self.notifyCallUpdated(callCopy)
            }
        }
    }

    /// Updates a call's media if needed
    /// - Parameter call: The call to update
    func updateCallMediaIfNeeded(call: CallModel) {
        queueHelper.barrierAsync {
            // Make a copy of the call to modify
            guard var callCopy = self.getCall(with: call.callId) else { return }
            var mediaList = callCopy.mediaList

            if mediaList.isEmpty {
                guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
                mediaList = attributes
                
                // Only update if media list has changed
                if !self.compareMediaLists(callCopy.mediaList, mediaList) {
                    callCopy.mediaList = mediaList
                    
                    // Update the calls relay
                    var updatedCalls = self.calls.value
                    updatedCalls[call.callId] = callCopy
                    self.calls.accept(updatedCalls)
                    
                    // Notify observers
                    self.notifyCallUpdated(callCopy)
                }
            }
        }
    }

    /// Handles remote recording state changes
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - record: Whether recording is active
    func handleRemoteRecordingChanged(callId: String, record: Bool) {
        queueHelper.barrierAsync {
            // Read-modify-write operation requires thread safety
            guard var call = self.getCall(with: callId) else { return }

            call.callRecorded = record
            
            // Update the calls relay
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            // Notify observers
            self.notifyCallUpdated(call)
        }
    }

    /// Handles when a call is placed on hold
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - holding: Whether the call is on hold
    func handleCallPlacedOnHold(callId: String, holding: Bool) {
        queueHelper.barrierAsync {
            // Read-modify-write operation requires thread safety
            guard var call = self.getCall(with: callId) else { return }

            call.peerHolding = holding
            
            // Update the calls relay
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            // Notify observers
            self.notifyCallUpdated(call)
        }
    }

    /// Handles media negotiation status updates
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - event: The event type
    ///   - media: The media information
    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]]) {
        queueHelper.barrierAsync {
            // Read-modify-write operation requires thread safety
            guard var call = self.getCall(with: callId),
                  let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: call.accountId) else { return }

            call.update(withDictionary: callDictionary, withMedia: media)
            
            // Update the calls relay
            var updatedCalls = self.calls.value
            updatedCalls[callId] = call
            self.calls.accept(updatedCalls)
            
            // Notify observers
            self.notifyCallUpdated(call)
        }
    }

    /// Handles media change requests
    /// - Parameters:
    ///   - accountId: The account ID
    ///   - callId: The call ID
    ///   - media: The requested media information
    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]]) {
        // Reading call is thread-safe with BehaviorRelay
        guard let call = self.getCall(with: callId) else { return }

        let answerMedias = self.processMediaChangeRequest(call: call, requestedMedia: media)
        self.callsAdapter.answerMediaChangeResquest(callId, accountId: accountId, withMedia: answerMedias)
        
        // Update call media after accepting the change
        queueHelper.barrierAsync {
            guard var updatedCall = self.getCall(with: callId) else { return }
            
            updatedCall.mediaList = answerMedias
            
            // Update the calls relay
            var updatedCalls = self.calls.value
            updatedCalls[callId] = updatedCall
            self.calls.accept(updatedCalls)
            
            // Notify observers
            self.notifyCallUpdated(updatedCall)
        }
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
    
    /// Compare two media lists to determine if they're equal
    /// - Parameters:
    ///   - list1: First media list
    ///   - list2: Second media list
    /// - Returns: True if they are equal, false otherwise
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
