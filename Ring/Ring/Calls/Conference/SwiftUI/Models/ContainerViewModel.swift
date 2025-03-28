/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import SwiftUI
import RxSwift

class ContainerViewModel: ObservableObject {

    @Published var layout: CallLayout = .grid
    @Published var hasLocalVideo: Bool = false
    @Published var hasIncomingVideo: Bool = false
    @Published var localImage = UIImage()
    @Published var callAnswered = false
    @Published var callState = ""

    private var conferenceActionsModel: ConferenceActionsModel
    var mainGridViewModel: MainGridViewModel = MainGridViewModel()
    var actionsViewModel: ActionsViewModel

    var pipManager: PictureInPictureManager?

    var participants = [ParticipantViewModel]()
    var activeVoiceParticipant: String = ""
    var activeParticipant: String = ""
    let localId: String
    var callId: String
    let currentCall: Observable<CallModel>
    var pending: [PendingConferenceCall] = []

    let disposeBag = DisposeBag()
    var videoRunningBag = DisposeBag()

    let videoService: VideoService
    let callService: CallsService
    let accountService: AccountsService
    let injectionBag: InjectionBag

    lazy var capturedFrame: Observable<UIImage?> = {
        return videoService.capturedVideoFrame.asObservable().map({ frame in
            return frame
        })
    }()

    // state
    private let actionsStateSubject = PublishSubject<State>()
    lazy var actionsState: Observable<State> = {
        return self.actionsStateSubject.asObservable()
    }()

    private let conferenceStateSubject = PublishSubject<State>()
    lazy var conferenceState: Observable<State> = {
        return self.conferenceStateSubject.asObservable()
    }()

