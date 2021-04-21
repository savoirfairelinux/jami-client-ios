/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import RxRelay

protocol MessageAccessoryViewDelegate: class {
    func setIsComposing(isComposing: Bool)
}

class MessageAccessoryView: UIView, NibLoadable, GrowingTextViewDelegate {

    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var emojisButton: UIButton!
    @IBOutlet weak var messageTextView: GrowingTextView!
    @IBOutlet weak var emojisButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var sendButtonLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewHeightConstraints: NSLayoutConstraint!
    var messageTextViewHeight = BehaviorRelay<CGFloat>(value: 0.00)
    var messageTextViewContent = BehaviorRelay<String>(value: "")
    weak var delegate: MessageAccessoryViewDelegate?

    var blurEffect: UIVisualEffectView?

    override func didMoveToWindow() {
        self.setupMessageTextView()
        super.didMoveToWindow()
        if #available(iOS 11.0, *) {
            guard let window = self.window else {
                return
            }
            self.bottomAnchor
                .constraint(lessThanOrEqualToSystemSpacingBelow: window.safeAreaLayoutGuide.bottomAnchor,
                            multiplier: 1)
                .isActive = true
        }
        blurEffect?.removeFromSuperview()
        if #available(iOS 13.0, *) {
            blurEffect = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        } else {
            blurEffect = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
        }
        self.backgroundColor = UIColor.jamiBackgroundColor
        if blurEffect != nil {
            blurEffect!.frame = self.bounds
            self.insertSubview(blurEffect!, at: 0)
            blurEffect!.topAnchor.constraint(equalTo: messageTextView.topAnchor, constant: -12.0).isActive = true
            blurEffect!.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 40).isActive = true
            blurEffect!.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0).isActive = true
            blurEffect!.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0).isActive = true
            blurEffect!.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    func setPlaceholder(placeholder: String) {
        self.messageTextView.placeholder = placeholder
    }

    func setupMessageTextView() {
        self.messageTextView.delegate = self
        self.messageTextView.layer.cornerRadius = 18
        self.messageTextView.tintColor = UIColor.jamiMain
        self.messageTextView.textContainerInset = UIEdgeInsets(top: 8, left: 7, bottom: 8, right: 7)
        self.messageTextView.layer.borderWidth = 1
        self.messageTextView.layer.borderColor = UIColor.jamiMsgTextFieldBorder.cgColor
        self.messageTextView.maxHeight = 70
        self.shareButton.tintColor = UIColor.jamiMain
        self.cameraButton.tintColor = UIColor.jamiMain
        self.messageTextView.backgroundColor = UIColor.jamiInputTextBackground
    }

    func textViewDidChangeHeight(_ textView: GrowingTextView, height: CGFloat) {
        if height > self.messageTextViewHeight.value {
            UIView.animate(withDuration: 0.2) {
                self.layoutIfNeeded()
            }
        }
        self.messageTextViewHeight.accept(height)
    }

    func textViewDidChange(_ textView: UITextView) {
        self.messageTextViewContent.accept(textView.text)
    }

    func editingChanges() {
        var isComposing = false
        if self.messageTextView.text != nil {
            if self.messageTextView.text!.count >= 1 {
                isComposing = true
                setEmojiButtonVisibility(hide: true)
            } else {
                setEmojiButtonVisibility(hide: false)
            }
        } else {
            setEmojiButtonVisibility(hide: false)
        }

        if let delegate = self.delegate {
            delegate.setIsComposing(isComposing: isComposing)
        }
    }
    func setEmojiButtonVisibility(hide: Bool) {
        UIView.animate(withDuration: 0.2, animations: {
            if hide {
                self.emojisButtonTrailingConstraint.constant = -27
                self.sendButtonLeftConstraint.constant = 13
                self.sendButton.tintColor = UIColor.jamiMain
            } else {
                self.emojisButtonTrailingConstraint.constant = 14
                self.sendButtonLeftConstraint.constant = 35
                self.sendButton.tintColor = UIColor.jamiMsgTextFieldBackground
            }
            self.layoutIfNeeded()
        })
    }
}
