/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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
import SwiftUI
import RxRelay
import RxSwift

class LogUIViewModel: ObservableObject {

    @Published var showPicker = false
    @Published var showShare = false
    @Published var showErrorAlert = false

    var errorText = "Failed to save file"

    let systemService: SystemService
    let log = "test"
    let openDocumentBrowser = BehaviorRelay(value: false)
    let openShareMenu = BehaviorRelay(value: false)
    let disposeBag = DisposeBag()

    var shareFileURL: URL?

    init(injectionBag: InjectionBag) {
        self.systemService = injectionBag.systemService
        openDocumentBrowser
            .asObservable()
            .subscribe(onNext: { [weak self] openBrowser in
                guard let self = self else { return }
                self.showPicker = openBrowser && !self.log.isEmpty
            })
            .disposed(by: self.disposeBag)

        openShareMenu
            .asObservable()
            .subscribe(onNext: { [weak self] openShare in
                guard let self = self else { return }
                guard openShare && !self.log.isEmpty else { return }
                if self.prepareFileToShare() {
                    self.showShare = true
                } else {
                    self.showShareError()
                }
            })
            .disposed(by: self.disposeBag)
    }

    func triggerLog() {
        systemService.triggerLog()
    }

    func prepareFileToShare() -> Bool {
        guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        let filename = getFileName()
        let finalURL = doc.appendingPathComponent(filename)
        do {
            try log.write(to: finalURL, atomically: true, encoding: String.Encoding.utf8)
            shareFileURL = finalURL
        } catch {
            return false
        }
        return true
    }

    private func getFileName() -> String {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let date = Date()
        let dateString = dateFormatter.string(from: date)
        return "log_" + dateString + ".log"
    }

    private func showSaveError() {
        errorText = "Failed to save file"
        showErrorAlert = true
    }

    private func showShareError() {
        errorText = "Failed to share file"
        showErrorAlert = true
    }

    func saveLogTo(path: URL) {
        let filename = getFileName()
        guard path.startAccessingSecurityScopedResource() else {
            showSaveError()
            return
        }
        let finalUrl = path.appendingPathComponent(filename)
        do {
            try log.write(to: finalUrl, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            path.stopAccessingSecurityScopedResource()
            showSaveError()
            return
        }
        path.stopAccessingSecurityScopedResource()
    }
}
