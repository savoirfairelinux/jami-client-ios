/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

import Foundation
import RxSwift
import UIKit

// swiftlint:disable identifier_name

extension UIViewController {
    /// Find the active UITextField if it exists
    ///
    /// - Parameters:
    ///     - view: The UIView to search into
    /// - Returns: The active UITextField (ie: isFirstResponder)
    func findActiveTextField(in view: UIView) -> UITextField? {
        guard !view.subviews.isEmpty else { return nil }

        for currentView in view.subviews {
            if let textfield = currentView as? UITextField,
               textfield.isFirstResponder {
                return textfield
            }

            if let textField = findActiveTextField(in: currentView) {
                return textField
            }
        }

        return nil
    }

    func findPathWithActiveTextField(in table: UITableView) -> IndexPath? {
        if table.numberOfSections <= 0 { return nil }
        for i in 0 ..< table.numberOfSections {
            if table.numberOfRows(inSection: i) == 0 { return nil }
            for k in 0 ..< table.numberOfRows(inSection: i) {
                let path = IndexPath(row: k, section: i)
                if let row = table.cellForRow(at: path) {
                    if findActiveTextField(in: row) != nil {
                        return path
                    }
                }
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
    func adaptToKeyboardState(for scrollView: UIScrollView, with disposeBag: DisposeBag) {
        NotificationCenter.keyboardHeight.observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self, weak scrollView] height in
                guard let self = self, let scrollView = scrollView else { return }
                let trueHeight = height > 0 ? height + 100 : 0.0
                let contentInsets = UIEdgeInsets(
                    top: 0.0,
                    left: 0.0,
                    bottom: trueHeight,
                    right: 0.0
                )

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
            })
            .disposed(by: disposeBag)
    }

    func adaptToWelcomeFormKeyboardState(for scrollView: UIScrollView,
                                         with disposeBag: DisposeBag) {
        NotificationCenter.keyboardHeight.observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self, weak scrollView] height in
                guard let self = self, let scrollView = scrollView else { return }
                let trueHeight = height
                if [.landscapeRight, .landscapeLeft].contains(ScreenHelper.currentOrientation()) {
                    let contentInsets = UIEdgeInsets(
                        top: 0.0,
                        left: 0.0,
                        bottom: trueHeight,
                        right: 0.0
                    )
                    scrollView.contentInset = contentInsets
                } else {
                    scrollView.contentInset = UIEdgeInsets(
                        top: 0.0,
                        left: 0.0,
                        bottom: 0.0,
                        right: 0.0
                    )
                }

                // If active text field is hidden by keyboard, scroll it so it's visible
                // Your app might not need or want this behavior.
                if let activeField = self.findActiveTextField(in: scrollView) {
                    var aRect = self.view.frame
                    aRect.size.height -= trueHeight

                    let activeFieldBottomPoint = CGPoint(
                        x: activeField.frame.origin.x,
                        y: activeField.frame.origin.y + activeField.frame.size.height + 10
                    ) // added 10 as padding

                    if !aRect.contains(activeFieldBottomPoint) {
                        scrollView.scrollRectToVisible(activeField.frame, animated: true)
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    func adaptTableToKeyboardState(
        for tableView: UITableView,
        with disposeBag: DisposeBag,
        topOffset _: CGFloat? = nil,
        bottomOffset _: CGFloat? = nil
    ) {
        NotificationCenter.keyboardHeight
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self, weak tableView] height in
                guard let self = self, let tableView = tableView else { return }
                let trueHeight = height > 0 ? height + 100 : 0.0
                // reset insets if they were changed before
                if tableView.contentInset.bottom > 0, trueHeight <= 0 {
                    var contentInsets = tableView.contentInset
                    contentInsets.bottom = 0
                    tableView.contentInset = contentInsets
                    return
                }
                if let activeFieldRowPath = self.findPathWithActiveTextField(in: tableView) {
                    let rectOfCell = tableView.rectForRow(at: activeFieldRowPath)
                    let rectOfCellInSuperview = tableView.convert(rectOfCell, to: self.view)
                    var aRect = self.view.frame
                    aRect.origin = CGPoint(x: 0, y: 0)
                    aRect.size.height -= (height + 50)
                    if !aRect.contains(rectOfCellInSuperview.origin) {
                        var contentInsets = tableView.contentInset
                        if trueHeight > 0 {
                            contentInsets.bottom += trueHeight
                            tableView.contentInset = contentInsets
                        }
                        tableView.scrollToRow(at: activeFieldRowPath, at: .top, animated: true)
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    func configureNavigationBar(
        isTransparent: Bool = false,
        backgroundColor: UIColor = .systemBackground
    ) {
        let appearance = UINavigationBarAppearance()
        if isTransparent {
            appearance.configureWithTransparentBackground()
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
        }

        // Explicitly set shadow properties to none
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        navigationController?.navigationBar.tintColor = UIColor.jamiButtonDark
        navigationController?.navigationBar.layer.shadowOpacity = 0

        // Apply the appearance configuration
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.standardAppearance = appearance

        if #available(iOS 16.0, *) {
            navigationItem.preferredSearchBarPlacement = .stacked
        }
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    func configureWalkrhroughNavigationBar() {
        let attrPortrait = [NSAttributedString.Key.foregroundColor: UIColor.jamiTextSecondary,
                            NSAttributedString.Key.font: UIFont.systemFont(
                                ofSize: 31,
                                weight: .thin
                            )]
        let attrLandscape = [NSAttributedString.Key.foregroundColor: UIColor.jamiTextSecondary,
                             NSAttributedString.Key.font: UIFont.systemFont(
                                ofSize: 20,
                                weight: .regular
                             )]
        let isPortrait = UIScreen.main.bounds.size.width < UIScreen.main.bounds.size.height
        navigationController?
            .navigationBar.titleTextAttributes = isPortrait ?
            attrPortrait : attrLandscape
    }

    @objc
    func resizeFrom(initialFrame _: CGRect) {}

    func addChildController(_ child: UIViewController, initialFrame: CGRect) {
        addChild(child)
        view.addSubview(child.view)
        child.resizeFrom(initialFrame: initialFrame)
        child.didMove(toParent: self)
    }

    func removeChildController() {
        guard parent != nil else { return }
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }
}

public extension UINavigationController {
    static func navBarHeight() -> CGFloat {
        let nVc = UINavigationController(rootViewController: UIViewController(
            nibName: nil,
            bundle: nil
        ))
        let navBarHeight = nVc.navigationBar.frame.size.height
        return navBarHeight
    }
}
