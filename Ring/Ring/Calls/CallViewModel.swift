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
class CallViewModel: Stateable, ViewModel {

    //stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    let callService: CallsService
    private let contactsService: ContactsService
    private let accountService: AccountsService
    private let videoService: VideoService
    private let audioService: AudioService
    private let profileService: ProfilesService
    private let conversationService: ConversationsService

    private let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self
    private let menuItemsManager = ConferenceMenuItemsManager()

    var isHeadsetConnected = false
    var isAudioOnly = false

    private lazy var currentCallVariable: BehaviorRelay<CallModel> = {
        BehaviorRelay<CallModel>(value: self.call ?? CallModel())
    }()
    lazy var currentCall: Observable<CallModel> = {
        currentCallVariable.asObservable()
    }()
    private var callDisposeBag = DisposeBag()

    var conferenceMode: BehaviorRelay<Bool> = BehaviorRelay<Bool>(value: false)

    var call: CallModel? {
        didSet {
            guard let call = self.call else {
                return
            }
            guard let account = self.accountService.currentAccount else { return }
            isHeadsetConnected = self.audioService.isHeadsetConnected.value
            isAudioOnly = call.isAudioOnly
            let type = account.type == AccountType.sip
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
            self.callService.currentConferenceEvent
                .asObservable()
                .filter({ [weak self] conference-> Bool in
                    return conference.calls.contains(self?.call?.callId ?? "") ||
                        conference.conferenceID == self?.rendererId
                })
                .subscribe(onNext: { [weak self] conf in
                    if conf.conferenceID.isEmpty {
                        return
                    }
                    if conf.state == ConferenceState.infoUpdated.rawValue {
                        self?.layoutUpdated.accept(true)
                        return
                    }
                    guard let updatedCall = self?.callService.call(callID: call.callId) else { return }
                    self?.call = updatedCall
                    let conferenceCreated = conf.state == ConferenceState.conferenceCreated.rawValue
                    self?.rendererId = conferenceCreated ? conf.conferenceID : self!.call!.callId
                    self?.containerViewModel?.isConference = conferenceCreated
                    self?.conferenceMode.accept(conferenceCreated)
                })
                .disposed(by: self.disposeBag)
            self.rendererId = call.callId
            containerViewModel =
                ButtonsContainerViewModel(isAudioOnly: self.isAudioOnly,
                                          with: self.callService,
                                          audioService: self.audioService,
                                          callID: call.callId,
                                          isSipCall: type,
                                          isIncoming: call.callType == .incoming)
            currentCall
                .map({ call in
                    return call.state == .current
                })
                .subscribe(onNext: { [weak self] _ in
                    self?.videoService
                        .setCameraOrientation(orientation: UIDevice.current.orientation)
                })
                .disposed(by: self.disposeBag)
        }
    }

    // data for ViewController binding

    var layoutUpdated = BehaviorRelay<Bool>(value: false)

