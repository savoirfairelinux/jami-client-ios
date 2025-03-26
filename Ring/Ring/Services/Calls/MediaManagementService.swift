import RxRelay
import RxSwift

// Interface for media management
protocol MediaManaging {
    func getVideoCodec(call: CallModel) -> String?
    func audioMuted(call callId: String, mute: Bool)
    func videoMuted(call callId: String, mute: Bool)
    func callMediaUpdated(call: CallModel)
    func updateCallMediaIfNeeded(call: CallModel)
}

enum MediaType: String, CustomStringConvertible {
    case audio = "MEDIA_TYPE_AUDIO"
    case video = "MEDIA_TYPE_VIDEO"

    var description: String {
        return self.rawValue
    }
}

class MediaManagementService: MediaManaging {
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
        let callDetails = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId)
        return callDetails?[CallDetailKey.videoCodec.rawValue]
    }

    func audioMuted(call callId: String, mute: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.audioMuted = mute
        self.currentCallsEvents.onNext(call)
    }

    func videoMuted(call callId: String, mute: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.videoMuted = mute
        self.currentCallsEvents.onNext(call)
    }

    func callMediaUpdated(call: CallModel) {
        var mediaList = call.mediaList
        if mediaList.isEmpty {
            guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
            call.update(withDictionary: [:], withMedia: attributes)
            mediaList = call.mediaList
        }
        if let callDictionary = self.callsAdapter.callDetails(withCallId: call.callId, accountId: call.accountId) {
            call.update(withDictionary: callDictionary, withMedia: mediaList)
            self.currentCallsEvents.onNext(call)
        }
    }

    func updateCallMediaIfNeeded(call: CallModel) {
        var mediaList = call.mediaList
        if mediaList.isEmpty {
            guard let attributes = self.callsAdapter.currentMediaList(withCallId: call.callId, accountId: call.accountId) else { return }
            call.update(withDictionary: [:], withMedia: attributes)
            mediaList = call.mediaList
        }
        call.mediaList = mediaList
    }

    /// Handles a change in the remote recording state
    func handleRemoteRecordingChanged(callId: String, record: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.callRecorded = record
        self.currentCallsEvents.onNext(call)
    }

    /// Handles when a call is placed on hold
    func handleCallPlacedOnHold(callId: String, holding: Bool) {
        guard let call = self.calls.value[callId] else {
            return
        }
        call.peerHolding = holding
        self.currentCallsEvents.onNext(call)
    }

    /// Updates media negotiation status based on an event
    func handleMediaNegotiationStatus(callId: String, event: String, media: [[String: String]]) {
        guard let call = self.calls.value[callId],
              let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: call.accountId) else { return }
        call.update(withDictionary: callDictionary, withMedia: media)
        self.currentCallsEvents.onNext(call)
    }

    /// Handles a request to change media
    func handleMediaChangeRequest(accountId: String, callId: String, media: [[String: String]]) {
        guard let call = self.calls.value[callId] else { return }
        var currentMediaLabels = [String]()
        for media in call.mediaList where media[MediaAttributeKey.label.rawValue] != nil {
            currentMediaLabels.append(media[MediaAttributeKey.label.rawValue]!)
        }

        var answerMedias = [[String: String]]()
        for media in media {
            let label = media[MediaAttributeKey.label.rawValue] ?? ""
            let index = currentMediaLabels.firstIndex(of: label) ?? -1
            if index >= 0 {
                var answerMedia = media
                answerMedia[MediaAttributeKey.muted.rawValue] = call.mediaList[index][MediaAttributeKey.muted.rawValue]
                answerMedia[MediaAttributeKey.enabled.rawValue] = call.mediaList[index][MediaAttributeKey.enabled.rawValue]
                answerMedias.append(answerMedia)
            } else {
                var answerMedia = media
                answerMedia[MediaAttributeKey.muted.rawValue] = "true"
                answerMedia[MediaAttributeKey.enabled.rawValue] = "true"
                answerMedias.append(answerMedia)
            }
        }
        self.callsAdapter.answerMediaChangeResquest(callId, accountId: accountId, withMedia: answerMedias)
    }
}

/// Factory for creating media attributes
/// Follows the Factory Method pattern to create media attributes
class MediaAttributeFactory {
    static func createAudioMedia() -> [String: String] {
        var mediaAttribute = [String: String]()
        mediaAttribute[MediaAttributeKey.mediaType.rawValue] = MediaAttributeValue.audio.rawValue
        mediaAttribute[MediaAttributeKey.label.rawValue] = "audio_0"
        mediaAttribute[MediaAttributeKey.enabled.rawValue] = "true"
        mediaAttribute[MediaAttributeKey.muted.rawValue] = "false"
        return mediaAttribute
    }

    static func createVideoMedia(source: String) -> [String: String] {
        var mediaAttribute = [String: String]()
        mediaAttribute[MediaAttributeKey.mediaType.rawValue] = MediaAttributeValue.video.rawValue
        mediaAttribute[MediaAttributeKey.label.rawValue] = "video_0"
        mediaAttribute[MediaAttributeKey.source.rawValue] = source
        mediaAttribute[MediaAttributeKey.enabled.rawValue] = "true"
        mediaAttribute[MediaAttributeKey.muted.rawValue] = "false"
        return mediaAttribute
    }

    static func createDefaultMediaList(isAudioOnly: Bool, videoSource: String) -> [[String: String]] {
        var mediaList = [[String: String]]()
        mediaList.append(createAudioMedia())

        if !isAudioOnly {
            mediaList.append(createVideoMedia(source: videoSource))
        }

        return mediaList
    }
}
