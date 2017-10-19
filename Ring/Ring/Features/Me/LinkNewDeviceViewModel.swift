/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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
import RxSwift
import RxDataSources

enum GeneratePinState: Int {
    case success = 0
    case wrongPassword = 1
    case couldNotConnect = 2
}

enum GeneratePinError {
    case wrongPasswordError
    case networkError
    case defaultError

    var description: String {
        switch self {
        case .wrongPasswordError:
            return L10n.Linkdevice.passwordError
        case .networkError:
            return L10n.Linkdevice.networkError
        case .defaultError:
            return L10n.Linkdevice.defaultError
        }
    }
}

enum GeneretingPinState {

    case initial
    case generetingPin
    case success(pin: String)
    case error(error: GeneratePinError)

    var rawValue: String {
        switch self {
        case .initial:
            return "INITIAL"
        case .generetingPin:
            return "GENERETING_PIN"
        case .success:
            return "SUCCESS"
        case .error:
            return "ERROR"
        }
    }

    func isStateOfType(type: String) -> Bool {

        return self.rawValue == type
    }
}

class LinkNewDeviceViewModel: ViewModel, Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject <State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let generetingState = Variable(GeneretingPinState.initial)
    lazy var observableState: Observable <GeneretingPinState> = {
           return self.generetingState.asObservable()
    }()

    lazy var isInitialState: Observable<Bool> = {
        return self.observableState.map { state in
            return !state.isStateOfType(type: "INITIAL")
        }
    }()

    lazy var isSuccessState: Observable<Bool> = {
        return self.observableState.map { state in
           return !state.isStateOfType(type: "SUCCESS")
        }
    }()

    lazy var isErrorState: Observable<Bool> = {
        return self.observableState.map { state in
            return !state.isStateOfType(type: "ERROR")
        }
    }()

    lazy var isGeneratedPinState: Observable<Bool> = {
        return self.observableState.map { state in
           return !state.isStateOfType(type: "GENERETING_PIN")
        }
    }()

    let accountService: AccountsService

    let disposeBag = DisposeBag()

    // MARK: L10n
    let linkDeviceTitleTitle  = L10n.Linkdevice.title
    let explanationMessage = L10n.Linkdevice.explanationMessage

    required init(with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService

    }

    func linkDevice(with password: String?) {
        self.generetingState.value = GeneretingPinState.generetingPin
        guard let password = password else {
            self.generetingState.value = GeneretingPinState.error(error: GeneratePinError.wrongPasswordError)
            return
        }
        self.accountService.exportOnRing(withPassword: password).subscribe(onCompleted: {
            if let account = self.accountService.currentAccount {
                let accountHelper = AccountModelHelper(withAccount: account)
                let uri = accountHelper.ringId
            self.accountService.sharedResponseStream
                .filter({ exportComplitedEvent in
                    return exportComplitedEvent.eventType == ServiceEventType.exportOnRingEnded
                    && exportComplitedEvent.getEventInput(.uri) == uri
                })
                .subscribe(onNext: { [unowned self] exportComplitedEvent in
                    if let state: Int = exportComplitedEvent.getEventInput(.state) {
                        switch state {
                        case GeneratePinState.success.rawValue:
                            if let pin: String = exportComplitedEvent.getEventInput(.pin) {
                             self.generetingState.value = GeneretingPinState.success(pin: pin)
                            } else {
                                self.generetingState.value = GeneretingPinState.error(error: GeneratePinError.defaultError)
                            }
                        case GeneratePinState.wrongPassword.rawValue:
                            self.generetingState.value = GeneretingPinState.error(error: GeneratePinError.wrongPasswordError)
                        case GeneratePinState.couldNotConnect.rawValue:
                            self.generetingState.value = GeneretingPinState.error(error: GeneratePinError.networkError)
                        default:
                             self.generetingState.value = GeneretingPinState.error(error: GeneratePinError.defaultError)
                        }

                    }
                })
                .disposed(by: self.disposeBag)
            }
        }) { _ in
           self.generetingState.value = GeneretingPinState.error(error: GeneratePinError.wrongPasswordError)
        }.addDisposableTo(self.disposeBag)
    }

    func refresh() {

        self.generetingState.value = GeneretingPinState.initial

    }
}
