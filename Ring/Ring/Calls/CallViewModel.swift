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

    var call: CallModel?
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    fileprivate let callService: CallsService
    fileprivate let contactsService: ContactsService
    private let disposeBag = DisposeBag()
    fileprivate let log = SwiftyBeaver.self

//    let hideIgnoreButton: Observable<Bool>
//    let hideCancelButton: Observable<Bool>
//    let hideAnswerButton: Observable<Bool>
//
//    let contactImageData: Observable<Data?>
//    let contactName: Observable<String>
//    let info: Observable<String>
//    let callDuration: Observable<String>
//    let bottomInfo: Observable<String>
//    let saveVCard: Observable<(CallModel, CNContact)>

    required init(with injectionBag: InjectionBag) {

        self.callService = injectionBag.callService
        self.contactsService = injectionBag.contactsService
    }
//
//        self.hideIgnoreButton = self.callService.currentCall.map({ call in
//            return call.state == .incoming
//        }).map({ show in
//            return !show
//        })
//
//        self.hideCancelButton = self.callService.currentCall.map({ call in
//            return call.state == .connecting || call.state == .ringing || call.state == .current
//        }).map({ show in
//            return !show
//        })
//
//        self.hideAnswerButton = callService.currentCall.map({ call in
//            return call.state == .incoming
//        }).map({ show in
//            return !show
//        })
//
//        self.contactImageData = callService.receivedVCard.asObservable().map({ vCard in
//            return vCard.imageData
//        })
//
//        self.contactName = callService.currentCall.filter({ call in
//            return call.state != .over && call.state != .inactive
//        }).map({ call in
//            if !call.displayName.isEmpty {
//                return call.displayName
//            } else if !call.registeredName.isEmpty {
//                return call.registeredName
//            } else {
//                return L10n.Calls.unknown
//            }
//        })
//
//        self.info = callService.currentCall.map({ call in
//            if call.state == .incoming {
//                return L10n.Calls.incomingCallInfo
//            } else {
//                return ""
//            }
//        })
//
//        let timer = Observable<Int>.interval(1, scheduler: MainScheduler.instance)
//            .takeUntil(self.callService.currentCall.filter { call in call.state == .over })
//            .map({ elapsed in
//                return CallViewModel.formattedDurationFrom(interval: elapsed)
//            })
//
//        self.callDuration = self.callService.currentCall.filter({ call in
//            return call.state == .current
//        }).flatMap({ _ in
//            return timer
//        })
//
//        self.bottomInfo = callService.currentCall.map({ call in
//            if call.state == .connecting || call.state == .ringing && call.callType == .outgoing {
//                return L10n.Calls.calling
//            } else if call.state == .over {
//                return L10n.Calls.callFinished
//            } else {
//                return ""
//            }
//        })
//
//        self.saveVCard = Observable<(CallModel, CNContact)>.zip(self.callService.currentCall.asObserver(),
//                                                                self.callService.receivedVCard,
//                                                                resultSelector: {($0, $1)})
//
//        saveVCard.subscribe(onNext: { (call, vCard) in
//            self.contactsService.saveVCard(vCard: vCard, withName: call.fromRingId)
//                .subscribe()
//                .disposed(by: self.disposeBag)
//        }).disposed(by: disposeBag)
//    }
//    static func formattedDurationFrom(interval: Int) -> String {
//        let seconds = interval % 60
//        let minutes = (interval / 60) % 60
//        let hours = (interval / 3600)
//        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
//    }
//
//    func ignoreCall() {
//        self.callService.refuse(call: self.call!).subscribe(onCompleted: {
//            self.log.info("Call ignored")
//        }, onError: { error in
//            self.log.error("Failed to ignore the call")
//        }).disposed(by: self.disposeBag)
//    }
//
//    func cancelCall() {
//        self.callService.hangUp(call: self.call!).subscribe(onCompleted: {
//            self.log.info("Call canceled")
//        }, onError: { error in
//            self.log.error("Failed to cancel the call")
//        }).disposed(by: self.disposeBag)
//    }
//
//    func answerCall() {
//        self.callService.accept(call: self.call!).subscribe(onCompleted: {
//            self.log.info("Call answered")
//        }, onError: { error in
//            self.log.error("Failed to answer the call")
//        }).disposed(by: self.disposeBag)
//    }

}
