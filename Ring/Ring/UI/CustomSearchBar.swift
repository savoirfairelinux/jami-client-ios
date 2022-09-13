/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
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

class CustomSearchBar: UISearchBar {
    var rightButton = UIButton()
    let trailing: CGFloat = -50
    let trailing1: CGFloat = -50.5
    let leading: CGFloat = 15
    let trailingEditing: CGFloat = -80
    let trailingEditing1: CGFloat = -80.5
    let buttonSize: CGFloat = 50
    let disposeBag = DisposeBag()

    var rightMargin: CGFloat {
        let orientation = UIDevice.current.orientation
        let margin: CGFloat = UIDevice.current.hasNotch && (orientation == .landscapeRight || orientation == .landscapeLeft) ? -50 : 0
        return margin
    }

    var currentTrailing: CGFloat {
        return trailing
    }

    var currentTrailingEditing: CGFloat {
        trailingEditing
    }

    var leftMargin: CGFloat {
        let orientation = UIDevice.current.orientation
        let margin: CGFloat = UIDevice.current.hasNotch && (orientation == .landscapeRight || orientation == .landscapeLeft) ? 60 : 15
        return margin
    }

    var searchFieldTrailing = NSLayoutConstraint()
    var searchFieldLeading = NSLayoutConstraint()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    init() {
        super.init(frame: CGRect.zero)
    }
    func sizeChanged(to size: CGFloat) {
        var buttonFrame = rightButton.frame
        let margin = rightMargin
        buttonFrame.origin.x = size - buttonSize + margin
        rightButton.frame = buttonFrame
        if margin == 0 {
            searchFieldTrailing.constant = rightButton.isHidden ? currentTrailingEditing : currentTrailing
        } else {
            searchFieldTrailing.constant += margin
        }
        searchFieldLeading.constant = leftMargin
    }

    func updateImage(buttonImage: UIImage) {
        rightButton.setImage(buttonImage, for: .normal)
    }

    func configure(buttonImage: UIImage, buttonPressed: @escaping (() -> Void)) {
        rightButton = UIButton(frame: CGRect(x: self.frame.size.width - buttonSize - 10, y: 0, width: buttonSize, height: buttonSize))
        rightButton.imageEdgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        rightButton.setImage(buttonImage, for: .normal)
        rightButton.tintColor = UIColor.jamiMain
        self.addSubview(rightButton)
        rightButton.translatesAutoresizingMaskIntoConstraints = true
        self.searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchFieldTrailing = self.searchTextField.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: currentTrailing)
        searchFieldTrailing.isActive = true
        searchFieldLeading = self.searchTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: leading)
        searchFieldLeading.isActive = true
        self.searchTextField.topAnchor.constraint(equalTo: self.topAnchor, constant: 7).isActive = true
        rightButton.rx.tap
            .subscribe(onNext: { buttonPressed() })
            .disposed(by: self.disposeBag)
        self.rx.textDidBeginEditing
            .subscribe(onNext: { [weak self] in
                self?.hideRightButton()
            })
            .disposed(by: self.disposeBag)
        self.rx.textDidEndEditing
            .subscribe(onNext: { [weak self] in
                self?.showRightButton()
            })
            .disposed(by: self.disposeBag)
    }

    func hideRightButton() {
        rightButton.isHidden = true
        rightButton.isEnabled = false
        searchFieldTrailing.constant = currentTrailingEditing
        searchFieldTrailing.constant += rightMargin
    }

    func showRightButton() {
        rightButton.isHidden = false
        rightButton.isEnabled = true
        searchFieldTrailing.constant = currentTrailing
        searchFieldTrailing.constant += rightMargin
    }

    func hideButton(hide: Bool) {
        rightButton.isHidden = hide
    }
}
