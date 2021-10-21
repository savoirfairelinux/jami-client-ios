/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
 *
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
class TroubleshootViewModel: ViewModel {

    let accountService: AccountsService
    let debugMessageReceived = PublishSubject<String>()
    var disposeBag = DisposeBag()

    required init(with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
    }

    func triggerLogging(enable: Bool) {
        if enable {
            self.accountService.debugMessageReceived
                .asObservable()
                .subscribe { [weak self] message in
                    guard let self = self else { return }
                    self.debugMessageReceived.onNext(message)
                } onError: { _ in
                }
                .disposed(by: disposeBag)
            self.accountService.monitor(enable: true)
        } else {
            disposeBag = DisposeBag()
            self.accountService.monitor(enable: false)
        }
    }

}
