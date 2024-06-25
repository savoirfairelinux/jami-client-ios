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
import RxRelay
import RxSwift
import SwiftUI

struct LogEntry: Identifiable {
    var id: String
    var content: String
}

class LogUIViewModel: ObservableObject {
    @Published var showPicker = false
    @Published var showShare = false
    @Published var showErrorAlert = false
    @Published var buttonTitle = L10n.LogView.startLogging
    @Published var font: Font = .footnote
    @Published var editButtonsVisible = false
    var logEntries = [LogEntry]()
    var isViewDisplayed = false {
        didSet {
            triggerUIUpdater()
        }
    }

    var timer: Timer?

    var errorText = ""

    let systemService: SystemService
    let openDocumentBrowser = BehaviorRelay(value: false)
    let openShareMenu = BehaviorRelay(value: false)
    let disposeBag = DisposeBag()
    let queue = DispatchQueue(label: "UpdateSystemLog", qos: .background, attributes: .concurrent)

    var shareFileURL: URL?

    init(injectionBag: InjectionBag) {
        systemService = injectionBag.systemService
        systemService.clearLog()
        parceCurrentLog()
        openDocumentBrowser
            .asObservable()
            .subscribe(onNext: { [weak self] openBrowser in
                guard let self = self else { return }
                self.showPicker = openBrowser && !self.systemService.currentLog.isEmpty
            })
            .disposed(by: disposeBag)

        openShareMenu
            .asObservable()
            .subscribe(onNext: { [weak self] openShare in
                guard let self = self else { return }
                guard openShare, !self.systemService.currentLog.isEmpty else { return }
                if self.prepareFileToShare() {
                    self.showShare = true
                } else {
                    self.showShareError()
                }
            })
            .disposed(by: disposeBag)
        systemService.isMonitoring
            .asObservable()
            .observe(on: MainScheduler.instance)
            .startWith(systemService.isMonitoring.value)
            .subscribe(onNext: { [weak self] monitoring in
                guard let self = self else { return }
                self.buttonTitle = monitoring ? L10n.LogView.stopLogging : L10n.LogView.startLogging
            })
            .disposed(by: disposeBag)

        systemService.newMessage
            .asObservable()
            .subscribe(onNext: { [weak self] newMessage in
                guard let self = self else { return }
                self.insertNewLog(log: newMessage)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.editButtonsVisible = !self.systemService.currentLog.isEmpty
                }
            })
            .disposed(by: disposeBag)
    }

    private func insertNewLog(log: String) {
        if log.isEmpty { return }
        queue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let id = "\(Int.random(in: 1 ..< 10000))_" + log
            let newLog = LogEntry(id: id, content: String(log))
            self.logEntries.insert(newLog, at: 0)
        }
    }

    private func triggerUIUpdater() {
        if systemService.isMonitoring.value && isViewDisplayed {
            startTimer()
        } else {
            stopTimer()
        }
    }

    deinit {
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.objectWillChange.send()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func prepareFileToShare() -> Bool {
        guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first
        else {
            return false
        }
        let filename = getFileName()
        let finalURL = doc.appendingPathComponent(filename)
        do {
            try systemService.currentLog.write(
                to: finalURL,
                atomically: true,
                encoding: String.Encoding.utf8
            )
            shareFileURL = finalURL
        } catch {
            return false
        }
        return true
    }

    private func getFileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let date = Date()
        let dateString = dateFormatter.string(from: date)
        return "log_" + dateString + ".log"
    }

    private func showSaveError() {
        errorText = L10n.LogView.saveError
        showErrorAlert = true
    }

    private func showShareError() {
        errorText = L10n.LogView.shareError
        showErrorAlert = true
    }

    private func parceCurrentLog() {
        let entries = systemService.currentLog.split(whereSeparator: \.isNewline)
        logEntries = entries.reversed()
            .filter { entry in
                !entry.isEmpty
            }
            .map { entry in
                let id = "\(Int.random(in: 1 ..< 10000))_" + entry
                return LogEntry(id: id, content: String(entry))
            }
        editButtonsVisible = !systemService.currentLog.isEmpty
    }

    func zoomIn() {
        switch font {
        case .callout:
            font = .body
        case .footnote:
            font = .callout
        case .caption:
            font = .footnote
        default:
            break
        }
    }

    func zoomOut() {
        switch font {
        case .body:
            font = .callout
        case .callout:
            font = .footnote
        case .footnote:
            font = .caption
        default:
            break
        }
    }

    func saveLogTo(path: URL) {
        let filename = getFileName()
        guard path.startAccessingSecurityScopedResource() else {
            showSaveError()
            return
        }
        let finalUrl = path.appendingPathComponent(filename)
        do {
            try systemService.currentLog.write(
                to: finalUrl,
                atomically: true,
                encoding: String.Encoding.utf8
            )
        } catch {
            path.stopAccessingSecurityScopedResource()
            showSaveError()
            return
        }
        path.stopAccessingSecurityScopedResource()
    }

    func triggerLog() {
        systemService.triggerLog()
        triggerUIUpdater()
    }

    func clearLog() {
        systemService.clearLog(force: true)
        parceCurrentLog()
    }

    func copy() {
        UIPasteboard.general.string = systemService.currentLog
    }
}
