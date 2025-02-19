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

class ImportFromArchiveVM: ObservableObject {
    @Published var password: String = ""
    @Published var selectedFileURL: URL?
    @Published var pickerPresented: Bool = false

    var importAction: ((_ url: URL, _ password: String) -> Void)

    var isImportButtonDisabled: Bool {
        return selectedFileURL == nil
    }

    var importButtonColor: Color {
        return isImportButtonDisabled ? Color(UIColor.secondaryLabel) : .jamiColor
    }

    var selectedFileText: String {
        return selectedFileURL?.lastPathComponent ?? L10n.ImportFromArchive.selectArchiveButton
    }

    init(with injectionBag: InjectionBag, importAction: @escaping ((_ url: URL, _ password: String) -> Void)) {
        self.importAction = importAction
    }

    func importAccount() {
        if let selectedFileURL = selectedFileURL {
            importAction(selectedFileURL, password)
        }
    }

    func selectFile() {
        withAnimation {
            pickerPresented = true
        }
    }
}
