/*
 *  Copyright (C) 2004-2026 Savoir-faire Linux Inc.
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
import WebKit
import RxSwift

/**
 Serves the editor, and the images of the document it is showing.

 Everything the page can ask for is answered here, and anything else is
 refused: a document is written by someone else, and a request coming out of
 one must not be able to reach the network or name a file of this application
 that the editor is not.
 */
class CollabSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "jami-collab"
    static let host = "editor"
    static let pageURL = URL(string: "\(scheme)://\(host)/editor.html")!

    private static let attachmentPath = "/attachment/"

    /// Named explicitly rather than opened by path.
    private static let editorFiles = [
        "/editor.html": "text/html",
        "/editor.js": "text/javascript",
        "/editor.css": "text/css"
    ]

    private weak var viewModel: CollabEditorViewModel?
    private let disposeBag = DisposeBag()

    init(viewModel: CollabEditorViewModel) {
        self.viewModel = viewModel
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.host == CollabSchemeHandler.host else {
            self.refuse(task)
            return
        }
        if let mimeType = CollabSchemeHandler.editorFiles[url.path] {
            self.serveAsset(named: url.lastPathComponent, mimeType: mimeType, to: task)
        } else if url.path.hasPrefix(CollabSchemeHandler.attachmentPath) {
            self.serveAttachment(url.lastPathComponent, to: task)
        } else {
            self.refuse(task)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func serveAsset(named name: String, mimeType: String, to task: WKURLSchemeTask) {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "collab"),
              let data = try? Data(contentsOf: url) else {
            self.refuse(task)
            return
        }
        self.answer(task, data: data, mimeType: mimeType)
    }

    private func serveAttachment(_ attachmentId: String, to task: WKURLSchemeTask) {
        guard !attachmentId.isEmpty, let viewModel = self.viewModel else {
            self.refuse(task)
            return
        }
        // The page is laying an image out and has nowhere to put an answer
        // that arrives later, but this is not the main thread, so it waits.
        viewModel.attachment(attachmentId)
            .subscribe(onSuccess: { [weak self] data in
                guard let self = self else { return }
                if data.isEmpty {
                    // Normal right after a peer referenced an image this
                    // replica does not hold yet, rather than an error.
                    self.refuse(task)
                } else {
                    self.answer(task, data: data, mimeType: CollabSchemeHandler.mimeType(of: data))
                }
            }, onFailure: { [weak self] _ in
                self?.refuse(task)
            })
            .disposed(by: self.disposeBag)
    }

    private func answer(_ task: WKURLSchemeTask, data: Data, mimeType: String) {
        guard let url = task.request.url else { return }
        let response = URLResponse(url: url,
                                   mimeType: mimeType,
                                   expectedContentLength: data.count,
                                   textEncodingName: nil)
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    /// Failing the request rather than letting the web view go and fetch it.
    private func refuse(_ task: WKURLSchemeTask) {
        task.didFailWithError(URLError(.resourceUnavailable))
    }

    /// What the bytes are, read from the first of them: an attachment is stored
    /// as it arrived, and nothing alongside it says what it is.
    static func mimeType(of data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        if bytes.count > 3, bytes[0] == 0xFF, bytes[1] == 0xD8 { return "image/jpeg" }
        if bytes.count > 8, bytes[0] == 0x89, bytes[1] == 0x50 { return "image/png" }
        // Only twelve bytes were taken, so asking for more than twelve never
        // matched: every WebP went out as bytes of no stated kind.
        if bytes.count >= 12, bytes[0] == 0x52, bytes[8] == 0x57 { return "image/webp" }
        if bytes.count > 6, bytes[0] == 0x47, bytes[1] == 0x49 { return "image/gif" }
        return "application/octet-stream"
    }
}
