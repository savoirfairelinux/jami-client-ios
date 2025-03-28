import RxSwift
import RxRelay

/*
 * CallManagementService Thread Safety Contract:
 *
 * This service uses ThreadSafeQueueHelper to ensure thread safety when modifying shared state.
 * Thread safety is managed following these guidelines:
 *
 * 1. For read-only operations on BehaviorRelay:
 *    - Direct access to .value is thread-safe (e.g., calls.value[callId])
 *    - No queue synchronization needed
 *
 * 2. For modifying shared state:
 *    - Use queueHelper.barrierAsync { ... }
 *
 * 3. For synchronized reads of non-relay state:
 *    - Use queueHelper.safeSync { ... }
 */

/// Protocol defining call management operations
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

    func addOrUpdateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]]) -> CallModel?
    func removeCall(callId: String, callState: CallState)
    func updateCallUUID(callId: String, callUUID: String)
}

/// Errors that can occur during call management operations
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

/// Service responsible for managing calls
class CallManagementService: CallManaging {
    // MARK: - Properties

    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private let callUpdates: ReplaySubject<CallModel>
    private let responseStream: PublishSubject<ServiceEvent>
    private let disposeBag = DisposeBag()
    
    // Thread safety
    private let queueHelper: ThreadSafeQueueHelper

