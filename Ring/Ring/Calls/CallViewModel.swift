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

import Contacts
import RxCocoa
import RxRelay
import RxSwift
import SwiftyBeaver

enum CallViewMode {
    case audio
    case videoWithSpiner
    case video
}

class CallViewModel: Stateable, ViewModel {
    // stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = self.stateSubject.asObservable()

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

    private lazy var currentCallVariable: BehaviorRelay<CallModel> =
        .init(value: self.call ?? CallModel())

    lazy var currentCall: Observable<CallModel> = currentCallVariable.asObservable()

    private var callDisposeBag = DisposeBag()

    var conferenceId = ""
    var isHost: Bool?
    var callFailed: BehaviorRelay<Bool> = BehaviorRelay(value: false)
    var callStarted: BehaviorRelay<Bool> = BehaviorRelay(value: false)
    var callCompleted = false

    func getJamiId() -> String? {
        guard let call = call else { return nil }
        return call.participantUri
    }

    var call: CallModel? {
        didSet {
            guard let call = call else {
                return
            }
            isAudioOnly = call.isAudioOnly
            callDisposeBag = DisposeBag()
            callService
                .currentCall(callId: call.callId)
                .share()
                .startWith(call)
                .subscribe(onNext: { [weak self] call in
                    self?.currentCallVariable.accept(call)
                })
                .disposed(by: callDisposeBag)
            // do other initializong only once
            if oldValue != nil {
                return
            }
            conferenceId = call.callId
            configureVideo()
            observeConferenceEvents()
        }
    }

    // data for ViewController binding
    lazy var showRecordImage: Observable<Bool> = self.callService
        .currentCallsEvents
        .asObservable()
        .map { [weak self] call in
            guard let self = self else { return false }
            let showStatus = call.callRecorded
            return showStatus
        }

    lazy var dismisVC: Observable<Bool> = currentCall
        .filter { call in
            !call.isExists()
        }
        .map { [weak self] call in
            let hide = !call.isExists()
            // if it was conference call switch to another running call
            if hide && call.participantsCallId.count > 1 {
                // switch to another call
                return self?.handleConferenceCallSwitch(call) ?? hide
            }
            return hide
        }

    lazy var contactName: Driver<String> = currentCall
        .startWith(self.call ?? CallModel())
        .filter { call in
            call.isExists()
        }
        .map { call in
            call.getDisplayName()
        }
        .asDriver(onErrorJustReturn: "")

    lazy var callDuration: Driver<String> = {
        let timer = Observable<Int>.interval(
            Durations.oneSecond.toTimeInterval(),
            scheduler: MainScheduler.instance
        )
        .take(until: currentCall
                .filter { call in
                    !call.isExists()
                })
        .map { [weak self] elapsed -> String in
            var time = elapsed
            if let startTime = self?.call?.dateReceived {
                time = Int(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970)
            }
            return CallViewModel.formattedDurationFrom(interval: time)
        }
        .share()
        return currentCall
            .filter { call in
                call.state == .current
            }
            .flatMap { _ in
                timer
            }
            .asDriver(onErrorJustReturn: "")
    }()

    let injectionBag: InjectionBag
    let callsProvider: CallsProviderService

