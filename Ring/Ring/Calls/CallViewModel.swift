/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

import RxSwift
import RxRelay
import SwiftyBeaver
import Contacts
import RxCocoa

enum CallViewMode {
    case audio
    case videoWithSpiner
    case video
}

class CallViewModel: Stateable, ViewModel {

    // stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    let callService: CallsService
    private let contactsService: ContactsService
    private let accountService: AccountsService
    let videoService: VideoService
    let audioService: AudioService
    private let profileService: ProfilesService
    private let conversationService: ConversationsService
    private let nameService: NameService

    private let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self
    var isAudioOnly = false

    private lazy var currentCallVariable: BehaviorRelay<CallModel> = {
        BehaviorRelay<CallModel>(value: self.call ?? CallModel())
    }()
    lazy var currentCall: Observable<CallModel> = {
        currentCallVariable.asObservable()
    }()
    private var callDisposeBag = DisposeBag()

    var conferenceId = ""
    var isHost: Bool?
    var callFailed: BehaviorRelay<Bool> = BehaviorRelay(value: false)
    var callStarted: BehaviorRelay<Bool> = BehaviorRelay(value: false)
    var callCompleted = false

    func callURI() -> String? {
        guard let call = call else { return nil }
        return call.callUri
    }

    var call: CallModel? {
        didSet {
            guard let call = self.call else {
                return
            }
            isAudioOnly = call.isAudioOnly
            callDisposeBag = DisposeBag()
            self.callService
                .currentCall(callId: call.callId)
                .share()
                .startWith(call)
                .subscribe(onNext: { [weak self] call in
                    self?.currentCallVariable.accept(call)
                })
                .disposed(by: self.callDisposeBag)
            // do other initializong only once
            if oldValue != nil {
                return
            }
            self.conferenceId = call.callId
            self.configureVideo()
            self.observeConferenceEvents()
        }
    }

    // data for ViewController binding
    lazy var showRecordImage: Observable<Bool> = {
        return self.callService
            .callUpdates
            .asObservable()
            .map({[weak self] call in
                guard let self = self else { return false }
                let showStatus = call.callRecorded
                return showStatus
            })
    }()

    lazy var dismisVC: Observable<Bool> = {
        return currentCall
            .filter({ call in
                return !call.isExists() || call.state.isFinished()
            })
            .map({ [weak self] call in
                let hide = !call.isExists() || call.state.isFinished()
                // if it was conference call switch to another running call
                if hide && call.participantsCallId.count > 1 {
                    // switch to another call
                    return self?.handleConferenceCallSwitch(call) ?? hide
                }
                return hide
            })
    }()

    lazy var contactName: Driver<String> = {
        return currentCall
            .startWith(self.call ?? CallModel())
            .filter({ call in
                return call.isExists()
            })
            .map({ call in
                return call.getDisplayName()
            })
            .asDriver(onErrorJustReturn: "")
    }()

    lazy var callDuration: Driver<String> = {
        let timer = Observable<Int>.interval(Durations.oneSecond.toTimeInterval(), scheduler: MainScheduler.instance)
            .take(until: currentCall
                    .filter { call in
                        !call.isExists()
                    })
            .map({ [weak self] (elapsed) -> String in
                var time = elapsed
                if let startTime = self?.call?.dateReceived {
                    time = Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
                }
                return CallViewModel.formattedDurationFrom(interval: time)
            })
            .share()
        return currentCall
            .filter({ call in
                return call.state == .current
            })
            .flatMap({ _ in
                return timer
            })
            .asDriver(onErrorJustReturn: "")
    }()

    let injectionBag: InjectionBag
    let callsProvider: CallsProviderService

