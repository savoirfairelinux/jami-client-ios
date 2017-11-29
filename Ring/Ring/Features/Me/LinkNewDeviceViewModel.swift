/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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
import RxDataSources

enum ExportAccountResponse: Int {
    case success = 0
    case wrongPassword = 1
    case networkProblem = 2
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

    lazy var isInitialState: Observable<Bool> = {
        return self.observableState.map { state in
            return !state.isStateOfType(type: "INITIAL")
        }
        }().share()

    lazy var isSuccessState: Observable<Bool> = {
        return self.observableState.map { state in
            return !state.isStateOfType(type: "SUCCESS")
        }
        }().share()

    lazy var isErrorState: Observable<Bool> = {
        return self.observableState.map { state in
            return !state.isStateOfType(type: "ERROR")
        }
        }().share()

    lazy var isGeneratedPinState: Observable<Bool> = {
        return self.observableState.map { state in
            return !state.isStateOfType(type: "GENERATING_PIN")
        }
        }().share()

    private let accountsService: NewAccountsService

    private let disposeBag = DisposeBag()

    // MARK: L10n
    let linkDeviceTitleTitle  = L10n.Linkdevice.title
    let explanationMessage = L10n.Linkdevice.explanationMessage

    required init(with injectionBag: InjectionBag) {
        self.accountsService = injectionBag.newAccountsService
    }

    func linkDevice(with password: String?) {
        self.generatingState.value = GeneratingPinState.generatingPin
        guard let password = password else {
            self.generatingState.value = GeneratingPinState.error(error: PinError.passwordError)
            return
        }

        self.accountsService.currentAccount().asObservable()
            .flatMap { [unowned self] (account) -> Observable<String> in
                return self.accountsService.exportAccountOnRing(account, withPassword: password)
            }
            .subscribe(onNext: { [weak self] pin in
                self?.generatingState.value = GeneratingPinState.success(pin: pin)
                }, onError: { [weak self] (error) in
                    if let pinError = error as? PinError {
                        self?.generatingState.value = GeneratingPinState.error(error: pinError)
                    } else {
                        self?.generatingState.value = GeneratingPinState.error(error: PinError.defaultError)
                    }
            })
            .disposed(by: self.disposeBag)
    }

    func refresh() {
        self.generatingState.value = GeneratingPinState.initial
    }
}
