/*
 *  Copyright (C) 2020 Savoir-faire Linux Inc.
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

import Reusable
import RxSwift
import UIKit

enum PrevewType {
    case player
    case image
}

protocol PreviewViewControllerDelegate: AnyObject {
    func deleteFile()
    func shareFile()
    func forwardFile()
    func saveFile()
}

class PreviewViewController: UIViewController, StoryboardBased, ViewModelBased {
    // MARK: - outlets

    @IBOutlet var playerView: PlayerView!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet private var hideButton: UIButton!
    @IBOutlet var imageLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var imageTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var imageTopConstraint: NSLayoutConstraint!
    @IBOutlet var imageBottomConstraint: NSLayoutConstraint!
    @IBOutlet var backgroundView: UIView!
    @IBOutlet var gradientView: UIView!
    @IBOutlet var shareButton: UIButton!
    @IBOutlet var deleteButton: UIButton!
    @IBOutlet var forwardButton: UIButton!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet var buttonsContainer: UIStackView!

    // MARK: - members

    let disposeBag = DisposeBag()
    var viewModel: PreviewControllerModel!
    var tapGestureRecognizer: UITapGestureRecognizer!
    var type: PrevewType = .player
    weak var delegate: PreviewViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.playerView.isHidden = type == .image
        gradientView.layoutIfNeeded()
        gradientView.applyGradient(
            with: [UIColor(red: 0, green: 0, blue: 0, alpha: 1), UIColor(
                red: 0,
                green: 0,
                blue: 0,
                alpha: 0
            )],
            gradient: .vertical
        )
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard UIDevice.current.portraitOrLandscape else { return }
                self?.gradientView.layoutIfNeeded()
                self?.gradientView.updateGradientFrame()
            })
            .disposed(by: disposeBag)
        hideButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.parent?.inputAccessoryView?.isHidden = false
                self?.removeChildController()
            })
            .disposed(by: disposeBag)
        hideButton.centerYAnchor.constraint(
            equalTo: self.playerView.muteAudio.centerYAnchor,
            constant: 0
        ).isActive = true
        hideButton.setTitle(L10n.Global.close, for: .normal)
        shareButton.isUserInteractionEnabled = type == .image
        deleteButton.isUserInteractionEnabled = type == .image
        forwardButton.isUserInteractionEnabled = type == .image
        buttonsContainer.isHidden = type != .image
        if type == .image, let image = viewModel.image {
            imageView.image = image
            let pinchGesture = UIPinchGestureRecognizer(
                target: self,
                action: #selector(startZooming(_:))
            )
            imageView.isUserInteractionEnabled = true
            imageView.addGestureRecognizer(pinchGesture)
            shareButton.rx.tap
                .subscribe(onNext: { [weak self] in
                    self?.share()
                })
                .disposed(by: disposeBag)
            deleteButton.rx.tap
                .subscribe(onNext: { [weak self] in
                    self?.parent?.inputAccessoryView?.isHidden = false
                    self?.removeChildController()
                    self?.delete()
                })
                .disposed(by: disposeBag)
            forwardButton.rx.tap
                .subscribe(onNext: { [weak self] in
                    self?.forward()
                    self?.parent?.inputAccessoryView?.isHidden = false
                    self?.removeChildController()
                })
                .disposed(by: disposeBag)
            saveButton.rx.tap
                .subscribe(onNext: { [weak self] in
                    self?.parent?.inputAccessoryView?.isHidden = false
                    self?.removeChildController()
                    self?.save()
                })
                .disposed(by: disposeBag)
            return
        }
        guard let model = viewModel.playerViewModel, let playerView = playerView else { return }
        playerView.viewModel = model
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        view.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc
    private func startZooming(_ sender: UIPinchGestureRecognizer) {
        let scaleResult = sender.view?.transform.scaledBy(x: sender.scale, y: sender.scale)
        guard let scale = scaleResult, scale.a > 1, scale.d > 1 else { return }
        sender.view?.transform = scale
        sender.scale = 1
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @objc
    func screenTapped() {
        playerView.changeControlsVisibility()
    }

    override func resizeFrom(initialFrame: CGRect) {
        if type == .player {
            playerView.resizeFrom(frame: initialFrame)
            return
        }
        let leftConstraint: CGFloat = initialFrame.origin.x
        let topConstraint: CGFloat = initialFrame.origin.y
        let rightConstraint: CGFloat = view.frame.width - initialFrame.origin.x - initialFrame.size
            .width
        let bottomConstraint: CGFloat = view.frame.height - initialFrame.origin.y - initialFrame
            .size.height
        imageLeadingConstraint.constant = leftConstraint
        imageTrailingConstraint.constant = -rightConstraint
        imageTopConstraint.constant = topConstraint
        imageBottomConstraint.constant = bottomConstraint
        view.layoutIfNeeded()
        backgroundView.alpha = 0
        UIView.animate(withDuration: 0.2,
                       delay: 0.0,
                       options: [.curveEaseInOut],
                       animations: { [weak self] in
                        guard let self = self else { return }
                        self.imageLeadingConstraint.constant = 0
                        self.imageTrailingConstraint.constant = 0
                        self.imageTopConstraint.constant = 0
                        self.imageBottomConstraint.constant = 0
                        self.backgroundView.alpha = 1
                        self.view.layoutIfNeeded()
                       }, completion: nil)
    }

    func share() {
        if let delegate = delegate {
            delegate.shareFile()
        }
    }

    func delete() {
        if let delegate = delegate {
            delegate.deleteFile()
        }
    }

    func forward() {
        if let delegate = delegate {
            delegate.forwardFile()
        }
    }

    func save() {
        if let delegate = delegate {
            delegate.saveFile()
        }
    }
}