    required init(with injectionBag: InjectionBag) {
        self.callService = injectionBag.callService
        self.contactsService = injectionBag.contactsService
        self.accountService = injectionBag.accountService
        self.videoService = injectionBag.videoService
        self.audioService = injectionBag.audioService
        self.profileService = injectionBag.profileService
        self.callsProvider = injectionBag.callsProvider
        self.nameService = injectionBag.nameService
        self.injectionBag = injectionBag
        self.conversationService = injectionBag.conversationsService

        callsProvider.sharedResponseStream
            .filter({ serviceEvent in
                serviceEvent.eventType == .audioActivated
            })
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.audioService.startAudio()
                // for outgoing calls ve create audio sesion with default parameters.
                // for incoming call audio session is created, we need to override it
                let overrideOutput = self.call?.callTypeValue == CallType.incoming.rawValue
                self.audioService.setDefaultOutput(toSpeaker: !self.isAudioOnly,
                                                   override: overrideOutput)
            })
            .disposed(by: self.disposeBag)
    }

    static func formattedDurationFrom(interval: Int) -> String {
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        switch hours {
        case 0:
            return String(format: "%02d:%02d", minutes, seconds)
        default:
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    func isBoothMode() -> Bool {
        return self.accountService.boothMode()
    }

    func callFinished() {
        guard !callCompleted else { return }
        guard let accountId = self.call?.accountId else {
            return
        }
        if self.isBoothMode() {
            self.contactsService.removeAllContacts(for: accountId)
            return
        }
        callCompleted = true
    }

    private func handleConferenceCallSwitch(_ call: CallModel) -> Bool {
        let anotherCallsIds = call.participantsCallId.filter { (callID) -> Bool in
            self.callService.call(callID: callID) != nil && callID != call.callId
        }
        if let anotherCallId = anotherCallsIds.first, let anotherCall = self.callService.call(callID: anotherCallId) {
            self.call = anotherCall
            if anotherCall.participantsCallId.count == 1 {
                self.conferenceId = anotherCallId
            }
            return false
        }
        return true
    }

    private func observeConferenceEvents() {
        callService.currentConferenceEvent
            .asObservable()
            .filter { [weak self] conference in
                guard let self = self else { return false }
                return self.isRelevantConference(conference)
            }
            .subscribe(onNext: { [weak self] conf in
                self?.handleConferenceEvent(conf)
            })
            .disposed(by: disposeBag)
    }

    private func isRelevantConference(_ conference: ConferenceUpdates) -> Bool {
        return conference.calls.contains(call?.callId ?? "") ||
            conference.conferenceID == (call?.callId ?? "") ||
            conference.conferenceID == conferenceId
    }

    private func handleConferenceEvent(_ conference: ConferenceUpdates) {
        if conference.state == ConferenceState.conferenceDestroyed.rawValue {
            handleDestroyedConference(conference)
            return
        }

        updateHostStatus(conference)
        conferenceId = conference.conferenceID
    }

    private func handleDestroyedConference(_ conference: ConferenceUpdates) {
        for callId in conference.calls {
            if let call = callService.call(callID: callId), call.state == .current {
                self.call = call
                conferenceId = call.callId
                return
            }
        }
    }

    private func updateHostStatus(_ conference: ConferenceUpdates) {
        if let participants = callService.getConferenceParticipants(for: conference.conferenceID),
           let participant = participants.first(where: { $0.uri?.filterOutHost() == localId() || $0.uri?.isEmpty ?? true }) {
            isHost = participant.sinkId.contains("host")
        }
    }

    private func configureVideo() {
        if !(self.call?.isAudioOnly ?? true) {
            self.videoService.startVideoCaptureBeforeCall()
        }
        self.currentCall
            .map { $0.state == .current }
            .subscribe(onNext: { [weak self] _ in
                self?.videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: actions
extension CallViewModel {

    func cancelCall() {
        guard let call = call else { return }
        self.callService
            .hangUpCallOrConference(callId: self.conferenceId, isSwarm: isCallForSwarm(), callURI: call.callUri)
    }

    func isCallForSwarm() -> Bool {
        guard let call = call,
              !call.conversationId.isEmpty,
              let conversation = conversationService.getConversationForId(conversationId: call.conversationId, accountId: call.accountId) else {
            return false
        }
        return conversation.getParticipants().count > 1
    }

    func acceptCall() -> Completable {
        return self.callService.accept(callId: call?.callId ?? "")
    }

    func placeCall(with uri: String, userName: String, account: AccountModel, isAudioOnly: Bool = false) {
        let isSwarm = uri.starts(with: "swarm:")
        let callObservable = isSwarm ?
            self.callService.placeSwarmCall(withAccount: account,
                                            uri: uri,
                                            userName: userName,
                                            videoSource: self.videoService.getVideoSource(),
                                            isAudioOnly: isAudioOnly) :
            self.callService.placeCall(withAccount: account,
                                       toParticipantId: uri,
                                       userName: userName,
                                       videoSource: self.videoService.getVideoSource(),
                                       isAudioOnly: isAudioOnly)

        callObservable
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .subscribe(onSuccess: { [weak self] callModel in
                self?.call = callModel
                if isSwarm {
                    self?.conferenceId = callModel.callId
                }
                self?.callsProvider.startCall(account: account, call: callModel)
                self?.callStarted.accept(true)
            }, onFailure: { [weak self] _ in
                self?.callFailed.accept(true)
            })
            .disposed(by: self.disposeBag)
    }

    func showContactPickerVC() {
        self.stateSubject.onNext(ConversationState.showContactPicker(callID: self.conferenceId, contactSelectedCB: { [weak self] (contacts) in
            guard let self = self,
                  let contact = contacts.first,
                  let contactToAdd = contact.contacts.first,
                  let account = self.accountService.getAccount(fromAccountId: contactToAdd.accountID),
                  let call = self.callService.call(callID: self.conferenceId) else { return }
            if contact.conferenceID.isEmpty {
                self.callService
                    .callAndAddParticipant(participant: contactToAdd.uri,
                                           toCall: self.conferenceId,
                                           withAccount: account,
                                           userName: contactToAdd.registeredName,
                                           videSource: self.videoService.getVideoSource(),
                                           isAudioOnly: call.isAudioOnly)
                return
            }
            guard let secondCall = self.callService.call(callID: contact.conferenceID) else { return }
            if call.participantsCallId.count == 1 {
                self.callService.joinCall(firstCallId: call.callId, secondCallId: secondCall.callId)
            } else {
                self.callService.joinConference(confID: contact.conferenceID, callID: self.conferenceId)
            }
        }, conversationSelectedCB: nil))
    }

    func showConversations() {
        guard let call = self.call else { return }

        if let conversation = findConversation(for: call) {
            self.stateSubject.onNext(ConversationState.openConversationFromCall(conversation: conversation))
        }
    }

    private func findConversation(for call: CallModel) -> ConversationModel? {
        if !call.conversationId.isEmpty {
            return conversationService.getConversationForId(conversationId: call.conversationId, accountId: call.accountId)
        }

        if let activeCall = call.getactiveCallFromURI() {
            return conversationService.getConversationForId(conversationId: activeCall.conversationId, accountId: call.accountId)
        }

        if let jamiId = JamiURI(schema: URIType.ring, infoHash: call.callUri).hash {
            return conversationService.getConversationForParticipant(jamiId: jamiId, accountId: call.accountId)
        }

        return nil
    }

    func togglePauseCall() {
        guard let call = self.call else {
            return
        }
        if call.state == .current {
            self.callService.hold(callId: call.callId)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.info("call paused")
                }, onError: { [weak self](error) in
                    self?.log.info(error)
                })
                .disposed(by: self.disposeBag)
        } else if call.state == .hold {
            self.callService.unhold(callId: call.callId)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.info("call unpaused")
                }, onError: { [weak self](error) in
                    self?.log.info(error)
                })
                .disposed(by: self.disposeBag)
        }
    }

    func toggleMuteAudio() {
        guard let call = self.call else { return }
        let callId = (self.isHost ?? false) ? self.conferenceId : call.callId
        guard let callToMute = self.callService.call(callID: callId) else { return }
        let device = self.videoService.getCurrentVideoSource()
        Task {
            await self.callService.updateCallMediaIfNeeded(call: callToMute)
        }
        self.videoService.requestMediaChange(call: callToMute, mediaLabel: "audio_0", source: device)
        updateCallStateForConferenceHost()
    }

    func toggleMuteVideo() {
        guard let call = self.call else { return }
        let callId = (self.isHost ?? false) ? self.conferenceId : call.callId
        guard let callToMute = self.callService.call(callID: callId) else { return }
        let device = self.videoService.getCurrentVideoSource()
        Task {
            await self.callService.updateCallMediaIfNeeded(call: callToMute)
        }
        self.videoService.requestMediaChange(call: callToMute, mediaLabel: "video_0", source: device)
        updateCallStateForConferenceHost()
    }

    func updateCallStateForConferenceHost() {
        if self.isHost ?? false,
           let call = self.callService.call(callID: self.conferenceId) {
            self.currentCallVariable.accept(call)
        }
    }

    func switchCamera() {
        self.videoService.switchCamera()
        videoService.setCameraOrientation(orientation: UIDevice.current.orientation, forceUpdate: true)
    }

    func switchSpeaker() {
        self.audioService.switchSpeaker()
    }

    func setCameraOrientation(orientation: UIDeviceOrientation) {
        videoService.setCameraOrientation(orientation: orientation)
    }

    func showDialpad() {
        self.stateSubject.onNext(ConversationState.showDialpad(inCall: true))
    }

    func localId() -> String {
        return self.accountService.currentAccount?.jamiId ?? ""
    }

    func isIncoming() -> Bool {
        return self.call?.callType == .incoming
    }

    func hasVideo() -> Bool {
        return !(self.call?.isAudioOnly ?? true)
    }

    func callId() -> String {
        return self.call?.callId ?? ""
    }

    func reopenCall(viewControler: CallViewController) {
        stateSubject.onNext(ConversationState.reopenCall(viewController: viewControler))
    }
}
