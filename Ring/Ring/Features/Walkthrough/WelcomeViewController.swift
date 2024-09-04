/*
 *  Copyright (C) 2017-2023 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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
import Reusable
import SwiftUI

class WelcomeViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: WelcomeVM!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        addSwiftUI()
    }

    func addSwiftUI() {
//        let welcomeView = WelcomeView(injectionBag: self.injectionBag)
//        let contentView = UIHostingController(rootView: welcomeView)
//        addChild(contentView)
//        view.addSubview(contentView.view)
//        contentView.view.frame = self.view.bounds
//        contentView.view.translatesAutoresizingMaskIntoConstraints = false
//        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
//        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
//        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
//        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
//        contentView.didMove(toParent: self)
    }
}
