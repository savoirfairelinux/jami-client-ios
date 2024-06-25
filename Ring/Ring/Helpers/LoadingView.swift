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
        loadingView.modalPresentationStyle = .overFullScreen
        loadingView.modalTransitionStyle = .crossDissolve
        return loadingView
    }()

    func presentWithMessage(
        message: String,
        presentingVC: UIViewController,
        animated flag: Bool,
        modalPresentationStyle: UIModalPresentationStyle = .overCurrentContext
    ) {
        loadingView.message = message
        loadingView.modalPresentationStyle = modalPresentationStyle
        loadingView.showLoadingView()
        presentingVC.present(loadingView, animated: flag)
    }

    func showSuccessAllert(
        message: String,
        presentingVC: UIViewController,
        animated flag: Bool,
        modalPresentationStyle: UIModalPresentationStyle = .overCurrentContext
    ) {
        loadingView.message = message
        loadingView.modalPresentationStyle = modalPresentationStyle
        loadingView.showSuccessView()
        presentingVC.present(loadingView, animated: flag)
        startTimer()
    }

    func hide(animated flag: Bool, completion: (() -> Void)? = nil) {
        loadingView.dismiss(animated: flag, completion: completion)
    }

    // MARK: - Timer

    @objc
    func timerHandler(_: Timer) {
        defer {
            stopTimer()
        }
        loadingView.dismiss(animated: true)
    }

    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(
            timeInterval: timeout,
            target: self,
            selector: #selector(timerHandler(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    func stopTimer() {
        timer?.invalidate()
    }
}

class LoadingView: UIViewController {
    let horizontalMargin: CGFloat = 10
    let verticalMargin: CGFloat = 10
    let defaultSize: CGFloat = 156
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
        view.addSubview(containerView)
    }

    func showLoadingView() {
        containerView.contentView.removeSubviews(recursive: true)
        let indicator = UIActivityIndicatorView()
        indicator.style = .large
        indicator.color = .black
        indicator.startAnimating()
        indicator.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 60, height: 60))
        addToContainerMessageAndView(viewToAdd: indicator)
    }

    func showSuccessView() {
        containerView.contentView.removeSubviews(recursive: true)
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .jamiSuccess
        imageView.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 60, height: 60))
        addToContainerMessageAndView(viewToAdd: imageView)
    }

    func addVibrancy() {
        let blurEffect = UIBlurEffect(style: .systemChromeMaterialLight)
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        containerView.contentView.addSubview(vibrancyView)
        NSLayoutConstraint.activate([
            vibrancyView
                .heightAnchor
                .constraint(equalTo: containerView.contentView.heightAnchor),
            vibrancyView
                .widthAnchor
                .constraint(equalTo: containerView.contentView.widthAnchor),
            vibrancyView
                .centerXAnchor
                .constraint(equalTo: containerView.contentView.centerXAnchor),
            vibrancyView
                .centerYAnchor
                .constraint(equalTo: containerView.contentView.centerYAnchor)
        ])
    }

    func addView(viewToAdd: UIView) {
        containerView.frame = CGRect(
            origin: CGPoint.zero,
            size: CGSize(width: defaultSize, height: defaultSize)
        )
        containerView.center = view.center
        addVibrancy()
        containerView.contentView.addSubview(viewToAdd)
        viewToAdd.center = containerView.contentView.center
    }

    func createMessageView() -> UILabel {
        let messageLabel = UILabel()
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.boldSystemFont(ofSize: 18.0)
        messageLabel.textColor = UIColor.black.withAlphaComponent(0.85)
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.25
        messageLabel.text = message
        messageLabel.frame.size.width = defaultSize
        messageLabel.sizeToFit()
        return messageLabel
    }

    func addToContainerMessageAndView(viewToAdd: UIView) {
        if message.isEmpty {
            addView(viewToAdd: viewToAdd)
            return
        }
        let messageLabel = createMessageView()

        // sizes
        let viewHeight = viewToAdd.frame.height
        let textHeight = messageLabel.frame.height
        let width = horizontalMargin * 2 + defaultSize
        let conteinerHeight = viewHeight + textHeight + verticalMargin * 3
        let height = max(width, max(defaultSize, conteinerHeight))
        let updatedVerticalMargin = (height - textHeight - viewHeight) / 3

        containerView.frame = CGRect(
            origin: CGPoint.zero,
            size: CGSize(width: width, height: height)
        )

        containerView.center = view.center

        addVibrancy()
        containerView.contentView.addSubview(messageLabel)

        let centerX = containerView.contentView.center.x
        let indicatorCenterY = containerView.contentView.frame
            .height - (viewHeight * 0.5) - updatedVerticalMargin
        let textCenterY = (textHeight * 0.5) + updatedVerticalMargin

        messageLabel.center = CGPoint(
            x: centerX,
            y: textCenterY
        )
        containerView.contentView.addSubview(viewToAdd)
        viewToAdd.center = CGPoint(
            x: centerX,
            y: indicatorCenterY
        )
    }
}
