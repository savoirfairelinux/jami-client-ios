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

import RxSwift
import UIKit

class CustomSearchBar: UISearchBar {
    var rightButton = UIButton()
    var buttonView = UIView()
    let trailing: CGFloat = -50
    let trailing1: CGFloat = -50.5
    let leading: CGFloat = 15
    let trailingEditing: CGFloat = -80
    let trailingEditing1: CGFloat = -80.5
    let buttonSize: CGFloat = 50
    var totalItem: CGFloat = 1.0
    let disposeBag = DisposeBag()

    var rightMargin: CGFloat {
        let orientation = UIDevice.current.orientation
        let margin: CGFloat = UIDevice.current
            .hasNotch && (orientation == .landscapeRight || orientation == .landscapeLeft) ? -50 : 0
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
        let margin: CGFloat = UIDevice.current
            .hasNotch && (orientation == .landscapeRight || orientation == .landscapeLeft) ? 60 : 15
        return margin
    }

    var searchFieldTrailing = NSLayoutConstraint()
    var searchFieldLeading = NSLayoutConstraint()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init() {
        super.init(frame: CGRect.zero)
        if isRightToLeft {
            buttonView = UIView(frame: CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        } else {
            buttonView = UIView(frame: CGRect(
                x: frame.size.width - buttonSize,
                y: 0,
                width: buttonSize,
                height: buttonSize
            ))
        }
    }

    func sizeChanged(to size: CGFloat, totalItems: CGFloat) {
        totalItem = totalItems
        var buttonFrame = buttonView.frame
        let margin = rightMargin
        if isRightToLeft {
            buttonFrame.origin.x = margin
        } else {
            buttonFrame.origin.x = size - (buttonSize * totalItems) + margin
        }
        buttonView.frame = CGRect(
            x: buttonFrame.origin.x,
            y: buttonFrame.origin.y,
            width: buttonSize * totalItems,
            height: buttonSize
        )
        if margin == 0 {
            searchFieldTrailing.constant = rightButton
                .isHidden ? currentTrailingEditing : (currentTrailing * totalItems)
        } else {
            searchFieldTrailing.constant += margin
        }
        searchFieldLeading.constant = leftMargin
    }

    func updateImage(buttonImage: UIImage) {
        rightButton.setImage(buttonImage, for: .normal)
    }

    func configure(buttonImage: UIImage, position: CGFloat, buttonPressed: @escaping (() -> Void)) {
        rightButton = UIButton(frame: CGRect(
            x: (buttonSize * position) - buttonSize,
            y: 0,
            width: buttonSize,
            height: buttonSize
        ))
        rightButton.imageEdgeInsets = UIEdgeInsets(
            top: 12,
            left: position == 2 ? 8 : 16,
            bottom: 12,
            right: position == 2 ? 16 : 8
        )
        rightButton.setImage(buttonImage, for: .normal)
        rightButton.tintColor = UIColor.jamiMain
        buttonView.addSubview(rightButton)
        addSubview(buttonView)
        rightButton.translatesAutoresizingMaskIntoConstraints = true
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchFieldTrailing = searchTextField.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: currentTrailing
        )
        searchFieldTrailing.isActive = true
        searchFieldLeading = searchTextField.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: leading
        )
        searchFieldLeading.isActive = true
        searchTextField.topAnchor.constraint(equalTo: topAnchor, constant: 7).isActive = true
        rightButton.rx.tap
            .subscribe(onNext: { buttonPressed() })
            .disposed(by: disposeBag)
        rx.textDidBeginEditing
            .subscribe(onNext: { [weak self] in
                self?.hideRightButton()
            })
            .disposed(by: disposeBag)
        rx.textDidEndEditing
            .subscribe(onNext: { [weak self] in
                self?.showRightButton()
            })
            .disposed(by: disposeBag)
    }

    func hideRightButton() {
        buttonView.isHidden = true
        rightButton.isEnabled = false
        searchFieldTrailing.constant = currentTrailingEditing
        searchFieldTrailing.constant += rightMargin
    }

    func showRightButton() {
        buttonView.isHidden = false
        rightButton.isEnabled = true
        searchFieldTrailing.constant = currentTrailing * totalItem
        searchFieldTrailing.constant += rightMargin
    }

    func hideButton(hide: Bool) {
        rightButton.isHidden = hide
    }
}
