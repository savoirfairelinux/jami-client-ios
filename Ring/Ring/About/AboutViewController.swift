/*
 * Copyright (C) 2024 Savoir-faire Linux Inc. *
 *
 * Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import UIKit
import SwiftUI
import Reusable

class AboutViewController: UIViewController, ViewModelBased, StoryboardBased {

    var viewModel: AboutViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = L10n.Smartlist.aboutJami
        self.configureNavigationBar(isTransparent: true)
        let swiftUIView = AboutSwiftUIView()
        let contentView = UIHostingController(rootView: swiftUIView)
        addChild(contentView)
        contentView.view.frame = self.view.frame
        self.view.addSubview(contentView.view)
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
        contentView.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 0).isActive = true
        contentView.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: 0).isActive = true
        contentView.didMove(toParent: self)
    }
}