    required init(with injectionBag: InjectionBag) {
        callService = injectionBag.callService
        contactsService = injectionBag.contactsService
        accountService = injectionBag.accountService
        videoService = injectionBag.videoService
        audioService = injectionBag.audioService
        profileService = injectionBag.profileService
        callsProvider = injectionBag.callsProvider
        nameService = injectionBag.nameService
        self.injectionBag = injectionBag
        conversationService = injectionBag.conversationsService

        callsProvider.sharedResponseStream
            .filter { serviceEvent in
                serviceEvent.eventType == .audioActivated
            }
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.audioService.startAudio()
                // for outgoing calls ve create audio sesion with default parameters.
                // for incoming call audio session is created, we need to override it
                let overrideOutput = self.call?.callTypeValue == CallType.incoming.rawValue
                self.audioService.setDefaultOutput(toSpeaker: !self.isAudioOnly,
                                                   override: overrideOutput)
            })
            .disposed(by: disposeBag)
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
        return accountService.boothMode()
    }

    func callFinished() {
        guard !callCompleted else { return }
        guard let accountId = call?.accountId else {
            return
        }
        if isBoothMode() {
            contactsService.removeAllContacts(for: accountId)
            return
        }
        callCompleted = true
        showConversations()
    }

    private func handleConferenceCallSwitch(_ call: CallModel) -> Bool {
        let anotherCallsIds = call.participantsCallId.filter { callID -> Bool in
            self.callService.call(callID: callID) != nil && callID != call.callId
        }
        if let anotherCallId = anotherCallsIds.first,
           let anotherCall = callService.call(callID: anotherCallId) {
            self.call = anotherCall
            if anotherCall.participantsCallId.count == 1 {
                conferenceId = anotherCallId
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
           let participant = participants
            .first(where: { $0.uri?.filterOutHost() == localId() || $0.uri?.isEmpty ?? true }) {
            isHost = participant.sinkId.contains("host")
        }
    }

    private func configureVideo() {
        if !(call?.isAudioOnly ?? true) {
            videoService.startVideoCaptureBeforeCall()
        }
        currentCall
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
        callService
            .hangUpCallOrConference(callId: conferenceId)
            .subscribe()
            .disposed(by: disposeBag)
    }

    func answerCall() -> Completable {
        return callService.accept(call: call)
    }

    func placeCall(
        with uri: String,
        userName: String,
        account: AccountModel,
        isAudioOnly: Bool = false
    ) {
        callService.placeCall(withAccount: account,
                              toParticipantId: uri,
                              userName: userName,
                              videoSource: videoService.getVideoSource(),
                              isAudioOnly: isAudioOnly)
            .subscribe(onSuccess: { [weak self] callModel in
                self?.call = callModel
                if self?.isBoothMode() ?? false {
                    return
                }
                self?.callsProvider
                    .startCall(account: account, call: callModel)
                self?.callStarted.accept(true)
            }, onFailure: { [weak self] _ in
                self?.callFailed.accept(true)
            })
            .disposed(by: disposeBag)
    }

    func showContactPickerVC() {
        stateSubject.onNext(ConversationState.showContactPicker(
            callID: conferenceId,
            contactSelectedCB: { [weak self] contacts in
                guard let self = self,
                      let contact = contacts.first,
                      let contactToAdd = contact.contacts.first,
                      let account = self.accountService
                        .getAccount(fromAccountId: contactToAdd.accountID),
                      let call = self.callService.call(callID: self.conferenceId) else { return }
                if contact.conferenceID.isEmpty {
                    self.callService
                        .callAndAddParticipant(participant: contactToAdd.uri,
                                               toCall: self.conferenceId,
                                               withAccount: account,
                                               userName: contactToAdd.registeredName,
                                               videSource: self.videoService.getVideoSource(),
                                               isAudioOnly: call.isAudioOnly)
                        .subscribe()
                        .disposed(by: self.disposeBag)
                    return
                }
                guard let secondCall = self.callService.call(callID: contact.conferenceID)
                else { return }
                if call.participantsCallId.count == 1 {
                    self.callService.joinCall(
                        firstCallId: call.callId,
                        secondCallId: secondCall.callId
                    )
                } else {
                    self.callService.joinConference(
                        confID: contact.conferenceID,
                        callID: self.conferenceId
                    )
                }
            },
            conversationSelectedCB: nil
        ))
    }

    func showConversations() {
        guard let call = call else {
            return
        }
        guard let jamiId = JamiURI(schema: URIType.ring, infoHash: call.participantUri).hash else {
            return
        }

        guard let conversation = conversationService.getConversationForParticipant(
            jamiId: jamiId,
            accontId: call.accountId
        ) else {
            return
        }
        stateSubject.onNext(ConversationState.openConversationFromCall(conversation: conversation))
    }

    func togglePauseCall() {
        guard let call = call else {
            return
        }
        if call.state == .current {
            callService.hold(callId: call.callId)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.info("call paused")
                }, onError: { [weak self] error in
                    self?.log.info(error)
                })
                .disposed(by: disposeBag)
        } else if call.state == .hold {
            callService.unhold(callId: call.callId)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.info("call unpaused")
                }, onError: { [weak self] error in
                    self?.log.info(error)
                })
                .disposed(by: disposeBag)
        }
    }

    func toggleMuteAudio() {
        guard let call = call else { return }
        let callId = (isHost ?? false) ? conferenceId : call.callId
        guard let callToMute = callService.call(callID: callId) else { return }
        let device = videoService.getCurrentVideoSource()
        callService.updateCallMediaIfNeeded(call: callToMute)
        videoService.requestMediaChange(call: callToMute, mediaLabel: "audio_0", source: device)
        updateCallStateForConferenceHost()
    }

    func toggleMuteVideo() {
        guard let call = call else { return }
        let callId = (isHost ?? false) ? conferenceId : call.callId
        guard let callToMute = callService.call(callID: callId) else { return }
        let device = videoService.getCurrentVideoSource()
        callService.updateCallMediaIfNeeded(call: callToMute)
        videoService.requestMediaChange(call: callToMute, mediaLabel: "video_0", source: device)
        updateCallStateForConferenceHost()
    }

    func updateCallStateForConferenceHost() {
        if isHost ?? false,
           let call = callService.call(callID: conferenceId) {
            currentCallVariable.accept(call)
        }
    }

    func switchCamera() {
        videoService.switchCamera()
        videoService.setCameraOrientation(
            orientation: UIDevice.current.orientation,
            forceUpdate: true
        )
    }

    func switchSpeaker() {
        audioService.switchSpeaker()
    }

    func setCameraOrientation(orientation: UIDeviceOrientation) {
        videoService.setCameraOrientation(orientation: orientation)
    }

    func showDialpad() {
        stateSubject.onNext(ConversationState.showDialpad(inCall: true))
    }

    func localId() -> String {
        return accountService.currentAccount?.jamiId ?? ""
    }

    func isIncoming() -> Bool {
        return call?.callType == .incoming
    }

    func hasVideo() -> Bool {
        return !(call?.isAudioOnly ?? true)
    }

    func callId() -> String {
        return call?.callId ?? ""
    }

    func reopenCall(viewControler: CallViewController) {
        stateSubject.onNext(ConversationState.reopenCall(viewController: viewControler))
    }
}
