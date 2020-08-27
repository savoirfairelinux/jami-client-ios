//
//  PlayerViewController.swift
//  Ring
//
//  Created by kateryna on 2020-08-27.
//  Copyright © 2020 Savoir-faire Linux. All rights reserved.
//

import UIKit
import Reusable
import RxSwift
import RxCocoa
import RxDataSources
import PKHUD

class PlayerViewController: UIViewController, StoryboardBased, ViewModelBased {
// MARK: - outlets
@IBOutlet weak var playerView: PlayerView!
@IBOutlet private weak var hideButton: UIButton!
let disposeBag = DisposeBag()

// MARK: - members
var viewModel: PlayerControllerModel!
var tapGestureRecognizer: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        self.view.addGestureRecognizer(tapGestureRecognizer)
        guard let model = self.viewModel.playerViewModel else { return }
        playerView.viewModel = model
        self.hideButton.rx.tap
        .subscribe(onNext: { [weak self] in
            self?.parent?.inputAccessoryView?.isHidden = false
            self?.removeChildController()
        })
        .disposed(by: self.disposeBag)
        hideButton.centerYAnchor.constraint(equalTo: self.playerView.muteAudio.centerYAnchor, constant: 0).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @objc
    func screenTapped() {
        self.playerView.changeControlsVisibility()
    }
}
