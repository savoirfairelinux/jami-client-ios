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
    let buttonOriginXOffset: CGFloat = -49
    let buttonSize: CGFloat = 40
    let disposeBag = DisposeBag()

    var rightMargin: CGFloat {
        let orientation = UIDevice.current.orientation
        let margin: CGFloat = UIDevice.current.hasNotch && (orientation == .landscapeRight || orientation == .landscapeLeft) ? -50 : 0
        return margin
    }

    var currentTrailing: CGFloat {
        if #available(iOS 13.0, *) {
            return trailing
        }
        let trailingConst = searchFieldTrailing.constant
        if trailingConst == trailing {
            return trailing1
        }
        return trailing
    }

    var currentTrailingEditing: CGFloat {
        if #available(iOS 13.0, *) {
            return trailingEditing
        }
        let trailingConst = searchFieldTrailing.constant
        if trailingConst == trailingEditing {
            return trailingEditing1
        }
        return trailingEditing
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
        buttonFrame.origin.x = size + buttonOriginXOffset + margin
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
        rightButton = UIButton(frame: CGRect(x: self.frame.size.width + buttonOriginXOffset, y: 3, width: buttonSize, height: buttonSize))
        rightButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        rightButton.setImage(buttonImage, for: .normal)
        rightButton.tintColor = UIColor.jamiMain
        self.addSubview(rightButton)
        rightButton.translatesAutoresizingMaskIntoConstraints = true
        if #available(iOS 13.0, *) {
            self.searchTextField.translatesAutoresizingMaskIntoConstraints = false
            searchFieldTrailing = self.searchTextField.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: currentTrailing)
            searchFieldTrailing.isActive = true
            searchFieldLeading = self.searchTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: leading)
            searchFieldLeading.isActive = true
            self.searchTextField.topAnchor.constraint(equalTo: self.topAnchor, constant: 7).isActive = true
        } else {
            for view in subviews {
                if let searchField = view as? UITextField {
                    searchField.translatesAutoresizingMaskIntoConstraints = false
                    searchFieldTrailing = searchField.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: currentTrailing)
                    searchFieldTrailing.isActive = true
                    searchField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
                    searchField.topAnchor.constraint(equalTo: self.topAnchor, constant: 7).isActive = true
                } else {
                    for sView in view.subviews {
                        if let searchField = sView as? UITextField {
                            searchField.translatesAutoresizingMaskIntoConstraints = false
                            searchFieldTrailing = searchField.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: currentTrailing)
                            searchFieldTrailing.isActive = true
                            searchField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
                            searchField.topAnchor.constraint(equalTo: self.topAnchor, constant: 7).isActive = true
                        }
                    }
                }
            }
        }
        rightButton.rx.tap
            .throttle(Durations.halfSecond.toTimeInterval(), scheduler: MainScheduler.instance)
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
