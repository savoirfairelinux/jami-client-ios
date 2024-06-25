/*
 * Copyright (C) 2022 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
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

import Reusable
import RxCocoa
import RxSwift
import SwiftUI
import UIKit

class SwarmInfoViewController: UIViewController, ViewModelBased, StoryboardBased {
    var viewModel: SwarmInfoViewModel!
    let disposeBag = DisposeBag()
    var contentView: UIHostingController<SwarmInfoView>! = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar(isTransparent: true)
        guard let swarmInfo = viewModel.swarmInfo else { return }
        let swiftUIVM = SwarmInfoVM(with: viewModel.injectionBag, swarmInfo: swarmInfo)
        contentView = UIHostingController(rootView: SwarmInfoView(viewmodel: swiftUIVM))
        addChild(contentView)
        view.addSubview(contentView.view)
        setupConstraints()
        swiftUIVM.navBarColor
            .subscribe(onNext: { [weak self] newColorValue in
                guard let self = self, let color = UIColor(hexString: newColorValue) else { return }
                let isLight: Bool = color.isLight(threshold: 0.8) ?? true
                self.navigationController?.navigationBar.tintColor = isLight ? UIColor
                    .jamiMain : .white
            })
            .disposed(by: disposeBag)
        swiftUIVM.colorPickerStatus
            .subscribe(onNext: { [weak self] statusValue in
                guard let self = self else { return }
                self.navigationItem.setHidesBackButton(statusValue, animated: true)
            })
            .disposed(by: disposeBag)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor = UIColor.jamiMain
        configureNavigationBar()
    }

    func setupConstraints() {
        contentView.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentView.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
}
