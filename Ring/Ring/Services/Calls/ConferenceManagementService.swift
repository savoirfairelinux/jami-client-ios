import RxSwift
import RxRelay

// Interface for conference management
protocol ConferenceManaging {
    func joinConference(confID: String, callID: String)
    func joinCall(firstCallId: String, secondCallId: String)
    func addCall(call: CallModel, to callId: String)
    func hangUpCallOrConference(callId: String) -> Completable
    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool?
    func isModerator(participantId: String, inConference confId: String) -> Bool
    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]?
    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String)
    func setModeratorParticipant(confId: String, participantId: String, active: Bool)
    func hangupParticipant(confId: String, participantId: String, device: String)
    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool)
    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String)

    var currentConferenceEvent: BehaviorRelay<ConferenceUpdates> { get }
    func shouldCallBeAddedToConference(callId: String) -> String?
    func clearPendingConferences(callId: String)
    func updateConferences(callId: String)
    
    // Event handlers
    func handleConferenceCreated(conference conferenceID: String, accountId: String)
    func handleConferenceChanged(conference conferenceID: String, accountId: String, state: String)
    func handleConferenceRemoved(conference conferenceID: String)
    func handleConferenceInfoUpdated(conference conferenceID: String, info: [[String: String]])
}

/// Represents the state of a conference
enum ConferenceState: String {
    case conferenceCreated
    case conferenceDestroyed
    case infoUpdated
}

/// Type alias for conference update information
typealias ConferenceUpdates = (conferenceID: String, state: String, calls: Set<String>)

/// Service responsible for managing conference calls
class ConferenceManagementService: ConferenceManaging {
    // MARK: - Properties
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    private var pendingConferences: PendingConferencesType = [:]
    private var createdConferences = Set<String>()
    private var conferenceInfos: ConferenceInfosType = [:]
    private let disposeBag = DisposeBag()
    private let callsQueue: DispatchQueue
    
    // Used to track if we're already inside a callsQueue block
    private let queueKey = DispatchSpecificKey<Bool>()
    
    let inConferenceCalls = PublishSubject<CallModel>()
    let currentConferenceEvent: BehaviorRelay<ConferenceUpdates>
    
    // MARK: - Initialization
    
    /// Initialize the conference management service
    /// - Parameters:
    ///   - callsAdapter: The adapter for interacting with the native call service
    ///   - calls: The behavior relay containing all calls
    ///   - callsQueue: The shared dispatch queue for thread-safe call operations
    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>,
        callsQueue: DispatchQueue
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.callsQueue = callsQueue
        self.currentConferenceEvent = BehaviorRelay<ConferenceUpdates>(value: ("", "", Set<String>()))
        
