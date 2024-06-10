/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
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
import RxSwift
import RxCocoa
import SwiftyBeaver
import Reusable
import SwiftUI

class LogViewController: UIViewController, ViewModelBased, StoryboardBased {
    var viewModel: LogViewModel!
    var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
//        self.configureNavigationBar()
//        self.navigationItem.title = L10n.LogView.title
//        self.navigationController?.navigationBar
//            .titleTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium),
//                                    NSAttributedString.Key.foregroundColor: UIColor.jamiLabelColor]
//        let logUIViewModel = LogUIViewModel(injectionBag: self.viewModel.injectionBag)
//
//        // configure navigation buttons
//        let shareItem = UIBarButtonItem()
//        shareItem.image = UIImage(systemName: "square.and.arrow.up")
//        shareItem.rx.tap.throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
//            .subscribe(onNext: { [weak logUIViewModel] in
//                logUIViewModel?.openShareMenu.accept(true)
//            })
//            .disposed(by: self.disposeBag)
//
//        let saveItem = UIBarButtonItem()
//        saveItem.image = UIImage(systemName: "arrow.down.circle")
//        saveItem.rx.tap.throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
//            .subscribe(onNext: { [weak logUIViewModel] in
//                logUIViewModel?.openDocumentBrowser.accept(true)
//            })
//            .disposed(by: self.disposeBag)
//
//        self.navigationItem.rightBarButtonItems = [shareItem, saveItem]
//
//        let logUI = LogUI(model: logUIViewModel)
//        let swiftUIView = UIHostingController(rootView: logUI)
//        addChild(swiftUIView)
//        swiftUIView.view.frame = self.view.frame
//        self.view.addSubview(swiftUIView.view)
//        swiftUIView.view.translatesAutoresizingMaskIntoConstraints = false
//        swiftUIView.view.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
//        swiftUIView.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
//        swiftUIView.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 0).isActive = true
//        swiftUIView.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: 0).isActive = true
//        swiftUIView.didMove(toParent: self)
    }
}
