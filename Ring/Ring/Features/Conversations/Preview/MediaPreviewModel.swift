/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import SwiftUI
import Photos

protocol MediaPreviewActionsDelegate: AnyObject {
    func deleteMessage()
}

/// Identifies which sheet to present from MediaPreviewView.
enum MediaPreviewSheet: Identifiable {
    case share(url: URL)
    case forward(injectionBag: InjectionBag, callback: ([String]) -> Void)

    var id: String {
        switch self {
        case .share: return "share"
        case .forward: return "forward"
        }
    }
}

// MARK: - Content

enum MediaPreviewContent {
    case player(PlayerViewModel)
    case image(UIImage)
}

// MARK: - Model

class MediaPreviewModel: ObservableObject {
    let content: MediaPreviewContent
    let canDelete: Bool
    let fileURL: URL?
    private weak var delegate: MediaPreviewActionsDelegate?

    var injectionBag: InjectionBag?
    var forwardCallback: (([String]) -> Void)?

    @Published var activeSheet: MediaPreviewSheet?
    @Published var saveError: String?

    var isImagePreview: Bool {
        if case .image = content { return true }
        return false
    }

    init(content: MediaPreviewContent, delegate: MediaPreviewActionsDelegate, fileURL: URL? = nil, canDelete: Bool = false) {
        self.content = content
        self.delegate = delegate
        self.fileURL = fileURL
        self.canDelete = canDelete
    }

    func share() {
        guard let url = fileURL else { return }
        activeSheet = .share(url: url)
    }

    func forward() {
        guard let bag = injectionBag, let callback = forwardCallback else { return }
        activeSheet = .forward(injectionBag: bag, callback: callback)
    }

    func save() {
        guard let url = fileURL else { return }
        if url.pathExtension.isImageExtension() {
            saveImageToPhotos(url: url)
        }
    }

    func delete() { delegate?.deleteMessage() }

    private func saveImageToPhotos(url: URL) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            performPhotoSave(url: url)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] newStatus in
                guard newStatus == .authorized || newStatus == .limited else {
                    DispatchQueue.main.async {
                        self?.saveError = L10n.Conversation.errorSavingImage
                    }
                    return
                }
                DispatchQueue.main.async {
                    self?.performPhotoSave(url: url)
                }
            }
        default:
            saveError = L10n.Conversation.errorSavingImage
        }
    }

    private func performPhotoSave(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: nil)
        }, completionHandler: { [weak self] _, error in
            guard let error = error else { return }
            DispatchQueue.main.async {
                self?.saveError = error.localizedDescription
            }
        })
    }
}
