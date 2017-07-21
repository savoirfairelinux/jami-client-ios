/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

class CallViewModel: NSObject {

    var call: CallModel?
    fileprivate let callService: CallsService
    fileprivate let contactsService: ContactsService
    fileprivate let disposeBag: DisposeBag
    fileprivate let log = SwiftyBeaver.self

    let hideIgnoreButton: Observable<Bool>
    let hideCancelButton: Observable<Bool>
    let hideAnswerButton: Observable<Bool>

    let contactImageData: Observable<Data?>
    let contactName: Observable<String>
    let info: Observable<String>
    let callDuration: Observable<String>
    let bottomInfo: Observable<String>
    let saveVCard: Observable<(CallModel, CNContact)>

    init(withCallsService callsService: CallsService, contactsService: ContactsService, call: CallModel) {
        self.callService = callsService
        self.contactsService = contactsService
        self.call = call

        let disposeBag = DisposeBag()
        self.disposeBag = disposeBag

        self.hideIgnoreButton = callsService.incomingCall.map({ call in
            return call.state != .incoming
        })

        self.hideCancelButton = callsService.incomingCall.map({ call in
            return call.state != .ringing && call.state != .current
        })

        self.hideAnswerButton = callsService.incomingCall.map({ call in
            return call.state != .incoming
        })

        self.contactImageData = callsService.receivedVCard.asObservable().map({ vCard in
            return vCard.imageData
        })

        self.contactName = callsService.incomingCall.filter({ call in
            return call.state != .over && call.state != .inactive
        }).map({ call in
            if !call.displayName.isEmpty {
                return call.displayName
            } else if !call.registeredName.isEmpty {
                return call.registeredName
            } else {
                return "Unknown"
            }
        })

        self.info = callsService.incomingCall.map({ call in
            if call.state == .incoming {
                return "wants to talk to you"
            } else {
                return ""
            }
        })

        let timer = Observable<Int>.interval(1, scheduler: MainScheduler.instance)
            .takeUntil(self.callService.incomingCall.filter { call in call.state == .over })
            .map({ elapsed in
                return CallViewModel.formattedDurationFrom(interval: elapsed)
            })

        self.callDuration = self.callService.incomingCall.filter({ call in
            return call.state == .current
        }).flatMap({ _ in
            return timer
        })

        self.bottomInfo = callsService.incomingCall.map({ call in
            if call.state == .ringing {
                return "Calling..."
            } else if call.state == .over {
                return "Call finished..."
            } else {
                return ""
            }
        })

        self.saveVCard = Observable<(CallModel, CNContact)>.zip(self.callService.incomingCall.asObserver(),
                                               self.callService.receivedVCard,
                                               resultSelector: {($0, $1)})

        saveVCard.subscribe(onNext: { (call, vCard) in
            contactsService.saveVCard(vCard: vCard, withName: call.fromRingId)
                .subscribe()
                .disposed(by: disposeBag)
        }).disposed(by: disposeBag)
        
    }

    static func formattedDurationFrom(interval: Int) -> String {
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func ignoreCall() {
        self.callService.refuse(call: self.call!).subscribe(onCompleted: {
            self.log.info("Call ignored")
        }, onError: { error in
            self.log.error("Failed to ignore the call")
        }).disposed(by: self.disposeBag)
    }

    func cancelCall() {
        self.callService.hangUp(call: self.call!).subscribe(onCompleted: {
            self.log.info("Call canceled")
        }, onError: { error in
            self.log.error("Failed to cancel the call")
        }).disposed(by: self.disposeBag)
    }

    func answerCall() {
        self.callService.accept(call: self.call!).subscribe(onCompleted: {
            self.log.info("Call answered")
        }, onError: { error in
            self.log.error("Failed to answer the call")
        }).disposed(by: self.disposeBag)
    }

//TODO: Place call...
//    func placeCall() {
//        self.callService.placeCall(toContact: ContactModel).subscribe(onCompleted: {
//            self.log.info("Call placed")
//        }, onError: { error in
//            self.log.error("Failed to place the call")
//        }).disposed(by: self.disposeBag)
//    }
}