    init(localId: String, delegate: PictureInPictureManagerDelegate, injectionBag: InjectionBag, currentCall: Observable<CallModel>, hasVideo: Bool, incoming: Bool, callId: String) {
        self.hasLocalVideo = hasVideo
        self.hasIncomingVideo = hasVideo
        self.localId = localId
        self.callId = callId
        self.injectionBag = injectionBag
        self.videoService = injectionBag.videoService
        self.accountService = injectionBag.accountService
        self.callService = injectionBag.callService
        self.currentCall = currentCall
        self.callAnswered = incoming
        if let call = self.callService.call(callID: callId), call.state == .current || call.state == .hold {
            self.callAnswered = true
        }

        self.actionsViewModel = ActionsViewModel(actionsState: self.actionsStateSubject, currentCall: currentCall, audioService: injectionBag.audioService)
        self.conferenceActionsModel = ConferenceActionsModel(injectionBag: injectionBag)

        self.pipManager = PictureInPictureManager(delegate: delegate)
        self.capturedFrame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.localImage = image
                    }
                }
            })
            .disposed(by: self.disposeBag)
        currentCall
            .filter({ call in
                return call.state == .current
            })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] call in
                self?.callAnswered = true
                self?.checkIfAudioOnly(call: call)
            })
            .disposed(by: self.disposeBag)

        currentCall
            .filter({call in
                return call.callType == .outgoing
            })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] call in
                self?.callState = call.state.toString()
                self?.checkIfAudioOnly(call: call)
            })
            .disposed(by: self.disposeBag)

        self.callService.currentConferenceEvent
            .observe(on: MainScheduler.instance)
            .asObservable()
            .filter(isRelevantConference)
            .subscribe(onNext: handleConferenceEvent)
            .disposed(by: disposeBag)

                self.callService
                    .inConferenceCalls()
                    .asObservable()
                    .observe(on: MainScheduler.instance)
                    .subscribe(onNext: { [weak self] call in
                        guard let self = self else { return }
                        self.handlePendingCall(call)
                    })
                    .disposed(by: self.disposeBag)

        self.observeRaiseHand()
        self.observeConferenceActions()
    }

    private func handlePendingCall(_ call: CallModel) {
        guard !isCallPending(call) else { return }

        // add pending call
        let confInfo = ConferenceParticipant(sinkId: call.callId, isActive: false)
        confInfo.uri = call.paricipantHash()
        confInfo.displayName = call.displayName
        let pendingCall = PendingConferenceCall(info: confInfo, injectionBag: self.injectionBag)
        self.pending.append(pendingCall)
        subscribePendingCall(callId: call.callId, pending: pendingCall)

        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    private func isCallPending(_ call: CallModel) -> Bool {
        return pending.contains { $0.info.sinkId == call.callId }
    }

    private func isRelevantConference(_ conference: ConferenceUpdates) -> Bool {
        return conference.calls.contains(callId) || conference.conferenceID == callId
    }

    private func handleConferenceEvent(_ conference: ConferenceUpdates) {
        switch conference.state {
        case ConferenceState.conferenceDestroyed.rawValue:
            handleConferenceDestroyed(conference)
        case ConferenceState.conferenceCreated.rawValue:
            updateViewForNewConference()
            fallthrough
        default:
            updateViewForOngoingConference(conference)
        }
    }

    private func handleConferenceDestroyed(_ conference: ConferenceUpdates) {
        for callId in conference.calls {
            if let currentCall = getCurrentCall(for: callId) {
                updateViewForCurrentCall(currentCall)
                return
            }
        }
    }

    private func updateViewForNewConference() {
        updateWith(participantsInfo: [], mode: .resizeAspectFill)
    }

    private func updateViewForOngoingConference(_ conference: ConferenceUpdates) {
        callId = conference.conferenceID
        if let participants = getConferenceParticipants() {
            updateWith(participantsInfo: participants, mode: .resizeAspectFill)
        }
    }

    private func getCurrentCall(for callId: String) -> CallModel? {
        guard let call = callService.call(callID: callId), call.state == .current else { return nil }
        self.callId = call.callId
        return call
    }

    private func updateViewForCurrentCall(_ call: CallModel) {
        let participant = ConferenceParticipant(sinkId: call.callId, isActive: true)
        participant.uri = call.participantUri
        updateWith(participantsInfo: [participant], mode: .resizeAspect)
        hasIncomingVideo = true
    }

    func isHostCall(participantId: String) -> Bool {
        if let participant = participants.first(where: { $0.info?.uri == participantId }) {
            return ((participant.info?.sinkId.contains("host")) != nil)
        }
        return false
    }

    func checkIfAudioOnly(call: CallModel? = nil) {
        if self.participants.count > 1 {
            self.hasLocalVideo = false
            return
        }
        guard let call = call else { return }
        let audioOnly = call.isAudioOnly || call.videoMuted
        self.hasLocalVideo = !audioOnly
    }

    func updateParticipantInfo(info: ConferenceParticipant) -> Bool {
        if let participant = participants.first(where: { $0.id == info.sinkId }) {
            participant.info = info
            let menu = self.getItemsForConferenceMenu(sinkId: info.sinkId)
            participant.setActions(items: menu)
            return true
        }
        return false
    }

    func addParticipantInfo(info: ConferenceParticipant, mode: AVLayerVideoGravity) {
        let participant = ParticipantViewModel(info: info, injectionBag: injectionBag, conferenceState: self.conferenceStateSubject, mode: mode)
        let menu = self.getItemsForConferenceMenu(sinkId: info.sinkId)
        participant.setActions(items: menu)
        self.participants.append(participant)
        if self.participants.count == 1 {
            participant.videoRunning
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] hasVideo in
                    guard let self = self else { return }
                    self.hasIncomingVideo = hasVideo
                })
                .disposed(by: self.videoRunningBag)
        } else {
            videoRunningBag = DisposeBag()
            self.hasIncomingVideo = true
        }
    }

    func updateWith(participantsInfo: [ConferenceParticipant], mode: AVLayerVideoGravity) {
        updateParticipants(with: participantsInfo, mode: mode)

        if let currentActiveParticipant = getActiveParticipant(),
           currentActiveParticipant.id != activeParticipant {
            activeParticipant = currentActiveParticipant.id
            reorderParticipantsIfNeeded(participant: currentActiveParticipant)
        }

        // Check if there is a new active voice participant and reorder the participants list if needed
        if let currentVoiceActiveParticipant = getActiveVoiceParticipant(), currentVoiceActiveParticipant.id != activeVoiceParticipant {
            activeVoiceParticipant = currentVoiceActiveParticipant.id
            reorderParticipantsIfNeeded(participant: currentVoiceActiveParticipant)
        }
        updateLayoutForConference()
        if self.participants.count == 1 {
            self.participants[0].setActions(items: [MenuItem]())
        }

        self.checkIfAudioOnly()
        self.actionsViewModel.updateItemRaiseHand(add: self.participants.count > 1)

        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func updateLayoutForConference() {
        let count = participants.count
        mainGridViewModel.updatedLayout(participantsCount: count, firstParticipant: participants.first?.id ?? "")
        setCallLayout(layout: getNewLayout())
    }

    func getNewLayout() -> CallLayout {
        if participants.count == 1 {
            return .one
        }

        guard let currentActiveParticipant = getActiveParticipant() else {
            // If there's no active participant, default to grid layout
            return .grid
        }

        let participantsWithValidVideo = getParticipantsWithValidVideoSize(excluding: currentActiveParticipant)
        return participantsWithValidVideo.isEmpty ? .one : .oneWithSmal
    }

    func getParticipantsWithValidVideoSize(excluding activeParticipant: ParticipantViewModel) -> [ParticipantViewModel] {
        return self.participants.filter { participant in
            let hasValidWidth = participant.info?.width ?? 0 > 0
            let hasValidHeight = participant.info?.height ?? 0 > 0
            return hasValidWidth && hasValidHeight
        }
        .filter { $0 != activeParticipant }
    }

    private func updateParticipants(with participantsInfo: [ConferenceParticipant], mode: AVLayerVideoGravity) {
        let filtered = participantsInfo.filter { participant in
            !participant.sinkId.isEmpty
        }
        /*
         Extract the base IDs from the sinkId of each filtered participant.
         These base IDs (callId) are key for tracking participants consistently.
         They help identify the same participant
         even when their media resources (like audio or video) change.
         */
        let baseIds = Set(filtered.map { extractBaseId(from: $0.sinkId) })

        // Remove participants not in the set of extracted base IDs to keep only relevant ones.
        participants.removeAll { !baseIds.contains(extractBaseId(from: $0.id)) }

        // Iterate over the filtered participants to update sinkId.
        for info in filtered {
            let baseId = extractBaseId(from: info.sinkId)
            // Check if a participant with the same base id exists
            if let index = participants.firstIndex(where: { extractBaseId(from: $0.id) == baseId }) {
                participants[index].id = info.sinkId
            }
        }
        // Update participant info or add new participants
        for info in filtered where !updateParticipantInfo(info: info) {
            addParticipantInfo(info: info, mode: mode)
        }
    }

    private func extractBaseId(from sinkId: String) -> String {
        /*
         The 'sinkId' is a string typically structured as 'callId_mediaResource', where:
         - 'callId' is the base identifier of a call, and
         - 'mediaResource' is an adjustment descriptor such as 'video_0', 'audio_0', etc.
         let components = sinkId.split(separator: "_")
         */
        let components = sinkId.split(separator: "_")
        return String(components.first ?? "")
    }

    private func reorderParticipantsIfNeeded(participant: ParticipantViewModel) {
        guard let currentActiveParticipant = getActiveParticipant(), let index = participants.firstIndex(of: currentActiveParticipant), !mainGridViewModel.isFirstPage(index: index) else {
            return
        }

        participants.swapAt(0, index)
    }

    private func getActiveParticipant() -> ParticipantViewModel? {
        if participants.count == 1 {
            return participants.first
        }
        return participants.first(where: { $0.info?.isActive ?? false })
    }

    private func getActiveVoiceParticipant() -> ParticipantViewModel? {
        return participants.first(where: { $0.info?.voiceActivity ?? false })
    }

    func setCallLayout(layout: CallLayout) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.layout == layout { return }
            self.layout = layout
            if let pipLayout = self.participants.filter({ participant in
                participant.info?.uri != self.localId
            }).first?.mainDisplayLayer {
                self.updatePipLayer(layer: pipLayout)
            }
        }
    }

    func callStopped() {
        self.pipManager?.callStopped()
        self.pipManager = nil
    }

    func showPiP() {
        self.pipManager?.showPiP()
    }

    func updatePipLayer(layer: AVSampleBufferDisplayLayer) {
        self.pipManager?.updatePIP(layer: layer)
    }

    func getConferenceParticipants() -> [ConferenceParticipant]? {
        guard let participants = self.callService.getConferenceParticipants(for: self.callId) else { return nil }
        return participants.map { participant in
            participant.uri = participant.uri?.filterOutHost()
            return participant
        }
    }

    func observeRaiseHand() {
        self.actionsState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? CallAction else { return }
                switch state {
                case .raiseHand:
                    guard let local = self.getLocal()?.info else { return }
                    self.conferenceActionsModel.togleRaiseHand(state: !local.isHandRaised, conferenceId: self.callId, deviceId: local.device)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)
    }

    func subscribePendingCall(callId: String, pending: PendingConferenceCall) {
                self.callService
                    .currentCall(callId: callId)
                    .observe(on: MainScheduler.instance)
                    .subscribe(onNext: { [weak self] currentCall in
                        if currentCall.state != .ringing && currentCall.state != .connecting
                            && currentCall.state != .unknown {
                            if let index = self?.pending.firstIndex(where: { model in
                                model.id == currentCall.callId
                            }) {
                                self?.pending.remove(at: index)
                                DispatchQueue.main.async { [weak self] in
                                    self?.objectWillChange.send()
                                }
                            }
                        }
                    })
                    .disposed(by: pending.disposeBag)
    }
}

