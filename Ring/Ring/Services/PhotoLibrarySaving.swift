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

import Photos

enum PhotoSaveResult {
    case success
    case denied
    case error(String)
}

protocol PhotoLibrarySaving {
    func authorizationStatus() -> PHAuthorizationStatus
    func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void)
    func performSave(url: URL, completion: @escaping (PhotoSaveResult) -> Void)
}

extension PhotoLibrarySaving {
    /// Checks authorization before saving. Callbacks may arrive on background threads;
    /// callers are responsible for dispatching to main.
    func saveImageWithAuthCheck(url: URL,
                                onSuccess: @escaping () -> Void,
                                onError: @escaping (String) -> Void,
                                onAccessDenied: (() -> Void)? = nil) {
        let handleResult = makeResultHandler(onSuccess: onSuccess, onError: onError)
        let status = authorizationStatus()
        switch status {
        case .authorized, .limited:
            performSave(url: url, completion: handleResult)
        case .notDetermined:
            requestAuthorizationAndSave(url: url, handleResult: handleResult, onError: onError)
        default:
            (onAccessDenied ?? { onError(L10n.Conversation.errorSavingImage) })()
        }
    }

    private func makeResultHandler(onSuccess: @escaping () -> Void,
                                   onError: @escaping (String) -> Void) -> (PhotoSaveResult) -> Void {
        return { result in
            switch result {
            case .success:
                onSuccess()
            case .denied:
                onError(L10n.Conversation.errorSavingImage)
            case .error(let message):
                onError(message)
            }
        }
    }

    private func requestAuthorizationAndSave(url: URL,
                                             handleResult: @escaping (PhotoSaveResult) -> Void,
                                             onError: @escaping (String) -> Void) {
        requestAuthorization { [self] newStatus in
            guard newStatus == .authorized || newStatus == .limited else {
                onError(L10n.Conversation.errorSavingImage)
                return
            }
            self.performSave(url: url, completion: handleResult)
        }
    }
}

class SystemPhotoLibrarySaver: PhotoLibrarySaving {
    func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }

    func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: completion)
    }

    func performSave(url: URL, completion: @escaping (PhotoSaveResult) -> Void) {
        // iOS 18+ sandbox change: the Photos service process can no longer read
        // files from the app's sandbox via fileURL. Load data in-process first.
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            completion(.error(error.localizedDescription))
            return
        }
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }, completionHandler: { success, error in
            if let error = error {
                completion(.error(error.localizedDescription))
            } else if success {
                completion(.success)
            } else {
                completion(.denied)
            }
        })
    }
}
