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
    private var pendingConferences: PendingConferencesType = [:]
    private var createdConferences = Set<String>()
    private var conferenceInfos: ConferenceInfosType = [:]
    private let disposeBag = DisposeBag()
    
    let inConferenceCalls = PublishSubject<CallModel>()
    let currentConferenceEvent: BehaviorRelay<ConferenceUpdates>
    
    // MARK: - Initialization
    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls
        self.currentConferenceEvent = BehaviorRelay<ConferenceUpdates>(value: ("", "", Set<String>()))
    }
    
    // MARK: - Conference Management
    func joinConference(confID: String, callID: String) {
        guard let secondConf = calls.value[callID],
              let firstConf = calls.value[confID] else { return }
        
        updatePendingConferences(mainCallId: confID, callToAdd: callID)
        
        if secondConf.participantsCallId.count == 1 {
            callsAdapter.joinConference(confID, call: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        } else {
            callsAdapter.joinConferences(confID, secondConference: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        }
    }
    
    func joinCall(firstCallId: String, secondCallId: String) {
        guard let firstCall = calls.value[firstCallId],
              let secondCall = calls.value[secondCallId] else { return }
        
        updatePendingConferences(mainCallId: firstCallId, callToAdd: secondCallId)
        callsAdapter.joinCall(firstCallId, second: secondCallId, accountId: firstCall.accountId, account2Id: secondCall.accountId)
    }
    
    func addCall(call: CallModel, to callId: String) {
        inConferenceCalls.onNext(call)
        updatePendingConferences(mainCallId: callId, callToAdd: call.callId)
    }
    
    func hangUpCallOrConference(callId: String) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self,
                  let call = self.calls.value[callId] else {
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
    
    func isModerator(participantId: String, inConference confId: String) -> Bool {
        guard let participants = conferenceInfos[confId] else { return false }
        
        return participants.first(where: { 
            $0.uri?.filterOutHost() == participantId.filterOutHost() 
        })?.isModerator ?? false
    }
    
    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]? {
        return conferenceInfos[conferenceId]
    }
    
    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) {
        guard let conference = calls.value[conferenceId],
              let isActive = isParticipant(participantURI: jamiId, activeIn: conferenceId, accountId: conference.accountId) else { 
            return 
        }
        
        let newLayout = isActive ? getNewLayoutForActiveParticipant(currentLayout: conference.layout, maximixe: maximixe) : .oneWithSmal
        conference.layout = newLayout
        
        callsAdapter.setActiveParticipant(jamiId, forConference: conferenceId, accountId: conference.accountId)
        callsAdapter.setConferenceLayout(newLayout.rawValue, forConference: conferenceId, accountId: conference.accountId)
    }
    
    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        guard let conference = calls.value[confId] else { return }
        callsAdapter.setConferenceModerator(participantId, forConference: confId, accountId: conference.accountId, active: active)
    }
    
    func hangupParticipant(confId: String, participantId: String, device: String) {
        guard let conference = calls.value[confId] else { return }
        callsAdapter.hangupConferenceParticipant(participantId, forConference: confId, accountId: conference.accountId, deviceId: device)
    }
    
    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        callsAdapter.muteStream(participantId, forConference: confId, accountId: accountId, deviceId: device, streamId: streamId, state: state)
    }
    
    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        callsAdapter.raiseHand(participantId, forConference: confId, accountId: accountId, deviceId: deviceId, state: state)
    }
    
    // MARK: - Conference State Management
    func updateConferences(callId: String) {
        let updatedCalls = calls.value

        let conferencesWithCall = updatedCalls.keys.filter { conferenceId -> Bool in
            guard let callModel = updatedCalls[conferenceId] else { return false }
            return callModel.participantsCallId.count > 1 && callModel.participantsCallId.contains(callId)
        }
        
        guard let conferenceId = conferencesWithCall.first,
              let conference = updatedCalls[conferenceId] else { 
            return 
        }
        
        let conferenceCalls = Set(callsAdapter.getConferenceCalls(conferenceId, accountId: conference.accountId))
        
        conference.participantsCallId = conferenceCalls
        
        for callId in conferenceCalls {
            if let call = updatedCalls[callId] {
                call.participantsCallId = conferenceCalls
            }
        }
        
        calls.accept(updatedCalls)
    }
    
    func handleConferenceCreated(conference conferenceId: String, accountId: String) {
        let conferenceCalls = Set(callsAdapter.getConferenceCalls(conferenceId, accountId: accountId))
        
        if conferenceCalls.isEmpty {
            createdConferences.insert(conferenceId)
            return
        }
        
        createdConferences.remove(conferenceId)
        
        for (callId, pendingSet) in pendingConferences {
            if !conferenceCalls.contains(callId) || conferenceCalls.isDisjoint(with: pendingSet) {
                continue
            }
            
            var remainingCalls = pendingSet
            remainingCalls.subtract(conferenceCalls)
            pendingConferences[callId] = nil
            
            if !remainingCalls.isEmpty {
                pendingConferences[conferenceId] = remainingCalls
            }
            
            calls.value[callId]?.participantsCallId = conferenceCalls
            pendingSet.forEach { callId in
                calls.value[callId]?.participantsCallId = conferenceCalls
            }
            
            guard var callDetails = callsAdapter.getConferenceDetails(conferenceId, accountId: accountId) else { 
                return 
            }
            
            callDetails[CallDetailKey.accountIdKey.rawValue] = calls.value[callId]?.accountId
            callDetails[CallDetailKey.audioOnlyKey.rawValue] = calls.value[callId]?.isAudioOnly.toString()
            
            let mediaList = [[String: String]]()
            let conferenceModel = CallModel(withCallId: conferenceId, callDetails: callDetails, withMedia: mediaList)
            conferenceModel.participantsCallId = conferenceCalls
            
            var updatedCalls = calls.value
            updatedCalls[conferenceId] = conferenceModel
            calls.accept(updatedCalls)
            
            currentConferenceEvent.accept((conferenceId, ConferenceState.conferenceCreated.rawValue, conferenceCalls))
        }
    }
    
    func handleConferenceChanged(conference conferenceId: String, accountId: String, state: String) {
        if createdConferences.contains(conferenceId) {
            handleConferenceCreated(conference: conferenceId, accountId: accountId)
            return
        }
        
        let updatedCalls = calls.value

        guard let conference = updatedCalls[conferenceId] else { return }
        
        let conferenceCalls = Set(callsAdapter.getConferenceCalls(conferenceId, accountId: conference.accountId))
        
        conference.participantsCallId = conferenceCalls
        
        for callId in conferenceCalls {
            if let call = updatedCalls[callId] {
                call.participantsCallId = conferenceCalls
            }
        }
        
        calls.accept(updatedCalls)
    }
    
    func handleConferenceRemoved(conference conferenceId: String) {
        guard let conference = calls.value[conferenceId] else { return }
        
        let participantCallIds = conference.participantsCallId
        
        conferenceInfos[conferenceId] = nil
        
        pendingConferences[conferenceId] = nil

        for (callId, pendingCalls) in pendingConferences {
            if pendingCalls.contains(conferenceId) {
                var updatedCalls = pendingCalls
                updatedCalls.remove(conferenceId)
                
                if updatedCalls.isEmpty {
                    pendingConferences.removeValue(forKey: callId)
                } else {
                    pendingConferences[callId] = updatedCalls
                }
            }
        }
        
        currentConferenceEvent.accept((conferenceId, ConferenceState.infoUpdated.rawValue, [""]))
        currentConferenceEvent.accept((conferenceId, ConferenceState.conferenceDestroyed.rawValue, participantCallIds))
        
        var updatedCalls = calls.value
        updatedCalls[conferenceId] = nil
        calls.accept(updatedCalls)
    }
    
    func handleConferenceInfoUpdated(conference conferenceId: String, info: [[String: String]]) {
        let participants = arrayToConferenceParticipants(participants: info, onlyURIAndActive: false)
        conferenceInfos[conferenceId] = participants
        currentConferenceEvent.accept((conferenceId, ConferenceState.infoUpdated.rawValue, [""]))
    }
    
    func clearPendingConferences(callId: String) {
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
    }
    
    func shouldCallBeAddedToConference(callId: String) -> String? {
        for (conferenceId, pendingCalls) in pendingConferences {
            if !pendingCalls.isEmpty && pendingCalls.contains(callId) {
                return conferenceId
            }
        }
        return nil
    }
    
    // MARK: - Helper Methods
    private func updatePendingConferences(mainCallId: String, callToAdd: String) {
        if var pendingCalls = pendingConferences[mainCallId] {
            pendingCalls.insert(callToAdd)
            pendingConferences[mainCallId] = pendingCalls
        } else {
            pendingConferences[mainCallId] = [callToAdd]
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
