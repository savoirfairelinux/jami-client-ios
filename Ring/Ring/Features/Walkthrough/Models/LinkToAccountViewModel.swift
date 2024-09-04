/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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
import SwiftUI

class LinkToAccountViewModel: Stateable, ObservableObject, ViewModel, Dismissable {
    @Published var pin: String = ""
    @Published var password: String = ""
    @Published var scannedCode: String?
    @Published var animatableScanSwitch: Bool = true
    @Published var notAnimatableScanSwitch: Bool = true

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    // MARK: - Rx Dismissable
    var dismiss = PublishSubject<Bool>()

    var linkAction: ((_ pin: String, _ password: String) -> Void)?

    var isLinkButtonEnabled: Bool {
        return !pin.isEmpty
    }

    // Computed property for the button's color
    var linkButtonColor: Color {
        return pin.isEmpty ? Color(UIColor.secondaryLabel) : .blue
    }

    required init(with injectionBag: InjectionBag) {
    }

    func link() {
        linkAction?(pin, password)
    }

    func switchToQRCode() {
        notAnimatableScanSwitch = true
        withAnimation {
            animatableScanSwitch = true
        }
    }

    func switchToManualEntry() {
        notAnimatableScanSwitch = false
        withAnimation {
            animatableScanSwitch = false
        }
    }

    func didScanQRCode(_ code: String) {
        self.pin = code
        self.scannedCode = code
    }
}
