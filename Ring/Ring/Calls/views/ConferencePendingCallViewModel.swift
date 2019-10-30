/*
*  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import RxSwift
import RxCocoa

class ConferencePendingCallViewModel {
    let call: CallModel
    let callsSercive: CallsService
    lazy var observableCall = {
        self.callsSercive.currentCall(callId: call.callId)
    }()
    let disposeBag = DisposeBag()

    init(with call: CallModel, callsService: CallsService) {
        self.call = call
        self.callsSercive = callsService
    }

    lazy var displayName: Driver<String> = {
        var name = self.call.displayName.isEmpty ? self.call.registeredName : self.call.displayName
        name = name.isEmpty ? self.call.paricipantHash() : name
        return Observable.just(name).asDriver(onErrorJustReturn: "")
    }()

    lazy var removeView: Observable<Bool> = {
        return self.observableCall
            .map({ callModel in
                return (callModel.state == .over ||
                    callModel.state == .current ||
                    callModel.state == .failure ||
                    callModel.state == .hungup ||
                    callModel.state == .busy)
            })
    }()

    func cancelCall() {
        self.callsSercive.hangUp(callId: call.callId)
            .subscribe(onCompleted: {
            }).disposed(by: disposeBag)
    }
}