    lazy var contactImageData: Observable<Data?>? = {
        guard let call = self.call,
            let account = self.accountService.getAccount(fromAccountId: call.accountId) else {
            return nil
        }
        let type = account.type == AccountType.sip ? URIType.sip : URIType.ring
        guard let uriString = JamiURI.init(schema: type,
                                           infoHach: call.participantUri,
                                           account: account).uriString else { return nil }
        return self.profileService.getProfile(uri: uriString,
                                              createIfNotexists: true, accountId: account.id)
            .filter({ [weak self] profile in
                guard let self = self else { return false }
                if let alias = profile.alias {
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

    lazy var incomingFrame: Observable<UIImage?> = {
        return videoService.incomingVideoFrame.asObservable()
            .filter({[weak self] renderer -> Bool in
                (renderer?.rendererId == self?
                    .rendererId)
            })
            .map({ renderer in
                return renderer?.data
        })
    }()

    var rendererId = ""
    lazy var capturedFrame: Observable<UIImage?> = {
        if !(self.call?.isAudioOnly ?? true) {
            videoService.startVideoCaptureBeforeCall()
        }
        return videoService.capturedVideoFrame.asObservable().map({ frame in
            return frame
        })
    }()

    lazy var dismisVC: Observable<Bool> = {
        return currentCall
            .filter({ call in
                return !call.isExists()
            })
            .map({ [weak self] call in
                let hide = !call.isExists()
                //if it was conference call switch to another running call
                if hide && call.participantsCallId.count > 1 {
                    //switch to another call
                    let anotherCalls = call.participantsCallId.filter { (callID) -> Bool in
                        self?.callService.call(callID: callID) != nil && callID != call.callId
                    }
                    if let anotherCallid = anotherCalls.first, let anotherCall = self?.callService.call(callID: anotherCallid) {
                        self?.call = anotherCall
                        if anotherCall.participantsCallId.count == 1 {
                            self?.rendererId = anotherCallid
                        }
                        self?.callsProvider.stopCall(callUUID: call.callUUID)
                        return !hide
                    }
                }
                if hide {
                    self?.videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
                    self?.callsProvider.stopCall(callUUID: call.callUUID)
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
            .takeUntil(currentCall
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

    lazy var isActiveVideoCall: Observable<Bool> = { [weak self] in
        return currentCall
              .map({ call in
                return call.state == .current && !(self?.isAudioOnly ?? false)
            })
    }()

    lazy var showCallOptions: Observable<Bool> = {
        return self.screenTapped.asObservable()
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

    lazy var showCapturedFrame: Observable<Bool> = {
        return currentCall
            .filter({ call in
                return call.isActive()
            })
            .map({ call in
                call.state == .current
            })
    }()

    var screenTapped = BehaviorSubject(value: false)

    lazy var videoButtonState: Observable<UIImage?> = {
        let onImage = UIImage(asset: Asset.videoRunning)
        let offImage = UIImage(asset: Asset.videoMuted)

        return self.videoMuted.map({ [weak self] muted in
            let audioOnly = self?.call?.isAudioOnly ?? false
            if audioOnly || muted {
                return offImage
            }
            return onImage
        })
    }()

    lazy var videoMuted: Observable<Bool> = {
        return currentCall
            .filter({ call in
                call.state == .current
            })
            .map({call in
                return call.videoMuted
            })
    }()

    lazy var audioButtonState: Observable<UIImage?> = {
        let onImage = UIImage(asset: Asset.audioRunning)
        let offImage = UIImage(asset: Asset.audioMuted)

        return self.audioMuted.map({ muted in
            if muted {
                return offImage
            }
            return onImage
        })
    }()

    lazy var speakerButtonState: Observable<UIImage?> = {
        let offImage = UIImage(asset: Asset.disableSpeakerphone)
        let onImage = UIImage(asset: Asset.enableSpeakerphone)

        return self.isOutputToSpeaker
            .map({ speaker in
                if speaker {
                    return onImage
                }
                return offImage
            })
    }()

    lazy var isOutputToSpeaker: Observable<Bool> = {
        return self.audioService.isOutputToSpeaker.asObservable()
    }()

    lazy var speakerSwitchable: Observable<Bool> = {
        return self.audioService.isHeadsetConnected.asObservable()
            .map { value in return !value }
    }()

    lazy var audioMuted: Observable<Bool> = {
        return currentCall
            .filter({ call in
                call.state == .current
            })
            .map({call in
                return call.audioMuted
            })
    }()

    lazy var pauseCallButtonState: Observable<UIImage?> = {
        let unpauseCall = UIImage(asset: Asset.unpauseCall)
        let pauseCall = UIImage(asset: Asset.pauseCall)

        return self.callPaused.map({ muted in
            if muted {
                return unpauseCall
            }
            return pauseCall
        })
    }()

    lazy var callPaused: Observable<Bool> = {
        return currentCall
            .filter({ call in
                (call.state == .hold ||
                    call.state == .unhold ||
                    call.state == .current)
            })
            .map({call in
                if  call.state == .hold ||
                    (call.state == .current && call.peerHolding) {
                    return true
                }
                return false
            })
    }()

    lazy var callForConference: Observable<CallModel> = {
        return callService.inConferenceCalls.asObservable()
    }()

    var containerViewModel: ButtonsContainerViewModel?
    let injectionBag: InjectionBag
    let callsProvider: CallsProviderDelegate

    required init(with injectionBag: InjectionBag) {
        self.callService = injectionBag.callService
        self.contactsService = injectionBag.contactsService
        self.accountService = injectionBag.accountService
        self.videoService = injectionBag.videoService
        self.audioService = injectionBag.audioService
        self.profileService = injectionBag.profileService
        self.callsProvider = injectionBag.callsProvider
        self.injectionBag = injectionBag
        self.conversationService = injectionBag.conversationsService
        callsProvider.sharedResponseStream
            .filter({ [weak self] serviceEvent in
                guard let callUUID: String = serviceEvent
                    .getEventInput(ServiceEventInput.callUUID) else { return false }
                return callUUID == self?.call?.callUUID.uuidString
            })
            .subscribe(onNext: { [weak self] serviceEvent in
                guard let self = self else { return }
                if serviceEvent.eventType == ServiceEventType.callProviderAnswerCall {
                    self.answerCall()
                        .subscribe()
                        .disposed(by: self.disposeBag)
                } else if serviceEvent.eventType == ServiceEventType.callProviderCancellCall {
                    self.cancelCall(stopProvider: false)
                }
            })
            .disposed(by: self.disposeBag)

        callsProvider.sharedResponseStream
            .filter({ serviceEvent in
                serviceEvent.eventType == .audioActivated
            })
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.audioService.startAudio()
                //for outgoing calls ve create audio sesion with default parameters.
                //for incoming call audio session is created, ve need to override it
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

    func respondOnTap() {
        self.screenTapped.onNext(true)
    }

    func isBoothMode() -> Bool {
        return self.accountService.boothMode()
    }

    func callFinished() {
        guard let accountId = self.call?.accountId else {
            return
        }
        if self.isBoothMode() {
            self.contactsService.removeAllContacts(for: accountId)
            return
        }
        self.showConversations()
    }
}

// MARK: actions
extension CallViewModel {

    func cancelCall(stopProvider: Bool) {
        guard let call = self.call else {
            return
        }
        if stopProvider {
            self.callsProvider.stopCall(callUUID: call.callUUID)
            call.participantsCallId.forEach { (callId) in
                if let participantCall = self.callService.call(callID: callId) {
                    self.callsProvider.stopCall(callUUID: participantCall.callUUID)
                }
            }
        }
        self.callService
            .hangUpCallOrConference(callId: rendererId)
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func answerCall() -> Completable {
        return self.callService.accept(call: call)
    }

    func placeCall(with uri: String, userName: String, isAudioOnly: Bool = false) {
        guard let account = self.accountService.currentAccount else {
            return
        }
        self.callService.placeCall(withAccount: account,
                                   toRingId: uri,
                                   userName: userName,
                                   isAudioOnly: isAudioOnly)
            .subscribe(onSuccess: { [weak self] callModel in
                callModel.callUUID = UUID()
                self?.call = callModel
                if self?.isBoothMode() ?? false {
                    return
                }
                self?.callsProvider
                    .startCall(account: account, call: callModel)
            })
            .disposed(by: self.disposeBag)
    }

    func showContactPickerVC() {
        self.stateSubject.onNext(ConversationState.showContactPicker(callID: rendererId, contactSelectedCB: { [weak self] (contacts) in
            guard let self = self,
                let contact = contacts.first,
                let contactToAdd = contact.contacts.first,
                let account = self.accountService.getAccount(fromAccountId: contactToAdd.accountID),
                let call = self.callService.call(callID: self.rendererId) else { return }
            if contact.conferenceID.isEmpty {
                self.callService
                    .callAndAddParticipant(participant: contactToAdd.uri,
                                           toCall: self.rendererId,
                                           withAccount: account,
                                           userName: contactToAdd.registeredName,
                                           isAudioOnly: call.isAudioOnly)
                    .subscribe()
                    .disposed(by: self.disposeBag)
                return
            }
            guard let secondCall = self.callService.call(callID: contact.conferenceID) else { return }
            if call.participantsCallId.count == 1 {
                self.callService.joinCall(firstCall: call.callId, secondCall: secondCall.callId)
            } else {
                self.callService.joinConference(confID: contact.conferenceID, callID: self.rendererId)
            }
        }))
    }

    func showConversations() {
        guard let call = self.call else {
            return
        }
        guard let uri = JamiURI(schema: URIType.ring, infoHach: call.participantUri).uriString else {
            return
        }

        guard let conversation = self.conversationService.findConversation(withUri: uri, withAccountId: call.accountId) else {
            return
        }
        let conversationViewModel = ConversationViewModel(with: self.injectionBag)
        conversationViewModel.conversation = BehaviorRelay<ConversationModel>(value: conversation)
        self.stateSubject.onNext(ConversationState.fromCallToConversation(conversation: conversationViewModel))
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
        guard let call = self.call else {
            return
        }
        let mute = !call.audioMuted
        self.callService.muteAudio(call: call.callId, mute: mute)
    }

    func toggleMuteVideo() {
        guard let call = self.call else {
            return
        }
        let mute = !call.videoMuted
        self.callService.muteVideo(call: call.callId, mute: mute)
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
}
// MARK: conference layout
extension CallViewModel {
    func setActiveParticipant(callId: String?, maximize: Bool) {
        self.callService.setActiveParticipant(callId: callId, conferenceId: self.rendererId, maximixe: maximize)
    }

    func getConferenceVideoSize() -> CGSize {
        return self.videoService.getConferenceVideoSize(confId: self.rendererId)
    }

    func getConferenceParticipants() -> [ConferenceParticipant]? {
        guard let account = self.accountService.currentAccount,
            let participants = self.callService.getConferenceParticipants(for: self.rendererId),
            let call = self.call else { return nil }
        participants.forEach { participant in
            guard let uri = participant.uri else { return }
            // master call
            if uri.isEmpty {
                //check if master call is local or remote
                if !self.conferenceMode.value {
                    participant.displayName = call.getDisplayName()
                } else {
                    participant.displayName = L10n.Account.me
                }
                return
            }
            guard let call = self.callService.call(participantHash: uri.filterOutHost(), accountID: account.id) else { return }
            participant.displayName = call.getDisplayName()
        }
        return participants
    }

    func getItemsForConferenceMenu(participantCallId: String?) -> MenuMode {
        let conference = self.callService.call(callID: self.rendererId)
        // menu for master call
        guard let callId = participantCallId else {
            let active = self.callService.isParticipant(participantURI: "", activeIn: self.rendererId)
            return menuItemsManager.getMenuItemsForMasterCall(conference: conference, active: active)
        }
        let call = self.callService.call(callID: callId)
        let active = self.callService.isParticipant(participantURI: call?.participantUri, activeIn: self.rendererId)
        return menuItemsManager.getMenuItemsFor(call: call, conference: conference, active: active)
    }
}