// MARK: - Conference Actions
extension ContainerViewModel {

    func getItemsForConferenceMenu(sinkId: String) -> [MenuItem] {
        guard let participant = self.participants.filter({ participant in
            participant.id == sinkId
        }).first,
        let local = getLocal(),
        let localInfo = local.info,
        let info = participant.info else { return [] }
        return self.conferenceActionsModel.getItemsForConferenceFor(participant: info, local: localInfo, conferenceId: callId, layout: getNewLayout())
    }

    func getHost() -> ParticipantViewModel? {
        return self.participants.filter({ participant in
            participant.id.contains("host")
        }).first
    }

    func getLocal() -> ParticipantViewModel? {
        guard let account = self.accountService.currentAccount else { return nil }
        return self.participants.filter({ participant in
            guard let uri = participant.info?.uri, !uri.isEmpty else { return true }
            return uri == account.jamiId
        }).first
    }

    func observeConferenceActions() {
        self.conferenceState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ParticipantAction else { return }
                switch state {
                case .hangup(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.hangupParticipant(participantId: uri, device: info.device, conferenceId: self.callId)
                case .maximize(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.setActiveParticipant(participantId: uri, maximize: true, conferenceId: self.callId)
                case .minimize(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.setActiveParticipant(participantId: uri, maximize: false, conferenceId: self.callId)
                case .setModerator(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.setModeratorParticipant(participantId: uri, active: !info.isModerator, conferenceId: self.callId)
                case .muteAudio(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.muteParticipant(participantId: uri, active: !info.isAudioMuted, conferenceId: self.callId, device: info.device, streamId: info.sinkId)
                case .raseHand(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.lowerHandFor(participantId: uri, conferenceId: self.callId, deviceId: info.device)
                }
            })
            .disposed(by: self.disposeBag)
    }
}
