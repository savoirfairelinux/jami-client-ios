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

class MessageAccessoryView: UIView, NibLoadable {

//    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var emojisButton: UIButton!
    @IBOutlet weak var emojisButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewHeightConstraints: NSLayoutConstraint!
    //    @IBOutlet weak var messageTextFieldTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewHeightConstraints: NSLayoutConstraint!
    @IBOutlet weak var messageTextView: GrowingTextView!

    override open func didMoveToWindow() {
        super.didMoveToWindow()
        self.messageTextView.placeholder = "Type your message..."
        self.messageTextView.layer.cornerRadius = 10
        self.messageTextView.layer.borderWidth = 1
        self.messageTextView.layer.borderColor = UIColor.ringMsgTextFieldBorder.cgColor
        self.messageTextView.maxHeight = 100
        if #available(iOS 11.0, *) {
            guard let window = self.window else {
                return
            }
            self.bottomAnchor
                .constraintLessThanOrEqualToSystemSpacingBelow(window.safeAreaLayoutGuide.bottomAnchor,
                                                               multiplier: 1)
                .isActive = true
        }
    }

    @IBAction func editingChanges(_ sender: Any) {
        if self.messageTextView.text != nil {
            if self.messageTextView.text!.count >= 1 {
                if UIDevice.current.userInterfaceIdiom != .pad {
                    setEmojiButtonVisibility(hide: true)
                }
            } else {
                setEmojiButtonVisibility(hide: false)
            }
        } else {
            setEmojiButtonVisibility(hide: false)
        }
    }
    func setEmojiButtonVisibility(hide: Bool) {
        UIView.animate(withDuration: 0.3, animations: {
            if hide {
                self.emojisButtonTrailingConstraint.constant = -27
            } else {
                self.emojisButtonTrailingConstraint.constant = 13
            }
            self.layoutIfNeeded()
        })
    }
}
