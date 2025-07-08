/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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
import UIKit

class ScreenDimensionsManager: ObservableObject {
    static let shared = ScreenDimensionsManager()

    @Published private(set) var adaptiveWidth: CGFloat = 0
    @Published private(set) var adaptiveHeight: CGFloat = 0
    @Published private(set) var avatarOffset: CGFloat = 0
    @Published private(set) var isLandscape: Bool = false

    private init() {
        updateDimensions()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updated),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updated),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }

    @objc
    private func updated() {
        DispatchQueue.main.async { [weak self] in
            self?.updateDimensions()
        }
    }

    private func updateDimensions() {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ??
                UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else {
            adaptiveWidth = UIScreen.main.bounds.width
            adaptiveHeight = UIScreen.main.bounds.height
            isLandscape = UIDevice.current.orientation.isLandscape
            updateAvatarOffset()
            return
        }

        isLandscape = windowScene.interfaceOrientation.isLandscape

        if let window = windowScene.windows.first {
            let bounds = window.bounds
            adaptiveWidth = bounds.width
            adaptiveHeight = bounds.height
        } else {
            let bounds = UIScreen.main.bounds
            adaptiveWidth = bounds.width
            adaptiveHeight = bounds.height
        }
        updateAvatarOffset()
    }

    private func updateAvatarOffset() {
        let avatarSize: CGFloat = 160

        if UIDevice.current.userInterfaceIdiom == .pad {
            avatarOffset = isLandscape
                ? -(adaptiveHeight / 3) + avatarSize
                : -(adaptiveHeight / 2.5) + avatarSize
        } else {
            avatarOffset = isLandscape
                ? 0
                : -(adaptiveHeight / 3) + avatarSize
        }
    }
}
