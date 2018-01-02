/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

import RxSwift
import SwiftyBeaver
import Contacts

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
    private let disposeBag = DisposeBag()
    fileprivate let log = SwiftyBeaver.self

    lazy var incomingFrame: Observable<UIImage?> = {
        return videoService.incomingVideoFrame.asObservable().map({ frame in
            return frame
        })
    }()
    lazy var capturedFrame: Observable<UIImage?> = {
        return videoService.capturedVideoFrame.asObservable().map({ frame in
            return frame
        })
    }()

    var call: CallModel? {
        didSet {
            guard let call = self.call else {
                return
            }
            self.contactsService.getProfileForUri(uri: call.participantRingId)
                .subscribe(onNext: { [unowned self] profile in
                    self.profileUpdated(profile: profile)
                })
                .disposed(by: self.disposeBag)

            self.callService
                .sharedResponseStream
                .filter({ (event) in
                    if let uri: String = event.getEventInput(ServiceEventInput.uri) {
                        return event.eventType == ServiceEventType.profileUpdated
                            && uri == call.participantRingId
                    }
                    return false
                })
                .subscribe(onNext: { [unowned self] _ in
                    self.contactsService.getProfileForUri(uri: call.participantRingId)
                        .subscribe(onNext: { profile in
                            self.profileUpdated(profile: profile)
                        })
                        .disposed(by: self.disposeBag)
                })
                .disposed(by: disposeBag)
        }
    }

    // data for ViewCintroller binding

    var contactImageData = Variable<Data?>(nil)

    lazy var dismisVC: Observable<Bool> = {
        return callService.currentCall.map({[weak self] call in
            return call.state == .over || call.state == .failure && call.callId == self?.call?.callId
        }).map({ hide in
            return hide
        })
    }()

    lazy var contactName: Observable<String> = {
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
        })
    }()

    lazy var callDuration: Observable<String> = {
        let timer = Observable<Int>.interval(1, scheduler: MainScheduler.instance)
            .takeUntil(self.callService.currentCall
                .filter { [weak self] call in
                    call.state == .over &&
                        call.callId == self?.call?.callId
            })
            .map({ elapsed in
                return CallViewModel.formattedDurationFrom(interval: elapsed)
            })
        return self.callService.currentCall.filter({ call in
            return call.state == .current
        }).flatMap({ _ in
            return timer
        })
    }()

    lazy var bottomInfo: Observable<String> = {
        return callService.currentCall.map({ [weak self] call in
            if call.state == .connecting || call.state == .ringing && call.callType == .outgoing && call.callId == self?.call?.callId {
                return L10n.Calls.calling
            } else if call.state == .over {
                return L10n.Calls.callFinished
            } else {
                return ""
            }
        })
    }()

    required init(with injectionBag: InjectionBag) {
        self.callService = injectionBag.callService
        self.contactsService = injectionBag.contactsService
        self.accountService = injectionBag.accountService
        self.videoService = injectionBag.videoService
    }
    static func formattedDurationFrom(interval: Int) -> String {
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func cancelCall() {
        guard let call = self.call else {
            return
        }
        self.callService.hangUp(callId: call.callId)
            .subscribe(onCompleted: { [weak self] in
                self?.log.info("Call canceled")
                }, onError: { [weak self] error in
                    self?.log.error("Failed to cancel the call")
            }).disposed(by: self.disposeBag)
    }



    func answerCall() {
        guard let call = self.call else {
            return
        }
        self.callService.accept(callId: call.callId)
            .subscribe(onCompleted: { [weak self] in
                self?.log.info("Call answered")
                }, onError: { [weak self] error in
                    self?.log.error("Failed to answer the call")
            }).disposed(by: self.disposeBag)
    }

    func placeCall(with uri: String, userName: String) {

        guard let account = self.accountService.currentAccount else {
            return
        }
        self.callService.placeCall(withAccount: account,
                                   toRingId: uri,
                                   userName: userName)
            .subscribe(onSuccess: { [unowned self] callModel in
                self.call = callModel
            }).disposed(by: self.disposeBag)
    }

    func profileUpdated(profile: Profile) {
        guard let photo = profile.photo else {
            return
        }
        guard let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? else {
            return
        }
        self.contactImageData.value = data
    }
}
