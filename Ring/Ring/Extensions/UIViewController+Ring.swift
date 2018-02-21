/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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
import UIKit
import RxSwift

extension UIViewController {

    /// Find the active UITextField if it exists
    ///
    /// - Parameters:
    ///     - view: The UIView to search into
    /// - Returns: The active UITextField (ie: isFirstResponder)
    func findActiveTextField(in view: UIView) -> UITextField? {

        guard !view.subviews.isEmpty else { return nil }

        for currentView in view.subviews {
            if  let textfield = currentView as? UITextField,
                textfield.isFirstResponder {
                return textfield
            }

            if let textField = findActiveTextField(in: currentView) {
                return textField
            }
        }

        return nil
    }

    /// Scroll the UIScrollView to the right position
    /// according to keyboard's height
    ///
    /// - Parameters:
    ///     - scrollView: The scrollView to adapt
    ///     - disposeBag: The RxSwift DisposeBag linked to the UIViewController life cycle
    func adaptToKeyboardState (for scrollView: UIScrollView, with disposeBag: DisposeBag) {

        NotificationCenter.keyboardHeight.observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self, unowned scrollView] (height) in
            let trueHeight = height>0 ? height+100 : 0.0
            let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: trueHeight, right: 0.0)

            scrollView.contentInset = contentInsets

            // If active text field is hidden by keyboard, scroll it so it's visible
            // Your app might not need or want this behavior.
            if let activeField = self.findActiveTextField(in: scrollView) {
                var aRect = self.view.frame
                aRect.size.height -= trueHeight

                if !aRect.contains(activeField.frame.origin) {
                    scrollView.scrollRectToVisible(activeField.frame, animated: true)
                }
            }

        }).disposed(by: disposeBag)

    }

    func applyShadow() {
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.ringNavigationBar.darken(byPercentage: 0.1).cgColor
        self.navigationController?.navigationBar.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
        self.navigationController?.navigationBar.layer.shadowRadius = 1.0
        self.navigationController?.navigationBar.layer.shadowOpacity = 0.8
        self.navigationController?.navigationBar.layer.masksToBounds = false
    }
}
