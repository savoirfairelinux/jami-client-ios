/*
 *  Copyright (C) 2017-2024 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

// Constants
struct SmartlistConstants {
    static let smartlistRowHeight: CGFloat = 70.0
    static let tableHeaderViewHeight: CGFloat = 30.0
}

class SmartlistViewController: UIViewController, StoryboardBased, ViewModelBased {

    var viewModel: SmartlistViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addSwiftUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.viewModel.closeAllPlayers()
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func addSwiftUI() {
//        let contentView = UIHostingController(rootView: SmartListContainer(model: viewModel.conversationsModel))
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