        // Set up queue key for deadlock prevention
        callsQueue.setSpecific(key: queueKey, value: true)
    }
    
    // MARK: - Conference Management
    
    /// Joins a call to a conference
    /// - Parameters:
    ///   - confID: The conference ID
    ///   - callID: The call ID to join
    func joinConference(confID: String, callID: String) {
        // Reading from BehaviorRelay is thread-safe
        guard let secondConf = calls.value[callID],
              let firstConf = calls.value[confID] else { return }
        
        updatePendingConferences(mainCallId: confID, callToAdd: callID)
        
        if secondConf.participantsCallId.count == 1 {
            callsAdapter.joinConference(confID, call: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        } else {
            callsAdapter.joinConferences(confID, secondConference: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        }
    }
    
    /// Joins two calls together
    /// - Parameters:
    ///   - firstCallId: The first call ID
    ///   - secondCallId: The second call ID
    func joinCall(firstCallId: String, secondCallId: String) {
        // Reading from BehaviorRelay is thread-safe
        guard let firstCall = calls.value[firstCallId],
              let secondCall = calls.value[secondCallId] else { return }
        
        updatePendingConferences(mainCallId: firstCallId, callToAdd: secondCallId)
        callsAdapter.joinCall(firstCallId, second: secondCallId, accountId: firstCall.accountId, account2Id: secondCall.accountId)
    }
    
    /// Adds a call to a conference
    /// - Parameters:
    ///   - call: The call to add
    ///   - callId: The ID of the conference call
    func addCall(call: CallModel, to callId: String) {
        callsQueue.async(flags: .barrier) {
            self.updatePendingConferences(mainCallId: callId, callToAdd: call.callId)
        }
        self.inConferenceCalls.onNext(call)
    }
    
    /// Hangs up a call or conference
    /// - Parameter callId: The ID of the call or conference
    /// - Returns: A Completable that completes when the operation is done
    func hangUpCallOrConference(callId: String) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create()
            }
            
            // Reading from BehaviorRelay is thread-safe
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
    /// - Parameters:
    ///   - participantURI: The URI of the participant
    ///   - conferenceId: The ID of the conference
    ///   - accountId: The account ID
    /// - Returns: true if the participant is active, false if not, nil if unknown
    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool? {
        guard let uri = participantURI,
              let participantsArray = callsAdapter.getConferenceInfo(conferenceId, accountId: accountId) as? [[String: String]] else { 
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
    
    /// Checks if a participant is a moderator in a conference
    /// - Parameters:
    ///   - participantId: The ID of the participant
    ///   - confId: The ID of the conference
    /// - Returns: true if the participant is a moderator, false otherwise
    func isModerator(participantId: String, inConference confId: String) -> Bool {
        guard let participants = getConferenceParticipants(for: confId) else { return false }
        
        return participants.first(where: { 
            $0.uri?.filterOutHost() == participantId.filterOutHost() 
        })?.isModerator ?? false
    }
    
    /// Gets the participants in a conference
    /// - Parameter conferenceId: The ID of the conference
    /// - Returns: The participants if found, nil otherwise
    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]? {
        return conferenceInfos[conferenceId]
    }
    
    /// Sets the active participant in a conference
    /// - Parameters:
    ///   - conferenceId: The ID of the conference
    ///   - maximixe: Whether to maximize the participant
    ///   - jamiId: The ID of the participant
    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) {
        // We need to protect access to the call object since its properties are modified
        callsQueue.async(flags: .barrier) {
            guard let conference = self.calls.value[conferenceId],
                  let isActive = self.isParticipant(participantURI: jamiId, activeIn: conferenceId, accountId: conference.accountId) else { 
                return 
            }
            
            let newLayout = isActive ? self.getNewLayoutForActiveParticipant(currentLayout: conference.layout, maximixe: maximixe) : .oneWithSmal
            conference.layout = newLayout
            
            self.callsAdapter.setActiveParticipant(jamiId, forConference: conferenceId, accountId: conference.accountId)
            self.callsAdapter.setConferenceLayout(newLayout.rawValue, forConference: conferenceId, accountId: conference.accountId)
        }
    }
    
    /// Sets a participant as a moderator
    /// - Parameters:
    ///   - confId: The ID of the conference
    ///   - participantId: The ID of the participant
    ///   - active: Whether to set as moderator
    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        // Reading from BehaviorRelay is thread-safe
        guard let conference = calls.value[confId] else { return }
        callsAdapter.setConferenceModerator(participantId, forConference: confId, accountId: conference.accountId, active: active)
    }
    
    /// Hangs up a participant in a conference
    /// - Parameters:
    ///   - confId: The ID of the conference
    ///   - participantId: The ID of the participant
    ///   - device: The device ID
    func hangupParticipant(confId: String, participantId: String, device: String) {
        // Reading from BehaviorRelay is thread-safe
        guard let conference = calls.value[confId] else { return }
        callsAdapter.hangupConferenceParticipant(participantId, forConference: confId, accountId: conference.accountId, deviceId: device)
    }
    
    /// Mutes a stream in a conference
    /// - Parameters:
    ///   - confId: The ID of the conference
    ///   - participantId: The ID of the participant
    ///   - device: The device ID
    ///   - accountId: The account ID
    ///   - streamId: The stream ID
    ///   - state: The mute state
    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        callsAdapter.muteStream(participantId, forConference: confId, accountId: accountId, deviceId: device, streamId: streamId, state: state)
    }
    
    /// Sets the raise hand state for a participant
    /// - Parameters:
    ///   - confId: The ID of the conference
    ///   - participantId: The ID of the participant
    ///   - state: The raise hand state
    ///   - accountId: The account ID
    ///   - deviceId: The device ID
    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        callsAdapter.raiseHand(participantId, forConference: confId, accountId: accountId, deviceId: deviceId, state: state)
    }
    
    // MARK: - Conference State Management
    
    /// Updates conferences containing a call
    /// - Parameter callId: The ID of the call
    func updateConferences(callId: String) {
        callsQueue.async(flags: .barrier) {
            let updatedCalls = self.calls.value

            let conferencesWithCall = updatedCalls.keys.filter { conferenceId -> Bool in
                guard let callModel = updatedCalls[conferenceId] else { return false }
                return callModel.participantsCallId.count > 1 && callModel.participantsCallId.contains(callId)
            }
            
            guard let conferenceId = conferencesWithCall.first,
                  let conference = updatedCalls[conferenceId] else { 
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
        }
    }
    
    /// Handles when a conference is created
    /// - Parameters:
    ///   - conference: The ID of the conference
    ///   - accountId: The account ID
    func handleConferenceCreated(conference conferenceId: String, accountId: String) {
        callsQueue.async(flags: .barrier) {
            let conferenceCalls = Set(self.callsAdapter.getConferenceCalls(conferenceId, accountId: accountId))
            
            if conferenceCalls.isEmpty {
                self.createdConferences.insert(conferenceId)
                return
            }
            
            self.createdConferences.remove(conferenceId)
            
            for (callId, pendingSet) in self.pendingConferences {
                if !conferenceCalls.contains(callId) || conferenceCalls.isDisjoint(with: pendingSet) {
                    continue
                }
                
                var remainingCalls = pendingSet
                remainingCalls.subtract(conferenceCalls)
                self.pendingConferences[callId] = nil
                
                if !remainingCalls.isEmpty {
                    self.pendingConferences[conferenceId] = remainingCalls
                }
                
                self.calls.value[callId]?.participantsCallId = conferenceCalls
                pendingSet.forEach { callId in
                    self.calls.value[callId]?.participantsCallId = conferenceCalls
                }
                
                guard var callDetails = self.callsAdapter.getConferenceDetails(conferenceId, accountId: accountId) else { 
                    return 
                }
                
                callDetails[CallDetailKey.accountIdKey.rawValue] = self.calls.value[callId]?.accountId
                callDetails[CallDetailKey.audioOnlyKey.rawValue] = self.calls.value[callId]?.isAudioOnly.toString()
                
                let mediaList = [[String: String]]()
                let conferenceModel = CallModel(withCallId: conferenceId, callDetails: callDetails, withMedia: mediaList)
                conferenceModel.participantsCallId = conferenceCalls
                
                var updatedCalls = self.calls.value
                updatedCalls[conferenceId] = conferenceModel
                self.calls.accept(updatedCalls)
                
                self.currentConferenceEvent.accept((conferenceId, ConferenceState.conferenceCreated.rawValue, conferenceCalls))
            }
        }
    }
    
    /// Handles when a conference is changed
    /// - Parameters:
    ///   - conference: The ID of the conference
    ///   - accountId: The account ID
    ///   - state: The state of the conference
    func handleConferenceChanged(conference conferenceId: String, accountId: String, state: String) {
        callsQueue.async(flags: .barrier) {
            if self.createdConferences.contains(conferenceId) {
                self.handleConferenceCreated(conference: conferenceId, accountId: accountId)
                return
            }
            
            let updatedCalls = self.calls.value

            guard let conference = updatedCalls[conferenceId] else { return }
            
            let conferenceCalls = Set(self.callsAdapter.getConferenceCalls(conferenceId, accountId: conference.accountId))
            
            conference.participantsCallId = conferenceCalls
            
            for callId in conferenceCalls {
                if let call = updatedCalls[callId] {
                    call.participantsCallId = conferenceCalls
                }
            }
            
            self.calls.accept(updatedCalls)
        }
    }
    
    /// Handles when a conference is removed
    /// - Parameter conference: The ID of the conference
    func handleConferenceRemoved(conference conferenceId: String) {
        callsQueue.async(flags: .barrier) {
            guard let conference = self.calls.value[conferenceId] else { return }
            
            let participantCallIds = conference.participantsCallId
            
            self.conferenceInfos[conferenceId] = nil
            
            self.pendingConferences[conferenceId] = nil

            for (callId, pendingCalls) in self.pendingConferences {
                if pendingCalls.contains(conferenceId) {
                    var updatedCalls = pendingCalls
                    updatedCalls.remove(conferenceId)
                    
                    if updatedCalls.isEmpty {
                        self.pendingConferences.removeValue(forKey: callId)
                    } else {
                        self.pendingConferences[callId] = updatedCalls
                    }
                }
            }
            
            self.currentConferenceEvent.accept((conferenceId, ConferenceState.infoUpdated.rawValue, [""]))
            self.currentConferenceEvent.accept((conferenceId, ConferenceState.conferenceDestroyed.rawValue, participantCallIds))
            
            var updatedCalls = self.calls.value
            updatedCalls[conferenceId] = nil
            self.calls.accept(updatedCalls)
        }
    }
    
    /// Handles when conference info is updated
    /// - Parameters:
    ///   - conference: The ID of the conference
    ///   - info: The updated info
    func handleConferenceInfoUpdated(conference conferenceId: String, info: [[String: String]]) {
        callsQueue.async(flags: .barrier) {
            let participants = self.arrayToConferenceParticipants(participants: info, onlyURIAndActive: false)
            self.conferenceInfos[conferenceId] = participants
            self.currentConferenceEvent.accept((conferenceId, ConferenceState.infoUpdated.rawValue, [""]))
        }
    }
    
    /// Clears pending conferences for a call
    /// - Parameter callId: The ID of the call
    func clearPendingConferences(callId: String) {
        callsQueue.async(flags: .barrier) {
            self.pendingConferences[callId] = nil
            
            var updatedEntries = [String: Set<String>]()
            var keysToRemove = [String]()
            
            for (conferenceId, pendingCalls) in self.pendingConferences {
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
                self.pendingConferences[conferenceId] = updatedCalls
            }
            
            for keyToRemove in keysToRemove {
                self.pendingConferences.removeValue(forKey: keyToRemove)
            }
        }
    }
    
    /// Checks if a call should be added to a conference
    /// - Parameter callId: The ID of the call
    /// - Returns: The ID of the conference to add to, or nil if none
    func shouldCallBeAddedToConference(callId: String) -> String? {
        // Check if we're already on the callsQueue to avoid deadlocks
        if DispatchQueue.getSpecific(key: queueKey) == true {
            // Direct access when already on the queue
            for (conferenceId, pendingCalls) in pendingConferences {
                if !pendingCalls.isEmpty && pendingCalls.contains(callId) {
                    return conferenceId
                }
            }
            return nil
        } else {
            // Synchronize when accessing from another thread
            return callsQueue.sync {
                for (conferenceId, pendingCalls) in pendingConferences {
                    if !pendingCalls.isEmpty && pendingCalls.contains(callId) {
                        return conferenceId
                    }
                }
                return nil
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Updates pending conferences
    /// - Parameters:
    ///   - mainCallId: The main call ID
    ///   - callToAdd: The call to add
    private func updatePendingConferences(mainCallId: String, callToAdd: String) {
        callsQueue.async(flags: .barrier) {
            if var pendingCalls = self.pendingConferences[mainCallId] {
                pendingCalls.insert(callToAdd)
                self.pendingConferences[mainCallId] = pendingCalls
            } else {
                self.pendingConferences[mainCallId] = [callToAdd]
            }
        }
    }
    
    /// Gets the new layout for an active participant
    /// - Parameters:
    ///   - currentLayout: The current layout
    ///   - maximixe: Whether to maximize the participant
    /// - Returns: The new layout
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
    
    /// Converts an array of dictionaries to conference participants
    /// - Parameters:
    ///   - participants: The participant information
    ///   - onlyURIAndActive: Whether to only include URI and active state
    /// - Returns: The conference participants
    private func arrayToConferenceParticipants(participants: [[String: String]], onlyURIAndActive: Bool) -> [ConferenceParticipant] {
        return participants.map { ConferenceParticipant(info: $0, onlyURIAndActive: onlyURIAndActive) }
    }
}
