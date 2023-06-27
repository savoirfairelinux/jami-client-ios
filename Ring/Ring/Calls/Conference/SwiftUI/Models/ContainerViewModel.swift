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

    private var conferenceActionsModel: ConferenceActionsModel

    var participants = [ParticipantViewModel]()
    var activeVoiceParticipant: String = ""
    var activeParticipant: String = ""

    var pipManager: PictureInPictureManager?

    var mainGridViewModel: MainGridViewModel = MainGridViewModel()

    let localId: String
    let callId: String
    var conferenceId: String

    let disposeBag = DisposeBag()
    var videoRunningBag = DisposeBag()

    let videoService: VideoService
    let callService: CallsService
    let accountService: AccountsService
    let injectionBag: InjectionBag

    var actionsViewModel: ActionsViewModel
    let currentCall: Observable<CallModel>
    @Published var hasLocalVideo: Bool = false
    @Published var hasIncomingVideo: Bool = false
    @Published var localImage = UIImage()
    @Published var callAnswered = false

    var pending: [ParticipantViewModel] = []

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
        self.conferenceId = callId
        self.injectionBag = injectionBag
        self.videoService = injectionBag.videoService
        self.accountService = injectionBag.accountService
        self.callService = injectionBag.callService
        self.currentCall = currentCall
        self.callAnswered = incoming

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

        self.callService.currentConferenceEvent
            .observe(on: MainScheduler.instance)
            .asObservable()
            .skip(1)
            .subscribe(onNext: { [weak self] conf in
                guard let self = self else { return }
                let conferenceDestroyed = conf.state == ConferenceState.conferenceDestroyed.rawValue
                self.conferenceId = conferenceDestroyed ? self.callId : conf.conferenceID
                if conferenceDestroyed {
                    self.updateWith(participantsInfo: [])
                    return
                }
                if let participants = self.getConferenceParticipants() {
                    self.updateWith(participantsInfo: participants)
                }
            })
            .disposed(by: self.disposeBag)
        self.callService
            .inConferenceCalls
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] call in
                guard let self = self else { return }
                if self.pending.contains(where: { model in
                    model.id == call.callId
                }) {
                    return
                }
                let confInfo = ConferenceParticipant(sinkId: call.callId, isActive: false)
                confInfo.uri = call.paricipantHash()
                confInfo.displayName = call.displayName
                let pending = ParticipantViewModel(info: confInfo, injectionBag: self.injectionBag, conferenceState: self.conferenceStateSubject)
                self.pending.append(pending)
                self.subscribePendingCall(callId: call.callId, pending: pending)
                DispatchQueue.main.async { [weak self] in
                    self?.objectWillChange.send()
                }
            })
            .disposed(by: self.disposeBag)

        self.observeRaiseHand()
        self.observeConferenceActions()
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

    func addParticipantInfo(info: ConferenceParticipant) {
        let participant = ParticipantViewModel(info: info, injectionBag: injectionBag, conferenceState: self.conferenceStateSubject)
        let menu = self.getItemsForConferenceMenu(sinkId: info.sinkId)
        participant.setActions(items: menu)
        self.participants.append(participant)
        if self.participants.count == 1 {
            participant.videoRunning
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] hasVideo in
                    self?.hasIncomingVideo = hasVideo
                })
                .disposed(by: self.videoRunningBag)
        } else {
            videoRunningBag = DisposeBag()
            self.hasIncomingVideo = true
        }
    }

    func updateWith(participantsInfo: [ConferenceParticipant]) {
        updateParticipants(with: participantsInfo)

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

    private func updateParticipants(with participantsInfo: [ConferenceParticipant]) {
        let filtered = participantsInfo.filter { participant in
            !participant.sinkId.isEmpty
        }
        let ids = Set(filtered.map { $0.sinkId })
        participants.removeAll { !ids.contains($0.id) }

        // Update participant info or add new participants
        for info in filtered where !updateParticipantInfo(info: info) {
            addParticipantInfo(info: info)
        }
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
        guard let participants = self.callService.getConferenceParticipants(for: self.conferenceId) else { return nil }
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
                    self.conferenceActionsModel.togleRaiseHand(state: !local.isHandRaised, conferenceId: conferenceId, deviceId: local.device)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)
    }

    func subscribePendingCall(callId: String, pending: ParticipantViewModel) {
        self.callService
            .currentCall(callId: callId)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] currentCall in
                if currentCall.state != .ringing && currentCall.state != .connecting {
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
        return self.conferenceActionsModel.getItemsForConferenceFor(participant: info, local: localInfo, conferenceId: conferenceId, layout: getNewLayout())
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
                    self.conferenceActionsModel.hangupParticipant(participantId: uri, device: info.device, conferenceId: self.conferenceId)
                case .maximize(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.setActiveParticipant(participantId: uri, maximize: true, conferenceId: self.conferenceId)
                case .minimize(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.setActiveParticipant(participantId: uri, maximize: false, conferenceId: self.conferenceId)
                case .setModerator(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.setModeratorParticipant(participantId: uri, active: !info.isModerator, conferenceId: self.conferenceId)
                case .muteAudio(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.muteParticipant(participantId: uri, active: !info.isAudioMuted, conferenceId: self.conferenceId, device: info.device, streamId: info.sinkId)
                case .raseHand(let info):
                    guard let uri = info.uri else { return }
                    self.conferenceActionsModel.lowerHandFor(participantId: uri, conferenceId: self.conferenceId, deviceId: info.device)
                case .hangupPending(let callId):
                    self.callService.stopPendingCall(callId: callId)
                }
            })
            .disposed(by: self.disposeBag)
    }
}
