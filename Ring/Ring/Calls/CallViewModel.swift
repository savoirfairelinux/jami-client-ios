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
import SwiftyBeaver
import Contacts
import RxCocoa
// swiftlint:disable type_body_length
class CallViewModel: Stateable, ViewModel {

    //stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    fileprivate let callService: CallsService
    fileprivate let contactsService: ContactsService
    fileprivate let accountService: AccountsService
    fileprivate let videoService: VideoService
    fileprivate let audioService: AudioService
    fileprivate let profileService: ProfilesService

    private let disposeBag = DisposeBag()
    fileprivate let log = SwiftyBeaver.self

    var isHeadsetConnected = false
    var isAudioOnly = false

    var call: CallModel? {
        didSet {
            guard let call = self.call else {
                return
            }
            guard let account = self.accountService.currentAccount else {return}
            isHeadsetConnected = self.audioService.isHeadsetConnected.value
            isAudioOnly = call.isAudioOnly
            let type = account.type == AccountType.sip

            containerViewModel =
                ButtonsContainerViewModel(isAudioOnly: self.isAudioOnly,
                                                           with: self.callService,
                                                           audioService: self.audioService,
                                                           callID: call.callId,
                                                           isSipCall: type,
                                                           isIncoming: call.callType == .incoming)
        }
    }

    // data for ViewController binding

    lazy var contactImageData: Observable<Data?>? = {
        guard let call = self.call,
            let account = self.accountService.getAccount(fromAccountId: call.accountId) else {
            return nil
        }
        let type = account.type == AccountType.sip ? URIType.sip : URIType.ring
        guard let uriString = JamiURI.init(schema: type,
                  infoHach: call.participantUri,
                  account: account).uriString else {return nil}
        return self.profileService.getProfile(uri: uriString,
                                              createIfNotexists: true, accountId: account.id)
            .filter({ profile in
                guard let photo = profile.photo else {
                    return false
                }
                return true
            }).map({ profile in
                return NSData(base64Encoded: profile.photo!,
                              options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?
            })
    }()

    lazy var incomingFrame: Observable<UIImage?> = {
        return videoService.incomingVideoFrame.asObservable().map({ frame in
            return frame
        })
    }()
    lazy var capturedFrame: Observable<UIImage?> = {
        videoService.startVideoCaptureBeforeCall()
        return videoService.capturedVideoFrame.asObservable().map({ frame in
            return frame
        })
    }()

    lazy var dismisVC: Observable<Bool> = {
        return callService.currentCall.filter({ [weak self] call in
            return call.callId == self?.call?.callId
        })
            .map({ call in
                return call.state == .over || call.state == .failure
            }).map({ [weak self] hide in
                if hide {
                    self?.videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
                    self?.videoService.stopAudioDevice()
                    if #available(iOS 10.0, *), let call = self?.call {
                        self?.callsProvider.stopCall(callUUID: call.callUUID)
                    }
                }
                return hide
            })
    }()

    lazy var contactName: Driver<String> = {
        return callService.currentCall.filter({ [weak self] call in
            return call.state != .over && call.state != .inactive && call.callId == self?.call?.callId
        }).map({ call in
            if !call.displayName.isEmpty {
                return call.displayName
            } else if !call.registeredName.isEmpty {
                return call.registeredName
            } else {
                return L10n.Calls.unknown
            }
        }).asDriver(onErrorJustReturn: "")
    }()

    lazy var callDuration: Driver<String> = {
        let timer = Observable<Int>.interval(1, scheduler: MainScheduler.instance)
            .takeUntil(self.callService.currentCall
                .filter { [weak self] call in
                    call.state == .over &&
                        call.callId == self?.call?.callId
            })
            .map({ elapsed in
                return CallViewModel.formattedDurationFrom(interval: elapsed)
            }).share()
        return self.callService.currentCall.filter({ [weak self] call in
            return call.state == .current &&
                call.callId == self?.call?.callId
        }).flatMap({ _ in
            return timer
        }).asDriver(onErrorJustReturn: "")
    }()

    lazy var bottomInfo: Observable<String> = {
        return callService
            .currentCall
            .filter({ [weak self] call in
                return call.callId == self?.call?.callId &&
                    call.callType == .outgoing
            }).map({ [weak self] call in
                switch call.state {
                case .connecting :
                    return L10n.Calls.connecting
                case .ringing :
                    return L10n.Calls.ringing
                case .over :
                    return L10n.Calls.callFinished
                case .unknown :
                    return L10n.Calls.searching
                default :
                    return ""
                }
        })
    }()

    lazy var isActiveVideoCall: Observable<Bool> = { [unowned self] in
        return (self.callService.currentCall
            .filter({call in
                return call.callId == self.call?.callId
            }).map({ call in
                return call.state == .current && !self.isAudioOnly
            }))
    }()

    lazy var showCallOptions: Observable<Bool> = { [unowned self] in
        return self.screenTapped.asObservable()
    }()

    lazy var showCancelOption: Observable<Bool> = { [unowned self] in
        return self.callService.currentCall
            .filter({ [weak self] call in
                return call.callId == self?.call?.callId &&
                    (call.state == .connecting || call.state == .ringing || call.state == .current)
            }).map({ call in
            return call.state == .connecting || call.state == .ringing
        })
    }()

    lazy var showCapturedFrame: Observable<Bool> = { [unowned self] in
        return self.callService.currentCall
            .filter({ [weak self] call in
                return call.callId == self?.call?.callId &&
                    (call.state == .connecting || call.state == .ringing || call.state == .current)
            }).map({ call in
                call.state == .current
            })
    }()

