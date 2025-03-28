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

    // Added access methods for properties now owned by this service
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
    private let callsAdapter: CallsAdapter
    private let calls: BehaviorRelay<[String: CallModel]>
    // Conference properties moved from CallsService
    private var pendingConferences: PendingConferencesType = [:]
    private var createdConferences = Set<String>()
    let inConferenceCalls = PublishSubject<CallModel>()
    // Expose as read-only property to conform to the protocol
    let currentConferenceEvent: BehaviorRelay<ConferenceUpdates>
    private var conferenceInfos: ConferenceInfosType = [:]
    private let disposeBag = DisposeBag()

    init(
        callsAdapter: CallsAdapter,
        calls: BehaviorRelay<[String: CallModel]>
    ) {
        self.callsAdapter = callsAdapter
        self.calls = calls

        // Initialize conference-related properties
        self.pendingConferences = [:]
        self.createdConferences = Set<String>()
        self.currentConferenceEvent = BehaviorRelay<ConferenceUpdates>(value: ConferenceUpdates("", "", Set<String>()))
        self.conferenceInfos = [:]
    }

    func joinConference(confID: String, callID: String) {
        guard let secondConf = self.calls.value[callID] else { return }
        guard let firstConf = self.calls.value[confID] else { return }
        if var pending = self.pendingConferences[confID] {
            pending.insert(callID)
            self.pendingConferences[confID] = pending
        } else {
            self.pendingConferences[confID] = [callID]
        }
        if secondConf.participantsCallId.count == 1 {
            self.callsAdapter.joinConference(confID, call: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        } else {
            self.callsAdapter.joinConferences(confID, secondConference: callID, accountId: firstConf.accountId, account2Id: secondConf.accountId)
        }
    }

    func joinCall(firstCallId: String, secondCallId: String) {
        guard let firstCall = self.calls.value[firstCallId] else { return }
        guard let secondCall = self.calls.value[secondCallId] else { return }
        if var pending = self.pendingConferences[firstCallId] {
            pending.insert(secondCallId)
            self.pendingConferences[firstCallId] = pending
        } else {
            self.pendingConferences[firstCallId] = [secondCallId]
        }
        self.callsAdapter.joinCall(firstCallId, second: secondCallId, accountId: firstCall.accountId, account2Id: secondCall.accountId)
    }

    func addCall(call: CallModel, to callId: String) {
        self.inConferenceCalls.onNext(call)
        if var pending = self.pendingConferences[callId] {
            pending.insert(call.callId)
            self.pendingConferences[callId] = pending
        } else {
            self.pendingConferences[callId] = [call.callId]
        }
    }

    func hangUpCallOrConference(callId: String) -> Completable {
        return Completable.create(subscribe: { completable in
            guard let call = self.calls.value[callId] else {
                completable(.error(CallServiceError.hangUpCallFailed))
                return Disposables.create { }
            }
            var success: Bool
            if call.participantsCallId.count < 2 {
                success = self.callsAdapter.hangUpCall(callId, accountId: call.accountId)
            } else {
                success = self.callsAdapter.hangUpConference(callId, accountId: call.accountId)
            }
            if success {
                completable(.completed)
            } else {
                completable(.error(CallServiceError.hangUpCallFailed))
            }
            return Disposables.create { }
        })
    }

    func isParticipant(participantURI: String?, activeIn conferenceId: String, accountId: String) -> Bool? {
        guard let uri = participantURI,
              let participantsArray = self.callsAdapter.getConferenceInfo(conferenceId, accountId: accountId) as? [[String: String]] else { return nil }
        let participants = self.arrayToConferenceParticipants(participants: participantsArray, onlyURIAndActive: true)
        for participant in participants where participant.uri?.filterOutHost() == uri.filterOutHost() {
            return participant.isActive
        }
        return nil
    }

    func isModerator(participantId: String, inConference confId: String) -> Bool {
        let participants = self.conferenceInfos[confId]
        let participant = participants?.filter({ confParticipant in
            return confParticipant.uri?.filterOutHost() == participantId.filterOutHost()
        }).first
        return participant?.isModerator ?? false
    }

    func getConferenceParticipants(for conferenceId: String) -> [ConferenceParticipant]? {
        return conferenceInfos[conferenceId]
    }

    func setActiveParticipant(conferenceId: String, maximixe: Bool, jamiId: String) {
        guard let conference = self.calls.value[conferenceId],
              let isActive = self.isParticipant(participantURI: jamiId, activeIn: conferenceId, accountId: conference.accountId) else { return }
        let newLayout = isActive ? self.getNewLayoutForActiveParticipant(currentLayout: conference.layout, maximixe: maximixe) : .oneWithSmal
        conference.layout = newLayout
        self.callsAdapter.setActiveParticipant(jamiId, forConference: conferenceId, accountId: conference.accountId)
        self.callsAdapter.setConferenceLayout(newLayout.rawValue, forConference: conferenceId, accountId: conference.accountId)
    }

    private func getNewLayoutForActiveParticipant(currentLayout: CallLayout, maximixe: Bool) -> CallLayout {
        var newLayout = CallLayout.grid
        switch currentLayout {
        case .grid:
            newLayout = .oneWithSmal
        case .oneWithSmal:
            newLayout = maximixe ? .one : .grid
        case .one:
            newLayout = .oneWithSmal
        }
        return newLayout
    }

    func setModeratorParticipant(confId: String, participantId: String, active: Bool) {
        guard let conference = calls.value[confId] else { return }
        self.callsAdapter.setConferenceModerator(participantId, forConference: confId, accountId: conference.accountId, active: active)
    }

    func hangupParticipant(confId: String, participantId: String, device: String) {
        guard let conference = calls.value[confId] else { return }
        self.callsAdapter.hangupConferenceParticipant(participantId, forConference: confId, accountId: conference.accountId, deviceId: device)
    }

    func muteStream(confId: String, participantId: String, device: String, accountId: String, streamId: String, state: Bool) {
        self.callsAdapter.muteStream(participantId, forConference: confId, accountId: accountId, deviceId: device, streamId: streamId, state: state)
    }

    func setRaiseHand(confId: String, participantId: String, state: Bool, accountId: String, deviceId: String) {
        self.callsAdapter.raiseHand(participantId, forConference: confId, accountId: accountId, deviceId: deviceId, state: state)
    }

    private func arrayToConferenceParticipants(participants: [[String: String]], onlyURIAndActive: Bool) -> [ConferenceParticipant] {
        var conferenceParticipants = [ConferenceParticipant]()
        for participant in participants {
            conferenceParticipants.append(ConferenceParticipant(info: participant, onlyURIAndActive: onlyURIAndActive))
        }
        return conferenceParticipants
    }

    func updateConferences(callId: String) {
        let conferences = self.calls.value.keys.filter { (callID) -> Bool in
            guard let callModel = self.calls.value[callID] else { return false }
            return callModel.participantsCallId.count > 1 && callModel.participantsCallId.contains(callId)
        }

        guard let conferenceID = conferences.first, let conference = calls.value[conferenceID] else { return }
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: conference.accountId))
        conference.participantsCallId = conferenceCalls
        conferenceCalls.forEach { (callID) in
            self.calls.value[callID]?.participantsCallId = conferenceCalls
        }
    }

    func handleConferenceCreated(conference conferenceID: String, accountId: String) {
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: accountId))
        if conferenceCalls.isEmpty {
            // no calls attached to a conference. Wait until conference changed to check the calls.
            createdConferences.insert(conferenceID)
            return
        }
        createdConferences.remove(conferenceID)
        for (callId, pendingSet) in pendingConferences {
            if !conferenceCalls.contains(callId) ||
                conferenceCalls.isDisjoint(with: pendingSet) {
                continue
            }
            var values = pendingSet
            // update pending conferences
            // replace callID by new Conference ID, and remove calls that was already added to conference
            values.subtract(conferenceCalls)
            self.pendingConferences[callId] = nil
            if !values.isEmpty {
                self.pendingConferences[conferenceID] = values
            }
            // update calls and add conference
            self.calls.value[callId]?.participantsCallId = conferenceCalls
            values.forEach { (call) in
                self.calls.value[call]?.participantsCallId = conferenceCalls
            }
            guard var callDetails = self.callsAdapter.getConferenceDetails(conferenceID, accountId: accountId) else { return }
            callDetails[CallDetailKey.accountIdKey.rawValue] = self.calls.value[callId]?.accountId
            callDetails[CallDetailKey.audioOnlyKey.rawValue] = self.calls.value[callId]?.isAudioOnly.toString()
            let mediaList = [[String: String]]()
            let conf = CallModel(withCallId: conferenceID, callDetails: callDetails, withMedia: mediaList)
            conf.participantsCallId = conferenceCalls
            var value = self.calls.value
            value[conferenceID] = conf
            self.calls.accept(value)
            currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.conferenceCreated.rawValue, conferenceCalls))
        }
    }

    func handleConferenceChanged(conference conferenceID: String, accountId: String, state: String) {
        if createdConferences.contains(conferenceID) {
            // a conference was created but calls was not attached to a conference. In this case a conference should be added first.
            self.handleConferenceCreated(conference: conferenceID, accountId: accountId)
            return
        }
        guard let conference = self.calls.value[conferenceID] else { return }
        let conferenceCalls = Set(self.callsAdapter
                                    .getConferenceCalls(conferenceID, accountId: conference.accountId))
        conference.participantsCallId = conferenceCalls
        conferenceCalls.forEach { (callId) in
            guard let call = self.calls.value[callId] else { return }
            call.participantsCallId = conferenceCalls
            var values = self.calls.value
            values[callId] = call
            self.calls.accept(values)
        }
    }

    func handleConferenceRemoved(conference conferenceID: String) {
        guard let conference = self.calls.value[conferenceID] else { return }
        self.conferenceInfos[conferenceID] = nil
        self.currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.infoUpdated.rawValue, [""]))
        self.currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.conferenceDestroyed.rawValue, conference.participantsCallId))
        var values = self.calls.value
        values[conferenceID] = nil
        self.calls.accept(values)
    }

    func handleConferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        let participants = self.arrayToConferenceParticipants(participants: info, onlyURIAndActive: false)
        self.conferenceInfos[conferenceID] = participants
        currentConferenceEvent.accept(ConferenceUpdates(conferenceID, ConferenceState.infoUpdated.rawValue, [""]))
    }

    func clearPendingConferences(callId: String) {
        // clear pending conferences if need
        if self.pendingConferences.keys.contains(callId) {
            self.pendingConferences[callId] = nil
        }

        for (confId, pendingCalls) in pendingConferences {
            if let index = pendingCalls.firstIndex(of: callId) {
                var updatedCalls = pendingCalls
                updatedCalls.remove(at: index)
                if updatedCalls.isEmpty {
                    self.pendingConferences[confId] = nil
                } else {
                    self.pendingConferences[confId] = updatedCalls
                }
            }
        }
    }

    func shouldCallBeAddedToConference(callId: String) -> String? {
        var confId: String?
        self.pendingConferences.keys.forEach { [weak self] (initialCall) in
            guard let self = self,
                  let pendigs = self.pendingConferences[initialCall],
                  !pendigs.isEmpty
            else { return }
            if pendigs.contains(callId) {
                confId = initialCall
            }
        }
        return confId
    }
}
