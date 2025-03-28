import RxSwift
import RxRelay

protocol CallManaging {
    func call(callId: String) -> CallModel?
    func call(participantId: String, accountId: String) -> CallModel?
    func callByUUID(UUID: String) -> CallModel?
    func accept(callId: String) -> Completable
    func refuse(callId: String) -> Completable
    func hangUp(callId: String) -> Completable
    func hold(callId: String) -> Completable
    func unhold(callId: String) -> Completable
    func isCurrentCall() -> Bool
    func placeCall(withAccount account: AccountModel, toParticipantId participantId: String, userName: String, videoSource: String, isAudioOnly: Bool, withMedia: [[String: String]]) -> Single<CallModel>
    func placeCall(accountId: String, toParticipantId: String) async -> (success: Bool, callId: String?, error: Error?)
    func accept(callId: String) async -> (success: Bool, error: Error?)
    func refuse(callId: String) async -> (success: Bool, error: Error?)

    func addOrUpdateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]]) -> CallModel?
    func removeCall(callId: String, callState: CallState) async
    func updateCallUUID(callId: String, callUUID: String) async
}

enum CallServiceError: Error, LocalizedError {
    case acceptCallFailed
    case refuseCallFailed
    case hangUpCallFailed
    case holdCallFailed
    case unholdCallFailed
    case placeCallFailed
    case callNotFound
    case invalidUUID
    
    var errorDescription: String? {
        switch self {
        case .acceptCallFailed:
            return "Failed to accept call"
        case .refuseCallFailed:
            return "Failed to refuse call"
        case .hangUpCallFailed:
            return "Failed to hang up call"
        case .holdCallFailed:
            return "Failed to hold call"
        case .unholdCallFailed:
            return "Failed to unhold call"
        case .placeCallFailed:
            return "Failed to place call"
        case .callNotFound:
            return "Call not found"
        case .invalidUUID:
            return "Invalid call UUID"
        }
    }
}

class CallManagementService: CallManaging {
    // MARK: - Properties

    private let callsAdapter: CallsAdapter
    private let calls: SynchronizedRelay<[String: CallModel]>
    private let callUpdates: ReplaySubject<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>
    private let disposeBag = DisposeBag()

    // MARK: - Initialization

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

    // MARK: - Call Access

    func call(callId: String) -> CallModel? {
        return calls.get()[callId]
    }

    func call(participantId: String, accountId: String) -> CallModel? {
        return calls.get().values.first(where: { $0.paricipantHash() == participantId && $0.accountId == accountId})
    }

    func callByUUID(UUID: String) -> CallModel? {
        return calls.get().values.first(where: { $0.callUUID.uuidString == UUID })
    }

    // MARK: - Call Management