    var screenTapped = BehaviorSubject(value: false)

    lazy var videoButtonState: Observable<UIImage?> = { [unowned self] in
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

    lazy var videoMuted: Observable<Bool> = { [unowned self] in
        return self.callService.currentCall.filter({ [weak self] call in
            call.callId == self?.call?.callId &&
                call.state == .current
        }).map({call in
            return call.videoMuted
        })
    }()

    lazy var audioButtonState: Observable<UIImage?> = { [unowned self] in
        let onImage = UIImage(asset: Asset.audioRunning)
        let offImage = UIImage(asset: Asset.audioMuted)

        return self.audioMuted.map({ muted in
            if muted {
                return offImage
            }
            return onImage
        })
    }()

    lazy var speakerButtonState: Observable<UIImage?> = { [unowned self] in
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

    lazy var isOutputToSpeaker: Observable<Bool> = { [unowned self] in
        return self.audioService.isOutputToSpeaker.asObservable()
    }()

    lazy var speakerSwitchable: Observable<Bool> = { [unowned self] in
        return self.audioService.isHeadsetConnected.asObservable()
            .map { value in return !value }
    }()

    lazy var audioMuted: Observable<Bool> = { [unowned self] in
        return self.callService.currentCall.filter({ [weak self] call in
            call.callId == self?.call?.callId &&
                call.state == .current
        }).map({call in
            return call.audioMuted
        })
    }()

    lazy var pauseCallButtonState: Observable<UIImage?> = { [unowned self] in
        let unpauseCall = UIImage(asset: Asset.unpauseCall)
        let pauseCall = UIImage(asset: Asset.pauseCall)

        return self.callPaused.map({ muted in
            if muted {
                return unpauseCall
            }
            return pauseCall
        })
    }()

    lazy var callPaused: Observable<Bool> = { [unowned self] in
        return self.callService.currentCall.filter({ [weak self] call in
            call.callId == self?.call?.callId &&
                (call.state == .hold ||
                    call.state == .unhold ||
                    call.state == .current)
        }).map({call in
            if  call.state == .hold ||
                (call.state == .current && call.peerHolding) {
                return true
            }
            return false
        })
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

        callService.currentCall.filter({ [weak self] call in
            return call.callId == self?.call?.callId
        }).map({ call in
            return call.state == .current
        }).subscribe(onNext: { [weak self] _ in
            self?.videoService
                .setCameraOrientation(orientation: UIDevice.current.orientation)
        }).disposed(by: self.disposeBag)
        callsProvider.sharedResponseStream
            .filter({ [unowned self] serviceEvent in
                guard let callUUID: String = serviceEvent
                    .getEventInput(ServiceEventInput.callUUID) else {return false}
                return callUUID == self.call?.callUUID.uuidString
            }).subscribe(onNext: { [unowned self] serviceEvent in
                if serviceEvent.eventType == ServiceEventType.callProviderAnswerCall {
                    self.answerCall()
                        .subscribe()
                        .disposed(by: self.disposeBag)
                } else if serviceEvent.eventType == ServiceEventType.callProviderCancellCall {
                    self.cancelCall(stopProvider: false)
                }
            }).disposed(by: self.disposeBag)

        callsProvider.sharedResponseStream
            .filter({ serviceEvent in
                serviceEvent.eventType == .audioActivated
            }).subscribe(onNext: { [unowned self] _ in
                self.audioService.startAudio()
            }).disposed(by: self.disposeBag)
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

    func cancelCall(stopProvider: Bool) {
        guard let call = self.call else {
            return
        }
        if #available(iOS 10.0, *), stopProvider {
            self.callsProvider.stopCall(callUUID: call.callUUID)
        }
        self.callService.hangUp(callId: call.callId)
            .subscribe(onCompleted: { [weak self] in
                // switch to either spk or headset (if connected) for loud ringtone
                // incase we were using rcv during the call
                self?.audioService.setToRing()
                self?.videoService.stopAudioDevice()
                self?.log.info("Call canceled")
                }, onError: { [weak self] error in
                    self?.log.error("Failed to cancel the call")
            }).disposed(by: self.disposeBag)
    }

    func answerCall() -> Completable {
        if !self.audioService.isHeadsetConnected.value {
            isAudioOnly ?
                self.audioService.overrideToReceiver() : self.audioService.overrideToSpeaker()
        }
        return self.callService.accept(call: call)
    }

    func placeCall(with uri: String, userName: String, isAudioOnly: Bool = false) {
        guard let account = self.accountService.currentAccount else {
            return
        }
        if !self.audioService.isHeadsetConnected.value {
            isAudioOnly ?
                self.audioService.overrideToReceiver() : self.audioService.overrideToSpeaker()
        }
        self.callService.placeCall(withAccount: account,
                                   toRingId: uri,
                                   userName: userName,
                                   isAudioOnly: isAudioOnly)
            .subscribe(onSuccess: { [weak self] callModel in
                callModel.callUUID = UUID()
                self?.call = callModel
                if #available(iOS 10.0, *) {
                    self?.callsProvider
                        .startCall(account: account, call: callModel)
                }
            }).disposed(by: self.disposeBag)
    }

    func respondOnTap() {
        self.screenTapped.onNext(true)
    }

    // MARK: call options

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
                }).disposed(by: self.disposeBag)
        } else if call.state == .hold {
            self.callService.unhold(callId: call.callId)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.info("call unpaused")
                    }, onError: { [weak self](error) in
                        self?.log.info(error)
                }).disposed(by: self.disposeBag)
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
