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

import Foundation

class LoadingViewPresenter {

    private weak var timer: Timer?
    private let timeout = 2.0

    var loadingView: LoadingView! = {
        let loadingView = LoadingView()
        loadingView.modalPresentationStyle = .overCurrentContext
        loadingView.modalTransitionStyle = .crossDissolve
        return loadingView
    }()

    func presentWithMessage(message: String, presentingVC: UIViewController, animated flag: Bool) {
        loadingView.message = message
        loadingView.showLoadingView()
        presentingVC.present(loadingView, animated: flag)
    }

    func showSuccessAllert(message: String, presentingVC: UIViewController, animated flag: Bool) {
        loadingView.message = message
        loadingView.showSuccessView()
        presentingVC.present(loadingView, animated: flag)
        startTimer()
    }

    func hide(animated flag: Bool, completion: (() -> Void)? = nil) {
        loadingView.dismiss(animated: flag, completion: completion)
    }

    // MARK: - Timer
    @objc
    func timerHandler(_ timer: Timer) {
        defer {
            stopTimer()
        }
        loadingView.dismiss(animated: true)
    }

    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(timerHandler(_:)), userInfo: nil, repeats: false)
    }

    func stopTimer() {
        timer?.invalidate()
    }
}

class LoadingView: UIViewController {
    let margin: CGFloat = 30
    let defaultSize: CGFloat = 156
    let defaultSizeWithoutText: CGFloat = 100
    var message: String = ""

    var containerView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemChromeMaterialLight)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.layer.cornerRadius = 9.0
        blurEffectView.layer.masksToBounds = true
        blurEffectView.autoresizingMask = [
            .flexibleWidth, .flexibleHeight
        ]
        return blurEffectView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        containerView.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: defaultSize, height: defaultSize))
        containerView.center = view.center
        view.addSubview(containerView)
    }

    func showLoadingView() {
        self.containerView.contentView.removeSubviews(recursive: true)
        let indicator = UIActivityIndicatorView()
        indicator.style = .large
        indicator.color = .black
        indicator.startAnimating()
        indicator.autoresizingMask = [
            .flexibleLeftMargin, .flexibleRightMargin,
            .flexibleTopMargin, .flexibleBottomMargin
        ]
        self.addToContainerMessageAndView(viewToAdd: indicator)
    }

    func showSuccessView() {
        self.containerView.contentView.removeSubviews(recursive: true)
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .jamiSuccess
        imageView.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 60, height: 60))
        self.addToContainerMessageAndView(viewToAdd: imageView)
    }

    func addToContainerMessageAndView(viewToAdd: UIView) {
        if message.isEmpty {
            containerView.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: defaultSize, height: defaultSize))
            containerView.center = view.center
            containerView.contentView.addSubview(viewToAdd)
            viewToAdd.center = containerView.contentView.center
            return
        }
        let messageLabel = UILabel()
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(legibilityWeight: .bold))
        messageLabel.text = message
        messageLabel.frame.size.width = defaultSize
        messageLabel.sizeToFit()
        containerView.contentView.addSubview(messageLabel)
        let viewHeight = viewToAdd.frame.height
        let textHeight = messageLabel.frame.height
        let width = margin * 2 + defaultSize
        let conteinerHeight = viewHeight + textHeight + margin * 3
        let height = max(defaultSize, conteinerHeight)
        let bottomMargin = (height - textHeight - viewHeight - margin) * 0.5
        containerView.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: width, height: height))
        containerView.center = view.center
        let centerX = containerView.contentView.center.x
        let centerAIY = containerView.contentView.frame.height - (viewHeight * 0.5) - bottomMargin

        let centerY = containerView.contentView.bounds.midY - (viewHeight * 0.5) - bottomMargin
        messageLabel.center = CGPoint(
            x: centerX,
            y: centerY
        )
        containerView.contentView.addSubview(viewToAdd)
        viewToAdd.center = CGPoint(
            x: centerX,
            y: centerAIY
        )
    }
}
