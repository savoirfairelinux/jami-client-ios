import RxSwift
import RxRelay

protocol CallManaging {
    func call(callId: String) -> CallModel?
    func callByUUID(UUID: String) -> CallModel?
    func accept(callId: String) -> Completable
    func refuse(callId: String) -> Completable
    func hangUp(callId: String) -> Completable
    func hold(callId: String) -> Completable
    func unhold(callId: String) -> Completable
    func isCurrentCall() -> Bool

    func addOrUpdateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]]) -> CallModel?
    func removeCall(callId: String, callState: CallState)
    func updateCallUUID(callId: String, callUUID: String)
}

enum CallServiceError: Error {
    case acceptCallFailed
    case refuseCallFailed
    case hangUpCallFailed
    case holdCallFailed
    case unholdCallFailed
    case placeCallFailed
    case callNotFound
    case invalidUUID
}

class CallManagementService: CallManaging {
    // MARK: - Properties

    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let currentCallsEvents: ReplaySubject<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>
    private let disposeBag = DisposeBag()

    // MARK: - Initialization

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

    // MARK: - Call Access

    func call(callId: String) -> CallModel? {
        return calls.value[callId]
    }

    func callByUUID(UUID: String) -> CallModel? {
        return calls.value.values.first(where: { $0.callUUID.uuidString == UUID })
    }

    // MARK: - Call Management

    func accept(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .acceptCallFailed) { call in
            self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
        }
    }

    func refuse(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .refuseCallFailed) { call in
            self.callsAdapter.refuseCall(withId: callId, accountId: call.accountId)
        }
    }

    func hangUp(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .hangUpCallFailed) { call in
            self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
        }
    }

    func hold(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .holdCallFailed) { call in
            self.callsAdapter.holdCall(withId: callId, accountId: call.accountId)
        }
    }

    func unhold(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .unholdCallFailed) { call in
            self.callsAdapter.unholdCall(withId: callId, accountId: call.accountId)
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

    // Initiates a call through the adapter
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

    // Retrieves call details from the adapter
    private func getCallDetails(callId: String, accountId: String) -> [String: String]? {
        return self.callsAdapter.callDetails(
            withCallId: callId,
            accountId: accountId
        )
    }

    func isCurrentCall() -> Bool {
        return calls.value.values.contains { call in
            call.state == .current || call.state == .hold ||
                call.state == .unhold || call.state == .ringing
        }
    }

    // MARK: - Call State Management

    func addOrUpdateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]] = [[String: String]]()) -> CallModel? {
        var call = self.calls.value[callId]
        var isNewCall = false
        var previousState: CallState?

        if call == nil {
            if !callState.isActive() {
                return nil
            }
            call = CallModel(withCallId: callId, callDetails: callDictionary, withMedia: mediaList)
            isNewCall = true
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

            self.currentCallsEvents.onNext(updatedCall)
        }

        return call
    }

    func removeCall(callId: String, callState: CallState) {
        guard let finishedCall = self.calls.value[callId],
              callState == .over || callState == .failure else { return }

        let callDuration = calculateCallDuration(finishedCall)
        emitCallEnded(call: finishedCall, duration: callDuration)

        self.currentCallsEvents.onNext(finishedCall)

        var values = self.calls.value
        values[callId] = nil
        self.calls.accept(values)
    }

    func updateCallUUID(callId: String, callUUID: String) {
        guard let call = self.call(callId: callId),
              let uuid = UUID(uuidString: callUUID) else { return }

        call.callUUID = uuid
    }

    // MARK: - Private Helpers

    private func createObservableAction(callId: String, error: CallServiceError, action: @escaping (CallModel) -> Bool) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self, let call = self.call(callId: callId) else {
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
        var values = self.calls.value
        values[callId] = call
        self.calls.accept(values)
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
        event.addEventInput(.callType, value: call.callType.rawValue)
    }
}

// MARK: - Factory Methods
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
