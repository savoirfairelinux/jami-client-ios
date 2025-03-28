import RxSwift
import RxRelay

protocol ConferenceManaging {
    func joinConference(confID: String, callID: String) async
    func joinCall(firstCallId: String, secondCallId: String) async
    func addCall(call: CallModel, to callId: String) async
    func hangUpCallOrConference(callId: String) -> Completable
    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool?
    func isModerator(participantId: String, inConference confId: String) -> Bool
    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]?
    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) async
    func setModeratorParticipant(confId: String, participantId: String, active: Bool) async
    func hangupParticipant(confId: String, participantId: String, device: String) async
    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) async
    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) async

    var currentConferenceEvent: BehaviorRelay<ConferenceUpdates> { get }
    var inConferenceCalls: PublishSubject<CallModel> { get }
    
    func shouldCallBeAddedToConference(callId: String) -> String?
    func clearPendingConferences(callId: String) async
    func updateConferences(callId: String) async
    
    // Event handlers
    func handleConferenceCreated(conferenceId: String, conversationId: String, accountId: String) async
    func handleConferenceChanged(conference conferenceID: String, accountId: String, state: String) async
    func handleConferenceRemoved(conference conferenceID: String) async
    func handleConferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) async
}

enum ConferenceState: String {
    case conferenceCreated
    case conferenceDestroyed
    case infoUpdated
}

typealias ConferenceUpdates = (conferenceID: String, state: String, calls: Set<String>)

class ConferenceManagementService: ConferenceManaging {
    // MARK: - Properties
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>

    private let pendingConferencesRelay = BehaviorRelay<PendingConferencesType>(value: [:])
    let createdConferencesRelay = BehaviorRelay<Set<String>>(value: [])
    private let conferenceInfosRelay = BehaviorRelay<ConferenceInfosType>(value: [:])
    
    private let queueHelper: ThreadSafeQueueHelper
    
    private let disposeBag = DisposeBag()
    