    // MARK: - Initialization

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
        self.responseStream = responseStream
        self.queueHelper = queueHelper
    }

    // MARK: - Call Access

    /// Returns a call model by call ID
    /// - Parameter callId: The ID of the call
    /// - Returns: The call model if found, nil otherwise
    func call(callId: String) -> CallModel? {
        // Reading from BehaviorRelay is thread-safe
        return calls.value[callId]
    }

    /// Returns a call model by participant ID and account ID
    /// - Parameters:
    ///   - participantId: The ID of the participant
    ///   - accountId: The ID of the account
    /// - Returns: The call model if found, nil otherwise
    func call(participantId: String, accountId: String) -> CallModel? {
        // Reading from BehaviorRelay is thread-safe
        return calls.value.values.first(where: { $0.paricipantHash() == participantId && $0.accountId == accountId})
    }

    /// Returns a call model by UUID
    /// - Parameter UUID: The UUID of the call
    /// - Returns: The call model if found, nil otherwise
    func callByUUID(UUID: String) -> CallModel? {
        // Reading from BehaviorRelay is thread-safe
        return calls.value.values.first(where: { $0.callUUID.uuidString == UUID })
    }

    // MARK: - Call Management

    /// Accepts an incoming call
    /// - Parameter callId: The ID of the call to accept
    /// - Returns: A Completable that completes when the call is accepted
    func accept(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .acceptCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.acceptCall(withId: call.callId, accountId: call.accountId, withMedia: call.mediaList)
        }
    }

    /// Refuses an incoming call
    /// - Parameter callId: The ID of the call to refuse
    /// - Returns: A Completable that completes when the call is refused
    func refuse(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .refuseCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.refuseCall(withId: callId, accountId: call.accountId)
        }
    }

    /// Hangs up an active call
    /// - Parameter callId: The ID of the call to hang up
    /// - Returns: A Completable that completes when the call is hung up
    func hangUp(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .hangUpCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
        }
    }

    /// Puts a call on hold
    /// - Parameter callId: The ID of the call to put on hold
    /// - Returns: A Completable that completes when the call is put on hold
    func hold(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .holdCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.holdCall(withId: callId, accountId: call.accountId)
        }
    }

    /// Removes a call from hold
    /// - Parameter callId: The ID of the call to remove from hold
    /// - Returns: A Completable that completes when the call is removed from hold
    func unhold(callId: String) -> Completable {
        return createObservableAction(callId: callId, error: .unholdCallFailed) { [weak self] call in
            guard let self = self else { return false }
            return self.callsAdapter.unholdCall(withId: callId, accountId: call.accountId)
        }
    }

    /// Places a new call
    /// - Parameters:
    ///   - account: The account to use for the call
    ///   - participantId: The ID of the participant to call
    ///   - userName: The name of the user
    ///   - videoSource: The source of the video
    ///   - isAudioOnly: Whether the call is audio-only
    ///   - withMedia: The media attributes for the call
    /// - Returns: A Single that emits the call model when the call is placed
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

    /// Prepares a call model for placing a new call
    /// - Parameters:
    ///   - account: The account to use for the call
    ///   - participantId: The ID of the participant to call
    ///   - userName: The name of the user
    ///   - videoSource: The source of the video
    ///   - isAudioOnly: Whether the call is audio-only
    ///   - withMedia: The media attributes for the call
    /// - Returns: A Single that emits the prepared call model
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

    /// Executes a call using the prepared call model
    /// - Parameters:
    ///   - callModel: The prepared call model
    ///   - account: The account to use for the call
    ///   - participantId: The ID of the participant to call
    /// - Returns: A Single that emits the updated call model
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

    /// Initiates a call through the adapter
    /// - Parameters:
    ///   - account: The account to use for the call
    ///   - participantId: The ID of the participant to call
    ///   - mediaList: The media attributes for the call
    /// - Returns: The ID of the initiated call, or an empty string if failed
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

    /// Retrieves call details from the adapter
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - accountId: The ID of the account
    /// - Returns: The call details, or nil if not found
    private func getCallDetails(callId: String, accountId: String) -> [String: String]? {
        return self.callsAdapter.callDetails(
            withCallId: callId,
            accountId: accountId
        )
    }

    /// Checks if there is a current active call
    /// - Returns: true if there is a current active call, false otherwise
    func isCurrentCall() -> Bool {
        // Reading from BehaviorRelay is thread-safe
        return calls.value.values.contains { call in
            call.state == .current || call.state == .hold ||
                call.state == .unhold || call.state == .ringing
        }
    }

    // MARK: - Call State Management

    /// Adds a new call or updates an existing call
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - callState: The state of the call
    ///   - callDictionary: The call details
    ///   - mediaList: The media attributes for the call
    /// - Returns: The added or updated call model, or nil if the call cannot be added or updated
    func addOrUpdateCall(callId: String, callState: CallState, callDictionary: [String: String], mediaList: [[String: String]] = [[String: String]]()) -> CallModel? {
        return queueHelper.safeBarrierSync {
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

                self.callUpdates.onNext(updatedCall)
            }

            return call
        }
    }

    /// Removes a call that has ended or failed
    /// - Parameters:
    ///   - callId: The ID of the call to remove
    ///   - callState: The state of the call
    func removeCall(callId: String, callState: CallState) {
        queueHelper.barrierAsync {
            guard let finishedCall = self.calls.value[callId],
                  callState == .over || callState == .failure else { return }

            let callDuration = self.calculateCallDuration(finishedCall)
            self.emitCallEnded(call: finishedCall, duration: callDuration)

            self.callUpdates.onNext(finishedCall)

            var values = self.calls.value
            values[callId] = nil
            self.calls.accept(values)
        }
    }

    /// Updates the UUID of a call
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - callUUID: The new UUID for the call
    func updateCallUUID(callId: String, callUUID: String) {
        queueHelper.barrierAsync {
            guard let call = self.calls.value[callId],
                  let uuid = UUID(uuidString: callUUID) else { return }

            call.callUUID = uuid
        }
    }

    // MARK: - Private Helpers

    /// Creates a Completable for a call operation
    /// - Parameters:
    ///   - callId: The ID of the call
    ///   - error: The error to return if the operation fails
    ///   - action: The action to perform on the call
    /// - Returns: A Completable that completes when the operation is done
    private func createObservableAction(callId: String, error: CallServiceError, action: @escaping (CallModel) -> Bool) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.error(CallServiceError.callNotFound))
                return Disposables.create()
            }
            
            // Reading from BehaviorRelay is thread-safe
            guard let call = self.calls.value[callId] else {
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

    /// Updates the calls store with a new or updated call
    /// - Parameters:
    ///   - call: The call to update
    ///   - callId: The ID of the call
    private func updateCallsStore(_ call: CallModel, forId callId: String) {
        queueHelper.barrierAsync {
            var values = self.calls.value
            values[callId] = call
            self.calls.accept(values)
        }
    }

    /// Calculates the duration of a call
    /// - Parameter call: The call to calculate the duration for
    /// - Returns: The duration of the call in seconds
    private func calculateCallDuration(_ call: CallModel) -> Int {
        guard let startTime = call.dateReceived else { return 0 }
        return Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
    }

    // MARK: - Event Emission

    /// Emits a call ended event
    /// - Parameters:
    ///   - call: The call that ended
    ///   - duration: The duration of the call
    private func emitCallEnded(call: CallModel, duration: Int) {
        var event = ServiceEvent(withEventType: .callEnded)
        configureBasicCallEvent(&event, for: call)
        event.addEventInput(.callTime, value: duration)
        self.responseStream.onNext(event)
    }

    /// Emits a call started event
    /// - Parameter call: The call that started
    private func emitCallStarted(call: CallModel) {
        var event = ServiceEvent(withEventType: .callStarted)
        configureBasicCallEvent(&event, for: call)
        self.responseStream.onNext(event)
    }

    /// Emits a call state changed event
    /// - Parameters:
    ///   - call: The call whose state changed
    ///   - newState: The new state of the call
    private func emitCallStateChanged(call: CallModel, newState: CallState) {
        var event = ServiceEvent(withEventType: .callStateChanged)
        configureBasicCallEvent(&event, for: call)
        event.addEventInput(.callState, value: newState.rawValue)
        self.responseStream.onNext(event)
    }

    /// Configures the basic properties of a call event
    /// - Parameters:
    ///   - event: The event to configure
    ///   - call: The call to configure the event for
    private func configureBasicCallEvent(_ event: inout ServiceEvent, for call: CallModel) {
        event.addEventInput(.peerUri, value: call.participantUri)
        event.addEventInput(.callUUID, value: call.callUUID.uuidString)
        event.addEventInput(.accountId, value: call.accountId)
        event.addEventInput(.callType, value: call.callType.rawValue)
    }
}

// MARK: - Factory Methods
class CallModelFactory {
    
    /// Creates an outgoing call model
    /// - Parameters:
    ///   - participantId: The ID of the participant to call
    ///   - accountId: The ID of the account
    ///   - userName: The name of the user
    ///   - isAudioOnly: Whether the call is audio-only
    ///   - withMedia: The media attributes for the call
    /// - Returns: A new outgoing call model
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
