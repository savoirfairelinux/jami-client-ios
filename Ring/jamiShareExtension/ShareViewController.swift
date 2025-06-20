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

@objc class ShareViewController: UIViewController {
    private var viewModel: ShareViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        let sharedItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        viewModel = ShareViewModel()

        let hostingController = UIHostingController(
            rootView: ShareView(
                items: sharedItems,
                viewModel: viewModel,
                closeAction: { [weak self] in
                    self?.viewModel.closeShareExtension()
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            )
        )

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.closeShareExtension()
    }
}