    let inConferenceCalls = PublishSubject<CallModel>()
    let currentConferenceEvent: BehaviorRelay<ConferenceUpdates>

    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        queueHelper: ThreadSafeQueueHelper
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.queueHelper = queueHelper
        self.currentConferenceEvent = BehaviorRelay<ConferenceUpdates>(value: ("", "", Set<String>()))
    }
    
    // MARK: - Conference Management

    func joinConference(confID: String, callID: String) async {
        guard let secondConf = calls.value[callID],
              let firstConf = calls.value[confID] else { return }
        
        await updatePendingConferences(mainCallId: confID, callToAdd: callID)
        
        if secondConf.participantsCallId.count == 1 {
            callsAdapter.joinConference(confID, call: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        } else {
            callsAdapter.joinConferences(confID, secondConference: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        }
    }

    func joinCall(firstCallId: String, secondCallId: String) async {
        guard let firstCall = calls.value[firstCallId],
              let secondCall = calls.value[secondCallId] else { return }
        
        await updatePendingConferences(mainCallId: firstCallId, callToAdd: secondCallId)
        callsAdapter.joinCall(firstCallId, second: secondCallId, accountId: firstCall.accountId, account2Id: secondCall.accountId)
    }

    func addCall(call: CallModel, to callId: String) async {
        await updatePendingConferences(mainCallId: callId, callToAdd: call.callId)
        self.inConferenceCalls.onNext(call)
    }

    func hangUpCallOrConference(callId: String) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create()
            }
            
            guard let call = self.calls.value[callId] else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create()
            }
            
            let success = call.participantsCallId.count < 2 
                ? self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
                : self.callsAdapter.hangUpConference(callId, accountId: call.accountId)
            
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.hangUpCallFailed))
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Participant Management
    
    /// Checks if a participant is active in a conference
    /// - Returns: true if the participant is active, false if not, nil if no participant
    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool? {
        guard let uri = participantURI else { return false }
              guard let participants = conferenceInfosRelay.value[conferenceId] else {
            guard let participantsArray = callsAdapter.getConferenceInfo(conferenceId, accountId: accountId) as? [[String: String]] else {
                return nil
            }

            let normalizedURI = uri.filterOutHost()
            for participant in participantsArray {
                if let participantURI = participant["uri"]?.filterOutHost(),
                   participantURI == normalizedURI {
                    return ConferenceParticipant(info: participant, onlyURIAndActive: true).isActive
                }
            }
            
            return nil
        }
        
        let normalizedURI = uri.filterOutHost()
        return participants.first(where: { $0.uri?.filterOutHost() == normalizedURI })?.isActive
    }

    func isModerator(participantId: String, inConference confId: String) -> Bool {
        guard let participants = conferenceInfosRelay.value[confId] else { return false }
        
        return participants.first(where: { 
            $0.uri?.filterOutHost() == participantId.filterOutHost() 
        })?.isModerator ?? false
    }
    

    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]? {
        return conferenceInfosRelay.value[conferenceId]
    }

    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) async {
        return await withCheckedContinuation { continuation in
            queueHelper.safeSync {
                guard let conference = self.calls.value[conferenceId],
                      let isActive = self.isParticipant(participantURI: jamiId, activeIn: conferenceId, accountId: conference.accountId) else { 
                    continuation.resume()
                    return 
                }
                
                let newLayout = isActive ? self.getNewLayoutForActiveParticipant(currentLayout: conference.layout, maximixe: maximixe) : .oneWithSmal
                conference.layout = newLayout
                
                self.callsAdapter.setActiveParticipant(jamiId, forConference: conferenceId, accountId: conference.accountId)
                self.callsAdapter.setConferenceLayout(newLayout.rawValue, forConference: conferenceId, accountId: conference.accountId)
                continuation.resume()
            }
        }
    }

    func setModeratorParticipant(confId: String, participantId: String, active: Bool) async {
        return await withCheckedContinuation { continuation in
            guard let conference = calls.value[confId] else { 
                continuation.resume()
                return 
            }
            callsAdapter.setConferenceModerator(participantId, forConference: confId, accountId: conference.accountId, active: active)
            continuation.resume()
        }
    }

    func hangupParticipant(confId: String, participantId: String, device: String) async {
        return await withCheckedContinuation { continuation in
            guard let conference = calls.value[confId] else { 
                continuation.resume()
                return 
            }
            callsAdapter.hangupConferenceParticipant(participantId, forConference: confId, accountId: conference.accountId, deviceId: device)
            continuation.resume()
        }
    }

    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) async {
        return await withCheckedContinuation { continuation in
            callsAdapter.muteStream(participantId, forConference: confId, accountId: accountId, deviceId: device, streamId: streamId, state: state)
            continuation.resume()
        }
    }

    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) async {
        return await withCheckedContinuation { continuation in
            callsAdapter.raiseHand(participantId, forConference: confId, accountId: accountId, deviceId: deviceId, state: state)
            continuation.resume()
        }
    }
    
    // MARK: - Conference State Management

    func updateConferences(callId: String) async {
        return await withCheckedContinuation { continuation in
            queueHelper.barrierAsync {
                let updatedCalls = self.calls.value

                let conferencesWithCall = updatedCalls.keys.filter { conferenceId -> Bool in
                    guard let callModel = updatedCalls[conferenceId] else { return false }
                    return callModel.participantsCallId.count > 1 && callModel.participantsCallId.contains(callId)
                }
                
                guard let conferenceId = conferencesWithCall.first,
                      let conference = updatedCalls[conferenceId] else { 
                    continuation.resume()
                    return 
                }
                
                let conferenceCalls = Set(self.callsAdapter.getConferenceCalls(conferenceId, accountId: conference.accountId))
                
                conference.participantsCallId = conferenceCalls
                
                for callId in conferenceCalls {
                    if let call = updatedCalls[callId] {
                        call.participantsCallId = conferenceCalls
                    }
                }
                
                self.calls.accept(updatedCalls)
                continuation.resume()
            }
        }
    }

    // MARK: - Conference Creation Flow
    
    /// Checks if any calls are attached to the conference
    private func getConferenceParticipants(conferenceId: String, accountId: String) -> Set<String> {
        return Set(self.callsAdapter.getConferenceCalls(conferenceId, accountId: accountId))
    }
    
    /// Registers a conference for later processing when no calls are attached yet
    private func registerEmptyConference(conferenceId: String) {
        var createdConferences = self.createdConferencesRelay.value
        createdConferences.insert(conferenceId)
        self.createdConferencesRelay.accept(createdConferences)
    }
    
    /// Marks a conference as being fully processed
    private func markConferenceAsProcessed(conferenceId: String) {
        var createdConferences = self.createdConferencesRelay.value
        createdConferences.remove(conferenceId)
        self.createdConferencesRelay.accept(createdConferences)
    }
    
    /// Finds the source call and identifies pending participants
    private func processPendingParticipants(
        conferenceId: String,
        conferenceCalls: Set<String>
    ) -> (sourceCallId: String?, updatedPendingConferences: [String: Set<String>]) {
        let pendingConferences = self.pendingConferencesRelay.value
        var updatedPendingConferences = pendingConferences
        var sourceCallId: String?
        
        for (callId, pendingSet) in pendingConferences {
            if conferenceCalls.contains(callId) && !conferenceCalls.isDisjoint(with: pendingSet) {
                sourceCallId = callId
                
                // Identify which invited participants haven't joined yet
                var waitingParticipants = pendingSet
                waitingParticipants.subtract(conferenceCalls)
                
                // Update pending conferences tracking
                updatedPendingConferences[callId] = nil
                if !waitingParticipants.isEmpty {
                    updatedPendingConferences[conferenceId] = waitingParticipants
                }
                break
            }
        }
        
        return (sourceCallId, updatedPendingConferences)
    }
    
    /// Links all current participants to the conference
    private func linkParticipantsToConference(conferenceCalls: Set<String>) {
        for callId in conferenceCalls {
            if let call = self.calls.value[callId] {
                call.participantsCallId = conferenceCalls
            }
        }
    }
    
    /// Creates a unified conference object for all participants
    private func createConferenceObject(
        conferenceId: String, 
        sourceCallId: String,
        conferenceCalls: Set<String>,
        accountId: String
    ) -> Bool {
        guard let sourceCall = self.calls.value[sourceCallId],
              var callDetails = self.callsAdapter.getConferenceDetails(conferenceId, accountId: accountId) else {
            return false
        }
        
        // Preserve settings from the original call
        callDetails[CallDetailKey.accountIdKey.rawValue] = sourceCall.accountId
        callDetails[CallDetailKey.audioOnlyKey.rawValue] = sourceCall.isAudioOnly.toString()
        
        // Create the conference model
        let conferenceModel = CallModel(withCallId: conferenceId, callDetails: callDetails, withMedia: [[String: String]]())
        conferenceModel.participantsCallId = conferenceCalls
        
        // Add the conference to the calls dictionary
        var updatedCalls = self.calls.value
        updatedCalls[conferenceId] = conferenceModel
        self.calls.accept(updatedCalls)
        
        return true
    }
    
    /// Notifies the system that the conference is ready
    private func notifyConferenceReady(conferenceId: String, conferenceCalls: Set<String>) {
        self.currentConferenceEvent.accept((conferenceId, ConferenceState.conferenceCreated.rawValue, conferenceCalls))
    }
    
    /// Updates pending participant tracking
    private func updatePendingParticipantsTracking(updatedPendingConferences: [String: Set<String>]) {
        let pendingConferences = self.pendingConferencesRelay.value
        if updatedPendingConferences != pendingConferences {
            self.pendingConferencesRelay.accept(updatedPendingConferences)
        }
    }

    func handleConferenceCreated(conferenceId: String, conversationId: String, accountId: String) async {
        return await withCheckedContinuation { continuation in
            queueHelper.barrierAsync {
                // 1. Check if any calls are attached to the conference
                let conferenceCalls = self.getConferenceParticipants(conferenceId: conferenceId, accountId: accountId)
                
                // 2. If no calls yet, register the conference and wait
                if conferenceCalls.isEmpty {
                    self.registerEmptyConference(conferenceId: conferenceId)
                    continuation.resume()
                    return
                }

                // 3. Mark conference as being processed
                self.markConferenceAsProcessed(conferenceId: conferenceId)

                // 4-5. Process pending participants and get source call
                let (sourceCallId, updatedPendingConferences) = self.processPendingParticipants(
                    conferenceId: conferenceId,
                    conferenceCalls: conferenceCalls
                )
                
                // 6. Link all participants to the conference
                self.linkParticipantsToConference(conferenceCalls: conferenceCalls)
                
                // 7. Create unified conference object
                var conferenceCreated = false
                if let sourceId = sourceCallId {
                    conferenceCreated = self.createConferenceObject(
                        conferenceId: conferenceId,
                        sourceCallId: sourceId,
                        conferenceCalls: conferenceCalls,
                        accountId: accountId
                    )
                }
                
                // 8. Notify system that conference is ready (only if we successfully created the model)
                if conferenceCreated {
                    self.notifyConferenceReady(conferenceId: conferenceId, conferenceCalls: conferenceCalls)
                }
                
                // Update pending participants tracking
                self.updatePendingParticipantsTracking(updatedPendingConferences: updatedPendingConferences)
                
                continuation.resume()
            }
        }
    }

    func handleConferenceChanged(conference conferenceId: String, accountId: String, state: String) async {
        return await withCheckedContinuation { continuation in
            queueHelper.barrierAsync {
                // Check if it's a newly created conference that needs processing
                let createdConferences = self.createdConferencesRelay.value
                if createdConferences.contains(conferenceId) {
                    continuation.resume()
                    Task {
                        await self.handleConferenceCreated(conferenceId: conferenceId, conversationId: "", accountId: accountId)
                    }
                    return
                }
                
                // Handle participant_attached state for swarm calls
                if state == "ACTIVE_ATTACHED" {
                    if let call = self.calls.value[conferenceId] {
                        // For swarm calls, when a participant is attached, update the call state
                        if call.state == .connecting {
                            call.state = .current
                        }
                    }
                    // Notify about the conference state update
                    self.currentConferenceEvent.accept((conferenceId, state, [""]))
                    continuation.resume()
                    return
                }
                
                let updatedCalls = self.calls.value
                guard let conference = updatedCalls[conferenceId] else { 
                    continuation.resume()
                    return 
                }
                
                let conferenceCalls = Set(self.callsAdapter.getConferenceCalls(conferenceId, accountId: conference.accountId))
                
                conference.participantsCallId = conferenceCalls
                
                for callId in conferenceCalls {
                    if let call = updatedCalls[callId] {
                        call.participantsCallId = conferenceCalls
                    }
                }
                
                self.calls.accept(updatedCalls)
                
                // Notify about the conference state update
                self.currentConferenceEvent.accept((conferenceId, state, conferenceCalls))
                
                continuation.resume()
            }
        }
    }

    func handleConferenceRemoved(conference conferenceId: String) async {
        return await withCheckedContinuation { continuation in
            queueHelper.barrierAsync {
                guard let conference = self.calls.value[conferenceId] else {
                    continuation.resume()
                    return
                }
                
                let participantCallIds = conference.participantsCallId
                
                var conferenceInfos = self.conferenceInfosRelay.value
                conferenceInfos.removeValue(forKey: conferenceId)
                self.conferenceInfosRelay.accept(conferenceInfos)
                
                var pendingConferences = self.pendingConferencesRelay.value
                pendingConferences[conferenceId] = nil
                
                var updatedEntries = [String: Set<String>]()
                var keysToRemove = [String]()

                for (callId, pendingCalls) in pendingConferences {
                    if pendingCalls.contains(conferenceId) {
                        var updatedCalls = pendingCalls
                        updatedCalls.remove(conferenceId)
                        
                        if updatedCalls.isEmpty {
                            keysToRemove.append(callId)
                        } else {
                            updatedEntries[callId] = updatedCalls
                        }
                    }
                }
                
                for (callId, updatedCalls) in updatedEntries {
                    pendingConferences[callId] = updatedCalls
                }
                
                for keyToRemove in keysToRemove {
                    pendingConferences.removeValue(forKey: keyToRemove)
                }
                
                self.pendingConferencesRelay.accept(pendingConferences)
                
                // Update created conferences
                var createdConferences = self.createdConferencesRelay.value
                createdConferences.remove(conferenceId)
                self.createdConferencesRelay.accept(createdConferences)
                
                // Notify about conference state changes
                self.currentConferenceEvent.accept((conferenceId, ConferenceState.infoUpdated.rawValue, [""]))
                self.currentConferenceEvent.accept((conferenceId, ConferenceState.conferenceDestroyed.rawValue, participantCallIds))
                
                // Remove conference from calls dictionary
                var updatedCalls = self.calls.value
                updatedCalls[conferenceId] = nil
                self.calls.accept(updatedCalls)
                
                continuation.resume()
            }
        }
    }

    func handleConferenceInfoUpdated(conference conferenceId: String, info: [[String: String]]) async {
        return await withCheckedContinuation { continuation in
            queueHelper.barrierAsync {
                let participants = self.arrayToConferenceParticipants(participants: info, onlyURIAndActive: false)
                
                // Update conference infos relay
                var conferenceInfos = self.conferenceInfosRelay.value
                let previousParticipants = conferenceInfos[conferenceId] ?? []
                conferenceInfos[conferenceId] = participants
                self.conferenceInfosRelay.accept(conferenceInfos)
                
                // For swarm calls, determine if this is a participant_attached event
                let participantAttached = previousParticipants.count < participants.count
                
                // For swarm calls, when a new participant is attached, we need to update call state
                if participantAttached, 
                   let call = self.calls.value[conferenceId],
                   participants.count > 1 {
                    // Update call state if it's still connecting
                    if call.state == .connecting {
                        call.state = .current
                    }
                }
                
                self.currentConferenceEvent.accept((conferenceId, ConferenceState.infoUpdated.rawValue, [""]))
                
                continuation.resume()
            }
        }
    }

    func clearPendingConferences(callId: String) async {
        return await withCheckedContinuation { continuation in
            queueHelper.barrierAsync {
                var pendingConferences = self.pendingConferencesRelay.value
                pendingConferences[callId] = nil
                
                var updatedEntries = [String: Set<String>]()
                var keysToRemove = [String]()
                
                for (conferenceId, pendingCalls) in pendingConferences {
                    if pendingCalls.contains(callId) {
                        var updatedCalls = pendingCalls
                        updatedCalls.remove(callId)
                        
                        if updatedCalls.isEmpty {
                            keysToRemove.append(conferenceId)
                        } else {
                            updatedEntries[conferenceId] = updatedCalls
                        }
                    }
                }
                
                for (conferenceId, updatedCalls) in updatedEntries {
                    pendingConferences[conferenceId] = updatedCalls
                }
                
                for keyToRemove in keysToRemove {
                    pendingConferences.removeValue(forKey: keyToRemove)
                }
                
                self.pendingConferencesRelay.accept(pendingConferences)
                continuation.resume()
            }
        }
    }

    func shouldCallBeAddedToConference(callId: String) -> String? {
        let pendingConferences = pendingConferencesRelay.value
        
        for (conferenceId, pendingCalls) in pendingConferences {
            if !pendingCalls.isEmpty && pendingCalls.contains(callId) {
                return conferenceId
            }
        }
        
        return nil
    }

    private func updatePendingConferences(mainCallId: String, callToAdd: String) async {
        return await withCheckedContinuation { continuation in
            queueHelper.safeSync {
                var pendingConferences = self.pendingConferencesRelay.value
                
                if var pendingCalls = pendingConferences[mainCallId] {
                    pendingCalls.insert(callToAdd)
                    pendingConferences[mainCallId] = pendingCalls
                } else {
                    pendingConferences[mainCallId] = [callToAdd]
                }
                
                self.pendingConferencesRelay.accept(pendingConferences)
                continuation.resume()
            }
        }
    }

    private func getNewLayoutForActiveParticipant(currentLayout: CallLayout, maximixe: Bool) -> CallLayout {
        switch currentLayout {
        case .grid:
            return .oneWithSmal
        case .oneWithSmal:
            return maximixe ? .one : .grid
        case .one:
            return .oneWithSmal
        }
    }

    private func arrayToConferenceParticipants(participants: [[String: String]], onlyURIAndActive: Bool) -> [ConferenceParticipant] {
        return participants.map { ConferenceParticipant(info: $0, onlyURIAndActive: onlyURIAndActive) }
    }
}
