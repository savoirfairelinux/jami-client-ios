import RxSwift
import RxRelay

// Interface for call management
protocol CallManaging {
    func call(callID: String) -> CallModel?
    func callByUUID(UUID: String) -> CallModel?
    func accept(call: CallModel?) -> Completable
    func refuse(callId: String) -> Completable
    func hangUp(callId: String) -> Completable
    func hold(callId: String) -> Completable
    func unhold(callId: String) -> Completable
    func placeCall(withAccount account: AccountModel,
                   toParticipantId participantId: String,
                   userName: String,
                   videoSource: String,
                   isAudioOnly: Bool,
                   withMedia: [[String: String]]) -> Single<CallModel>
    func answerCall(call: CallModel) -> Bool
    func stopCall(call: CallModel)
    func stopPendingCall(callId: String)
    func playDTMF(code: String)
    func isCurrentCall() -> Bool
}

enum CallServiceError: Error {
    case acceptCallFailed
    case refuseCallFailed
    case hangUpCallFailed
    case holdCallFailed
    case unholdCallFailed
    case placeCallFailed
}

class CallManagementService: CallManaging {
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let currentCallsEvents: ReplaySubject<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>
    private let disposeBag = DisposeBag()

    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        currentCallsEvents: ReplaySubject<CallModel>,
        responseStream: PublishSubject<ServiceEvent>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.currentCallsEvents = currentCallsEvents
        self.responseStream = responseStream
    }

    func call(callID: String) -> CallModel? {
        return calls.value[callID]
    }

    func callByUUID(UUID: String) -> CallModel? {
        return calls.value.values.filter { call in
            call.callUUID.uuidString == UUID
        }.first
    }

    func accept(call: CallModel?) -> Completable {
        return Completable.create(subscribe: { completable in
            guard let callId = call?.callId else {
                completable(.error(CallServiceError.acceptCallFailed))
                return Disposables.create { }
            }
            let success = self.callsAdapter.acceptCall(withId: callId, accountId: call?.accountId, withMedia: call?.mediaList)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.acceptCallFailed))
            }
            return Disposables.create { }
        })
    }

    func refuse(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            guard let call = self.call(callID: callId) else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            let success = self.callsAdapter.refuseCall(withId: callId, accountId: call.accountId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.refuseCallFailed))
            }
            return Disposables.create { }
        })
    }

    func hangUp(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            var success: Bool
            guard let call = self.call(callID: callId) else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            success = self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.hangUpCallFailed))
            }
            return Disposables.create { }
        })
    }

    func hold(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            guard let call = self.call(callID: callId) else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            let success = self.callsAdapter.holdCall(withId: callId, accountId: call.accountId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.holdCallFailed))
            }
            return Disposables.create { }
        })
    }

    func unhold(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            guard let call = self.call(callID: callId) else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            let success = self.callsAdapter.unholdCall(withId: callId, accountId: call.accountId)
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.unholdCallFailed))
            }
            return Disposables.create { }
        })
    }

    func placeCall(withAccount account: AccountModel,
                   toParticipantId participantId: String,
                   userName: String,
                   videoSource: String,
                   isAudioOnly: Bool = false,
                   withMedia: [[String: String]] = [[String: String]]()) -> Single<CallModel> {

        // Create and emit the call
        var callDetails = [String: String]()
        callDetails[CallDetailKey.callTypeKey.rawValue] = String(describing: CallType.outgoing)
        callDetails[CallDetailKey.displayNameKey.rawValue] = userName
        callDetails[CallDetailKey.accountIdKey.rawValue] = account.id
        callDetails[CallDetailKey.audioOnlyKey.rawValue] = isAudioOnly.toString()
        callDetails[CallDetailKey.timeStampStartKey.rawValue] = ""

        var mediaList = withMedia
        if mediaList.isEmpty {
            mediaList = MediaAttributeFactory.createDefaultMediaList(isAudioOnly: isAudioOnly, videoSource: videoSource)
        }

        let call = CallModelFactory.createOutgoingCall(
            participantId: participantId,
            accountId: account.id,
            userName: userName,
            isAudioOnly: isAudioOnly,
            withMedia: mediaList
        )

        return Single<CallModel>.create(subscribe: { [weak self] single in
            if let self = self, let callId = self.callsAdapter.placeCall(withAccountId: account.id,
                                                                         toParticipantId: participantId,
                                                                         withMedia: mediaList), !callId.isEmpty,
               let callDictionary = self.callsAdapter.callDetails(withCallId: callId, accountId: account.id) {
                call.update(withDictionary: callDictionary, withMedia: mediaList)
                call.participantUri = participantId
                call.callId = callId
                call.participantsCallId.removeAll()
                call.participantsCallId.insert(callId)
                self.currentCallsEvents.onNext(call)
                var values = self.calls.value
                values[callId] = call
                self.calls.accept(values)
                single(.success(call))
            } else {
                single(.failure(CallServiceError.placeCallFailed))
            }
            return Disposables.create { }
        })
    }

    func answerCall(call: CallModel) -> Bool {
        NSLog("call service answerCall %@", call.callId)
        return self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
    }

    func stopCall(call: CallModel) {
        self.callsAdapter.hangUpCall(call.callId, accountId: call.accountId)
    }

    func stopPendingCall(callId: String) {
        guard let call = self.call(callID: callId) else { return }
        self.stopCall(call: call)
    }

    func playDTMF(code: String) {
        self.callsAdapter.playDTMF(code)
    }

    func isCurrentCall() -> Bool {
        for call in self.calls.value.values {
            if call.state == .current || call.state == .hold ||
                call.state == .unhold || call.state == .ringing {
                return true
            }
        }
        return false
    }

    /// Updates or adds a call in the calls map
    func updateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]] = [[String: String]]()) -> CallModel? {
        var call = self.calls.value[callId]

        if call == nil {
            if !callState.isActive() {
                return nil
            }
            call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
            var values = self.calls.value
            values[callId] = call
            self.calls.accept(values)
        } else {
            call?.update(withDictionary: callDictionary, withMedia: mediaList)
        }

        return call
    }

    /// Removes a call from the calls map
    func removeCall(callId: String, callState: CallState) {
        guard let finishedCall = self.calls.value[callId],
              callState == .over || callState == .failure else { return }

        var time = 0
        if let startTime = finishedCall.dateReceived {
            time = Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
        }
        var event = ServiceEvent(withEventType: .callEnded)
        event.addEventInput(.peerUri, value: finishedCall.participantUri)
        event.addEventInput(.callUUID, value: finishedCall.callUUID.uuidString)
        event.addEventInput(.accountId, value: finishedCall.accountId)
        event.addEventInput(.callType, value: finishedCall.callType.rawValue)
        event.addEventInput(.callTime, value: time)
        self.responseStream.onNext(event)
        self.currentCallsEvents.onNext(finishedCall)
        var values = self.calls.value
        values[callId] = nil
        self.calls.accept(values)
    }

    /// Method to update a call's UUID
    func updateCallUUID(callId: String, callUUID: String) {
        if let call = self.call(callID: callId), let uuid = UUID(uuidString: callUUID) {
            call.callUUID = uuid
        }
    }
}

/// Factory for creating a call model
/// Follows the Factory Method pattern to create CallModel instances
class CallModelFactory {
    static func createCall(withId callId: String, callDetails: [String: String], withMedia mediaList: [[String: String]]) -> CallModel {
        return CallModel(withCallId: callId, callDetails: callDetails, withMedia: mediaList)
    }

    static func createOutgoingCall(participantId: String,
                                   accountId: String,
                                   userName: String,
                                   isAudioOnly: Bool,
                                   withMedia mediaList: [[String: String]]) -> CallModel {
        var callDetails = [String: String]()
        callDetails[CallDetailKey.callTypeKey.rawValue] = String(describing: CallType.outgoing)
        callDetails[CallDetailKey.displayNameKey.rawValue] = userName
        callDetails[CallDetailKey.accountIdKey.rawValue] = accountId
        callDetails[CallDetailKey.audioOnlyKey.rawValue] = isAudioOnly.toString()
        callDetails[CallDetailKey.timeStampStartKey.rawValue] = ""

        let call = CallModel(withCallId: participantId, callDetails: callDetails, withMedia: mediaList)
        call.state = .unknown
        call.callType = .outgoing
        call.participantUri = participantId
        return call
    }
}

