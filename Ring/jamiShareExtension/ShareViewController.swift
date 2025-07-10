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

import UIKit
import SwiftUI
import Social
import RxSwift

@objc
class ShareViewController: UIViewController {
    private var hostingController: UIHostingController<ShareView>?
    private var requestCompleted: Bool = false

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        NSLog("ShareViewController init")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NSLog("ShareViewController init(coder:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("ShareViewController viewDidLoad")
        ShareCoordinator.shared.registerController(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NSLog("ShareViewController viewWillDisappear called")
        closeShareExtension()
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        NSLog("ShareViewController didReceiveMemoryWarning")
    }

    func setView(for viewModel: ShareViewModel?) {
        NSLog("ShareViewController setView called")
        guard let viewModel = viewModel else {
            return
        }
        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        self.hostingController = UIHostingController(
            rootView: ShareView(
                items: sharedItems,
                viewModel: viewModel,
                closeAction: { [weak self] in
                    self?.closeShareExtension()
                }
            )
        )

        guard let hostingController = hostingController else {
            return
        }

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)

        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let size = hostingController.view.systemLayoutSizeFitting(targetSize)
        hostingController.preferredContentSize = size
    }

    func closeShareExtension() {
        NSLog("ShareViewController closeShareExtension called")
        cleanupUI()
        ShareCoordinator.shared.performCleanup()
        completeRequest()
    }

    func cleanupUI() {
        NSLog("ShareViewController cleanupUI called")
        guard let hostingController = hostingController else {
            return
        }
        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        self.hostingController = nil
    }

    func newControllerCreated() {
        NSLog("ShareViewController newControllerCreated called")
        self.cleanupUI()
    }

    func completeRequest(withError: Bool = false) {
        NSLog("ShareViewController completeRequest, withError: %@", withError ? "true" : "false")
        if requestCompleted {
            return
        }
        requestCompleted = true
        if withError {
            let error = NSError(domain: "ShareExtensionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Share extension cancelled"])
            extensionContext?.cancelRequest(withError: error)
        } else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    deinit {
        NSLog("ShareViewController deinit")
        cleanupUI()
        completeRequest()
    }
}
