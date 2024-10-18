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

class ConnectSipVM: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var server: String = ""
    @Published var isTextFieldFocused: Bool = true

    var connectAction: ((_ username: String, _ password: String, _ server: String) -> Void)

    required init(with injectionBag: InjectionBag, connectAction: @escaping ((_ username: String, _ password: String, _ server: String) -> Void)) {
        self.connectAction = connectAction
    }

    func connect() {
        connectAction(username, password, server)
    }
}
