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

import Foundation
import UIKit
import RxSwift

final class ShareCoordinator {
    // MARK: - Singleton
    static var shared: ShareCoordinator {
        return _shared
    }

    private static let _shared = ShareCoordinator()

    // singleton components
    private var adapter: Adapter?
    private var adapterService: AdapterService?
    private var shareViewModel: ShareViewModel?

    private var currentController: ShareViewController?

    // State tracking
    private var isInitialized = false

    func registerController(_ viewController: ShareViewController) {

        NSLog("ShareCoordinator registerController")

        if let currentController = currentController {
            currentController.newControllerCreated()
        }

        currentController = viewController
        ensureComponentsInitialized()

        guard let shareViewModel = shareViewModel else { return }
        currentController?.setView(for: shareViewModel)
    }

    private func ensureComponentsInitialized() {
        guard !isInitialized else { return }

        adapter = Adapter()
        adapterService = AdapterService(withAdapter: adapter!)
        shareViewModel = ShareViewModel(
            adapter: adapter!,
            adapterService: adapterService!
        )

        isInitialized = true
    }

    func performCleanup() {
        NSLog("ShareCoordinator performCleanup called")

        shareViewModel?.cleanup()
        shareViewModel = nil

        if let adapterService = adapterService {
            adapterService.setAllAccountsInactive()
            adapterService.removeDelegate()
        }

        adapter = nil
        adapterService = nil
        currentController = nil
        isInitialized = false
    }
}
