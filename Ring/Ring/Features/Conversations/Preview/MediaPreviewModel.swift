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
    private let photoSaver: PhotoLibrarySaving

    var injectionBag: InjectionBag?
    var forwardCallback: (([String]) -> Void)?

    @Published var activeSheet: MediaPreviewSheet?
    @Published var saveError: String?
    @Published var saveSuccess: Bool = false
    @Published var needsPhotoPermission: Bool = false

    var isImagePreview: Bool {
        if case .image = content { return true }
        return false
    }

    init(content: MediaPreviewContent, delegate: MediaPreviewActionsDelegate, fileURL: URL? = nil, canDelete: Bool = false, photoSaver: PhotoLibrarySaving = SystemPhotoLibrarySaver()) {
        self.content = content
        self.delegate = delegate
        self.fileURL = fileURL
        self.canDelete = canDelete
        self.photoSaver = photoSaver
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
            photoSaver.saveImageWithAuthCheck(
                url: url,
                onSuccess: { [weak self] in
                    DispatchQueue.main.async {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        self?.saveSuccess = true
                    }
                },
                onError: { [weak self] message in
                    DispatchQueue.main.async {
                        self?.saveError = message
                    }
                },
                onAccessDenied: { [weak self] in
                    DispatchQueue.main.async {
                        self?.needsPhotoPermission = true
                    }
                }
            )
        }
    }

    func delete() { delegate?.deleteMessage() }
}
