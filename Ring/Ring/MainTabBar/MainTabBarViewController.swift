/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import RxSwift

class MainTabBarViewController: UITabBarController {

    fileprivate let viewModel = MainTabBarViewModel(withCallsService: AppDelegate.callsService)
    fileprivate let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupBindings()
    }

    func setupBindings() {

        self.viewModel.showCallScene.subscribe(onNext: { call in
            //Instanciate Call view controller
            let callViewController = StoryboardScene.CallScene.initialViewController()
            callViewController.viewModel = CallViewModel(withCallsService: AppDelegate.callsService,
                                                         contactsService: AppDelegate.contactsService,
                                                         call: call)
            //Show call scene
            self.present(callViewController, animated: false, completion: nil)
        }).disposed(by: self.disposeBag)

        self.viewModel.hideCallScene.subscribe(onNext: { _ in
            //Hide call scene after delay in seconds
            self.hideCallScene(afterDelay: 2.0)
        }).disposed(by: self.disposeBag)
    }

    func hideCallScene(afterDelay delay: Float) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
            self.presentedViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