    func accept(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .acceptCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
        }
    }

    func refuse(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .refuseCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.refuseCall(withId: callId, accountId: call.accountId)
        }
    }

    func hangUp(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .hangUpCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
        }
    }

    func hold(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .holdCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.holdCall(withId: callId, accountId: call.accountId)
        }
    }

    func unhold(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .unholdCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.unholdCall(withId: callId, accountId: call.accountId)
        }
    }

    func placeCall(withAccount account: AccountModel,
                   toParticipantId participantId: String,
                   userName: String,
                   videoSource: String,
                   isAudioOnly: Bool = false,
                   withMedia: [[String: String]] = [[String: String]]()) -> Single<CallModel> {

        return prepareCallModel(
            account: account,
            participantId: participantId,
            userName: userName,
            videoSource: videoSource,
            isAudioOnly: isAudioOnly,
            withMedia: withMedia
        )
        .flatMap { [weak self] callModel -> Single<CallModel> in
            guard let self = self else {
                return Single.error(CallServiceError.placeCallFailed)
            }
            return self.executeCall(callModel: callModel, account: account, participantId: participantId)
        }
    }

    private func prepareCallModel(
        account: AccountModel,
        participantId: String,
        userName: String,
        videoSource: String,
        isAudioOnly: Bool,
        withMedia: [[String: String]]
    ) -> Single<CallModel> {
        let mediaList = withMedia.isEmpty ?
            MediaAttributeFactory.createDefaultMediaList(isAudioOnly: isAudioOnly, videoSource: videoSource) :
            withMedia

        let call = CallModelFactory.createOutgoingCall(
            participantId: participantId,
            accountId: account.id,
            userName: userName,
            isAudioOnly: isAudioOnly,
            withMedia: mediaList
        )

        return Single.just(call)
    }

    private func executeCall(
        callModel: CallModel,
        account: AccountModel,
        participantId: String
    ) -> Single<CallModel> {
        return Single<CallModel>.create { [weak self] single in
            guard let self = self else {
                single(.failure(CallServiceError.placeCallFailed))
                return Disposables.create()
            }

            let callId = self.initiateCall(account: account, participantId: participantId, mediaList: callModel.mediaList)
            if callId.isEmpty {
                single(.failure(CallServiceError.placeCallFailed))
                return Disposables.create()
            }

            guard let callDictionary = self.getCallDetails(callId: callId, accountId: account.id) else {
                single(.failure(CallServiceError.placeCallFailed))
                return Disposables.create()
            }

            callModel.updateWith(callId: callId, callDictionary: callDictionary, participantId: participantId)
            self.updateCallsStore(callModel, forId: callId)

            self.emitCallStarted(call: callModel)
            single(.success(callModel))

            return Disposables.create()
        }
    }

    private func initiateCall(account: AccountModel, participantId: String, mediaList: [[String: String]]) -> String {
        guard let callId = self.callsAdapter.placeCall(
            withAccountId: account.id,
            toParticipantId: participantId,
            withMedia: mediaList
        ) else {
            return ""
        }
        return callId
    }

    func getCallDetails(callId: String, accountId: String) -> [String: String]? {
        return self.callsAdapter.callDetails(
            withCallId: callId,
            accountId: accountId
        )
    }

    func isCurrentCall() -> Bool {
        return calls.get().values.contains { $0.isCurrent() }
    }

    // MARK: - Call State Management

    func addOrUpdateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]] = [[String: String]]()) -> CallModel? {
        var call = self.calls.get()[callId]
        var isNewCall = false
        var previousState: CallState?

        if call == nil {
            if !callState.isActive() {
                return nil
            }
            call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
            isNewCall = true
            call?.state = callState
            updateCallsStore(call!, forId: callId)
        } else {
            previousState = call?.state
            call?.update(withDictionary: callDictionary, withMedia: mediaList)
            call?.state = callState
        }

        if let updatedCall = call {
            if isNewCall && callState.isActive() {
                emitCallStarted(call: updatedCall)
            } else if let prevState = previousState, prevState != callState {
                emitCallStateChanged(call: updatedCall, newState: callState)
            }

            self.callUpdates.onNext(updatedCall)
        }

        return call
    }

    func removeCall(callId: String, callState: CallState) async {
        await withCheckedContinuation { continuation in
            guard let finishedCall = self.call(callId: callId) else {
                continuation.resume()
                return 
            }

            finishedCall.state = callState

            let callDuration = self.calculateCallDuration(finishedCall)
            self.emitCallEnded(call: finishedCall, duration: callDuration)

            self.callUpdates.onNext(finishedCall)

            self.calls.update { calls in
                calls[callId] = nil
            }
            
            continuation.resume()
        }
    }

    func updateCallUUID(callId: String, callUUID: String) async {
        await withCheckedContinuation { continuation in
            guard let call = self.call(callId: callId),
                  let uuid = UUID(uuidString: callUUID) else { 
                continuation.resume()
                return 
            }

            call.callUUID = uuid
            continuation.resume()
        }
    }

    // MARK: - Private Helpers

    private func createObservableAction(callId: String, error: CallServiceError, action: @escaping (CallModel) -> Bool) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.error(CallServiceError.callNotFound))
                return Disposables.create()
            }
            
            guard let call = self.call(callId: callId) else {
                completable(.error(CallServiceError.callNotFound))
                return Disposables.create()
            }

            let success = action(call)
            if success {
                completable(.completed)
            } else {
                completable(.error(error))
            }

            return Disposables.create()
        }
    }

    private func updateCallsStore(_ call: CallModel, forId callId: String) {
        self.calls.update { calls in
            calls[callId] = call
        }
    }

    private func calculateCallDuration(_ call: CallModel) -> Int {
        guard let startTime = call.dateReceived else { return 0 }
        return Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
    }

    // MARK: - Event Emission

    private func emitCallEnded(call: CallModel, duration: Int) {
        var event = ServiceEvent(withEventType: .callEnded)
        configureBasicCallEvent(&event, for: call)
        event.addEventInput(.callTime, value: duration)
        self.responseStream.onNext(event)
    }

    private func emitCallStarted(call: CallModel) {
        var event = ServiceEvent(withEventType: .callStarted)
        configureBasicCallEvent(&event, for: call)
        self.responseStream.onNext(event)
    }

    private func emitCallStateChanged(call: CallModel, newState: CallState) {
        var event = ServiceEvent(withEventType: .callStateChanged)
        configureBasicCallEvent(&event, for: call)
        event.addEventInput(.callState, value: newState.rawValue)
        self.responseStream.onNext(event)
    }

    private func configureBasicCallEvent(_ event: inout ServiceEvent, for call: CallModel) {
        event.addEventInput(.peerUri, value: call.participantUri)
        event.addEventInput(.callUUID, value: call.callUUID.uuidString)
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.callId, value: call.callId)
        event.addEventInput(.callType, value: call.callType.rawValue)
    }

    // Add new async version of placeCall
    func placeCall(accountId: String, toParticipantId: String) async -> (success: Bool, callId: String?, error: Error?) {
        return await withCheckedContinuation { continuation in
            let callId = self.callsAdapter.placeCall(withAccountId: accountId, toParticipantId: toParticipantId, withMedia: [])
            
            if callId?.isEmpty ?? true {
                continuation.resume(returning: (success: false, callId: nil, error: CallServiceError.placeCallFailed))
                return
            }
            
            continuation.resume(returning: (success: true, callId: callId, error: nil))
        }
    }

    // Add async version of accept
    func accept(callId: String) async -> (success: Bool, error: Error?) {
        return await withCheckedContinuation { continuation in
            guard let call = self.call(callId: callId) else {
                continuation.resume(returning: (success: false, error: CallServiceError.callNotFound))
                return
            }
            
            let success = self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
            
            if success {
                continuation.resume(returning: (success: true, error: nil))
            } else {
                continuation.resume(returning: (success: false, error: CallServiceError.acceptCallFailed))
            }
        }
    }
    
    // Add async version of refuse
    func refuse(callId: String) async -> (success: Bool, error: Error?) {
        return await withCheckedContinuation { continuation in
            guard let call = self.call(callId: callId) else {
                continuation.resume(returning: (success: false, error: CallServiceError.callNotFound))
                return
            }
            
            let success = self.callsAdapter.refuseCall(withId: callId, accountId: call.accountId)
            
            if success {
                continuation.resume(returning: (success: true, error: nil))
            } else {
                continuation.resume(returning: (success: false, error: CallServiceError.refuseCallFailed))
            }
        }
    }
}

class CallModelFactory {
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
