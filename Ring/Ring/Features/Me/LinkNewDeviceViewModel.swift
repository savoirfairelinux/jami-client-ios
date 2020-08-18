/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

enum ExportAccountResponse: Int {
    case success = 0
    case wrongPassword = 1
    case networkProblem = 2
}

enum PinError {
    case passwordError
    case networkError
    case defaultError

    var description: String {
        switch self {
        case .passwordError:
            return L10n.LinkDevice.passwordError
        case .networkError:
            return L10n.LinkDevice.networkError
        case .defaultError:
            return L10n.LinkDevice.defaultError
        }
    }
}

enum GeneratingPinState {

    case initial
    case generatingPin
    case success(pin: String)
    case error(error: PinError)

    var rawValue: String {
        switch self {
        case .initial:
            return "INITIAL"
        case .generatingPin:
            return "GENERATING_PIN"
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

    private let generatingState = Variable(GeneratingPinState.initial)
    lazy var observableState: Observable <GeneratingPinState> = {
        return self.generatingState.asObservable()
    }()

    lazy var hasPassord: Bool = {
        guard let currentAccount = self.accountService.currentAccount else { return true }
        return AccountModelHelper(withAccount: currentAccount).hasPassword
    }()

    let accountService: AccountsService

    let disposeBag = DisposeBag()

    // MARK: L10n
    let linkDeviceTitleTitle = L10n.LinkDevice.title
    let explanationMessage = L10n.LinkDevice.explanationMessage

    required init(with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService

    }

    func linkDevice(with password: String?) {
        self.generatingState.value = GeneratingPinState.generatingPin
        guard let password = password else {
            self.generatingState.value = GeneratingPinState.error(error: PinError.passwordError)
            return
        }
        self.accountService.exportOnRing(withPassword: password)
            .subscribe(onCompleted: {
                if let account = self.accountService.currentAccount {
                    self.accountService.sharedResponseStream
                        .filter({ exportComplitedEvent in
                            return exportComplitedEvent.eventType == ServiceEventType.exportOnRingEnded
                                && exportComplitedEvent.getEventInput(.id) == account.id
                        })
                        .subscribe(onNext: { [unowned self] exportComplitedEvent in
                            if let state: Int = exportComplitedEvent.getEventInput(.state) {
                                switch state {
                                case ExportAccountResponse.success.rawValue:
                                    if let pin: String = exportComplitedEvent.getEventInput(.pin) {
                                        self.generatingState.value = GeneratingPinState.success(pin: pin)
                                    } else {
                                        self.generatingState.value = GeneratingPinState.error(error: PinError.defaultError)
                                    }
                                case ExportAccountResponse.wrongPassword.rawValue:
                                    self.generatingState.value = GeneratingPinState.error(error: PinError.passwordError)
                                case ExportAccountResponse.networkProblem.rawValue:
                                    self.generatingState.value = GeneratingPinState.error(error: PinError.networkError)
                                default:
                                    self.generatingState.value = GeneratingPinState.error(error: PinError.defaultError)
                                }
                            }
                        })
                        .disposed(by: self.disposeBag)
                } else {
                    self.generatingState.value = GeneratingPinState.error(error: PinError.defaultError)
                }
            }, onError: { error in
                self.generatingState.value = GeneratingPinState.error(error: PinError.passwordError)
            })
            .disposed(by: self.disposeBag)
    }

    func refresh() {
        self.generatingState.value = GeneratingPinState.initial
    }
}
