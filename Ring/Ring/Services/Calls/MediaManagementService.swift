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

final class MediaManagementService: MediaManaging {
    // MARK: - Dependencies

    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let currentCallsEvents: ReplaySubject<CallModel>

    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        currentCallsEvents: ReplaySubject<CallModel>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.currentCallsEvents = currentCallsEvents
    }

    func getVideoCodec(call: CallModel) -> String? {
        let callDetails = callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId)
        return callDetails?[CallDetailKey.videoCodec.rawValue]
    }

    func audioMuted(call callId: String, mute: Bool) {
        guard let call = getCall(with: callId) else { return }

        call.audioMuted = mute
        notifyCallUpdated(call)
    }

    func videoMuted(call callId: String, mute: Bool) {
        guard let call = getCall(with: callId) else { return }

        call.videoMuted = mute
        notifyCallUpdated(call)
    }

    func callMediaUpdated(call: CallModel) {
        var mediaList = call.mediaList

        // Fetch media list if not available
        if mediaList.isEmpty {
            guard let attributes = callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
            call.update(withDictionary: [:], withMedia: attributes)
            mediaList = call.mediaList
        }

        // Update call with latest details
        if let callDictionary = callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId) {
            call.update(withDictionary: callDictionary, withMedia: mediaList)
            notifyCallUpdated(call)
        }
    }

    func updateCallMediaIfNeeded(call: CallModel) {
        var mediaList = call.mediaList

        if mediaList.isEmpty {
            guard let attributes = callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
            call.update(withDictionary: [:], withMedia: attributes)
            mediaList = call.mediaList
        }

        call.mediaList = mediaList
    }

    func handleRemoteRecordingChanged(callId: String, record: Bool) {
        guard let call = getCall(with: callId) else { return }

        call.callRecorded = record
        notifyCallUpdated(call)
    }

    func handleCallPlacedOnHold(callId: String, holding: Bool) {
        guard let call = getCall(with: callId) else { return }

        call.peerHolding = holding
        notifyCallUpdated(call)
    }

    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]]) {
        guard let call = getCall(with: callId),
              let callDictionary = callsAdapter.callDetails(withCallId: callId, accountId: call.accountId) else { return }

        call.update(withDictionary: callDictionary, withMedia: media)
        notifyCallUpdated(call)
    }

    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]]) {
        guard let call = getCall(with: callId) else { return }

        let answerMedias = processMediaChangeRequest(call: call, requestedMedia: media)
        callsAdapter.answerMediaChangeResquest(callId, accountId: accountId, withMedia: answerMedias)
    }

    private func getCall(with callId: String) -> CallModel? {
        return calls.value[callId]
    }

    private func notifyCallUpdated(_ call: CallModel) {
        currentCallsEvents.onNext(call)
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

// MARK: - Media Attribute Factory

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
