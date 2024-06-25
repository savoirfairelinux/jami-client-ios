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

import RxSwift
import UIKit

class SmartListNavigationBar: UINavigationBar {
    private enum Constants {
        static let topViewHeight: CGFloat = 50.0
        static let buttonSpacing: CGFloat = -22.0
        static let trailing: CGFloat = -15.0
    }

    var topView: UIView?
    var disposeBag = DisposeBag()
    var usingCustomSize = false
    var customHeight: CGFloat = 44.0

    func addTopView(with buttons: [UIButton]) {
        setupTopView()
        setupSearchTitleLabel()
        layoutButtons(buttons)
    }

    func removeTopView() {
        topView?.removeFromSuperview()
        topView = nil
        disposeBag = DisposeBag()
    }

    var searchActive = false {
        didSet {
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !usingCustomSize {
            return
        }
        adjustSubviewsFrame()
    }

    override var frame: CGRect {
        didSet {
            if frame.size.height < customHeight && searchActive && usingCustomSize {
                super.frame = CGRect(
                    x: frame.origin.x,
                    y: frame.origin.y,
                    width: frame.size.width,
                    height: customHeight
                )
            } else {
                super.frame = frame
            }
        }
    }
}

// MARK: - Private helpers

private extension SmartListNavigationBar {
    func setupTopView() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear

        addSubview(view)

        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: guide.topAnchor, constant: -5),
            view.heightAnchor.constraint(equalToConstant: Constants.topViewHeight),
            view.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: guide.trailingAnchor)
        ])

        topView = view
    }

    func setupSearchTitleLabel() {
        guard let topView = topView else { return }

        let title = UILabel()
        title.text = L10n.Smartlist.searchBar
        title.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        topView.addSubview(title)
        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: topView.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: topView.centerYAnchor)
        ])
    }

    func layoutButtons(_ buttons: [UIButton]) {
        guard let topView = topView else { return }

        var previousButton: UIButton?
        for button in buttons {
            button.translatesAutoresizingMaskIntoConstraints = false
            topView.addSubview(button)

            if let prevBtn = previousButton {
                button.trailingAnchor.constraint(
                    equalTo: prevBtn.leadingAnchor,
                    constant: Constants.buttonSpacing
                ).isActive = true
            } else {
                button.trailingAnchor.constraint(
                    equalTo: topView.trailingAnchor,
                    constant: Constants.trailing
                ).isActive = true
            }
            button.centerYAnchor.constraint(equalTo: topView.centerYAnchor).isActive = true
            previousButton = button
        }
    }

    func adjustSubviewsFrame() {
        for subview in subviews {
            let stringFromClass = NSStringFromClass(subview.classForCoder)

            if stringFromClass.contains("UINavigationBarContentView"), searchActive {
                subview.frame = CGRect(x: 0, y: 0, width: frame.width, height: customHeight)
            }

            if stringFromClass.contains("SearchBar"), searchActive {
                subview.frame = CGRect(
                    x: 0,
                    y: 36,
                    width: frame.width,
                    height: subview.frame.height
                )
            }
        }
    }
}
