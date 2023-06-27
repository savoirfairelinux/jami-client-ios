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

    func getJamiId() -> String? {
        guard let call = call else { return nil }
        return call.participantUri
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
            if !(self.call?.isAudioOnly ?? true) {
                self.videoService.startVideoCaptureBeforeCall()
            }
            self.conferenceId = call.callId
            currentCall
                .map({ call in
                    return call.state == .current
                })
                .subscribe(onNext: { [weak self] _ in
                    self?.videoService
                        .setCameraOrientation(orientation: UIDevice.current.orientation)
                })
                .disposed(by: self.disposeBag)
            self.callService.currentConferenceEvent
                .asObservable()
                .filter({ [weak self] conference -> Bool in
                    guard let self = self else { return false }
                    return conference.calls.contains(self.call?.callId ?? "") ||
                        conference.conferenceID == (self.call?.callId ?? "") ||
                        conference.conferenceID == self.conferenceId
                })
                .subscribe(onNext: { [weak self] conf in
                    guard let self = self else { return }
                    let conferenceDestroyed = conf.state == ConferenceState.conferenceDestroyed.rawValue
                    if conferenceDestroyed {
                        let calls = conf.calls
                        for callId in calls {
                            if let call = self.callService.call(callID: callId), call.state == .current {
                                self.call = call
                                self.conferenceId = call.callId
                                return
                            }
                        }
                        return
                    }
                    if let participants = self.callService.getConferenceParticipants(for: conf.conferenceID) {
                        if let participant = participants.first(where: { $0.uri == self.localId() }) {
                            if participant.sinkId.contains("host") {
                                self.isHost = true
                            } else {
                                self.isHost = false
                            }
                        }

                    }
                    self.conferenceId = conf.conferenceID
                })
                .disposed(by: self.disposeBag)
        }
    }

    // data for ViewController binding
    lazy var showRecordImage: Observable<Bool> = {
        return self.callService
            .currentCallsEvents
            .asObservable()
            .map({[weak self] call in
                guard let self = self else { return false }
                let showStatus = call.callRecorded
                return showStatus
            })
    }()

    lazy var contactImageData: Observable<Data?>? = {
        guard let call = self.call,
              let account = self.accountService.getAccount(fromAccountId: call.accountId) else {
            return nil
        }
        let type = account.type == AccountType.sip ? URIType.sip : URIType.ring
        guard let uriString = JamiURI.init(schema: type,
                                           infoHash: call.participantUri,
                                           account: account).uriString else { return nil }
        return self.profileService.getProfile(uri: uriString,
                                              createIfNotexists: true, accountId: account.id)
            .filter({ [weak self] profile in
                guard let self = self else { return false }
                if let alias = profile.alias, !alias.isEmpty {
                    self.call?.displayName = alias
                }
                guard let photo = profile.photo else {
                    return false
                }
                return true
            })
            .map({ profile in
                return NSData(base64Encoded: profile.photo!,
                              options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?
            })
    }()

    lazy var dismisVC: Observable<Bool> = {
        return currentCall
            .filter({ call in
                return !call.isExists()
            })
            .map({ [weak self] call in
                let hide = !call.isExists()
                // if it was conference call switch to another running call
                if hide && call.participantsCallId.count > 1 {
                    // switch to another call
                    let anotherCalls = call.participantsCallId.filter { (callID) -> Bool in
                        self?.callService.call(callID: callID) != nil && callID != call.callId
                    }
                    if let anotherCallid = anotherCalls.first, let anotherCall = self?.callService.call(callID: anotherCallid) {
                        self?.call = anotherCall
                        if anotherCall.participantsCallId.count == 1 {
                            self?.conferenceId = anotherCallid
                        }
                        return !hide
                    }
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

    lazy var bottomInfo: Observable<String> = {
        return currentCall
            .startWith(self.call ?? CallModel())
            .filter({call in
                return call.callType == .outgoing
            })
            .map({call in
                return call.state.toString()
            })
    }()

    lazy var showCancelOption: Observable<Bool> = {
        return currentCall
            .filter({ call in
                return call.isActive()
            })
            .map({ call in
                return call.state == .connecting || call.state == .ringing
            })
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
        self.showConversations()
    }

    var callCompleted = false
}

// MARK: actions
extension CallViewModel {

    func cancelCall() {
        self.callService
            .hangUpCallOrConference(callId: self.conferenceId)
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func answerCall() -> Completable {
        return self.callService.accept(call: call)
    }

    func placeCall(with uri: String, userName: String, account: AccountModel, isAudioOnly: Bool = false) {
        self.callService.placeCall(withAccount: account,
                                   toParticipantId: uri,
                                   userName: userName,
                                   videoSource: self.videoService.getVideoSource(),
                                   isAudioOnly: isAudioOnly)
            .subscribe(onSuccess: { [weak self] callModel in
                self?.call = callModel
                if self?.isBoothMode() ?? false {
                    return
                }
                self?.callsProvider
                    .startCall(account: account, call: callModel)
                self?.callStarted.accept(true)
            }, onFailure: {  [weak self] _ in
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
                    .subscribe()
                    .disposed(by: self.disposeBag)
                return
            }
            guard let secondCall = self.callService.call(callID: contact.conferenceID) else { return }
            if call.participantsCallId.count == 1 {
                self.callService.joinCall(firstCallId: call.callId, secondCallId: secondCall.callId)
            } else {
                self.callService.joinConference(confID: contact.conferenceID, callID: self.conferenceId)
            }
        }))
    }

    func showConversations() {
        guard let call = self.call else {
            return
        }
        guard let jamiId = JamiURI(schema: URIType.ring, infoHash: call.participantUri).hash else {
            return
        }

        guard let conversation = self.conversationService.getConversationForParticipant(jamiId: jamiId, accontId: call.accountId) else {
            return
        }
        self.stateSubject.onNext(ConversationState.openConversationFromCall(conversation: conversation))
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
        let callId = !(self.isHost ?? false) ? call.callId : self.conferenceId
        self.callService.requestMediaChange(call: conferenceId, mediaLabel: "audio_0")
    }

    func toggleMuteVideo() {
        guard let call = self.call else { return }
        let callId = !(self.isHost ?? false) ? call.callId : self.conferenceId
        self.callService.requestMediaChange(call: conferenceId, mediaLabel: "video_0")
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

    func reopenCall(viewControler: CallViewController) {
        stateSubject.onNext(ConversationState.reopenCall(viewController: viewControler))
    }

}
