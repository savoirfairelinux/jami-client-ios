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

class CustomNavigationBar: UINavigationBar {

    var customHeight: CGFloat = 44.0
    var customSearchView: UIView?
    var disposeBag = DisposeBag()

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: UIScreen.main.bounds.width, height: customHeight)
    }

    func addCustomSearchView(with buttons: [UIButton]) {
        customSearchView = UIView()
        customSearchView?.translatesAutoresizingMaskIntoConstraints = false
        customSearchView?.backgroundColor = .clear

        addSubview(customSearchView!)
        customSearchView?.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        customSearchView?.heightAnchor.constraint(equalToConstant: 50).isActive = true
        customSearchView?.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        customSearchView?.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        let title = UILabel()
        title.text = "Search"
        title.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        title.translatesAutoresizingMaskIntoConstraints = false
        customSearchView?.addSubview(title)
        title.centerXAnchor.constraint(equalTo: customSearchView!.centerXAnchor).isActive = true
        title.centerYAnchor.constraint(equalTo: customSearchView!.centerYAnchor).isActive = true

        var previousButton: UIButton?
        for button in buttons {
            button.translatesAutoresizingMaskIntoConstraints = false
            customSearchView?.addSubview(button)

            if let prevBtn = previousButton {
                button.trailingAnchor.constraint(equalTo: prevBtn.leadingAnchor, constant: -15).isActive = true
            } else {
                button.trailingAnchor.constraint(equalTo: customSearchView!.trailingAnchor, constant: -15).isActive = true
            }

            button.centerYAnchor.constraint(equalTo: customSearchView!.centerYAnchor).isActive = true
            button.widthAnchor.constraint(equalToConstant: 25).isActive = true
            button.heightAnchor.constraint(equalToConstant: 25).isActive = true
            previousButton = button
        }
    }

    func removeCustomSearchView() {
        customSearchView?.removeFromSuperview()
        customSearchView = nil
        disposeBag = DisposeBag()
    }

    var increaseHeight = false {
        didSet {
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        for subview in self.subviews {
            let stringFromClass = NSStringFromClass(subview.classForCoder)

            if stringFromClass.contains("UINavigationBarContentView") {
                if increaseHeight {
                    subview.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: customHeight)
                }
            }

            if stringFromClass.contains("SearchBar") {
                if increaseHeight {
                    subview.frame = CGRect(x: 0, y: 40, width: self.frame.width, height: subview.frame.height)
                }
            }

        }
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: super.intrinsicContentSize.width, height: customHeight)
    }

    override var frame: CGRect {
        didSet {
            var newFrame = frame
            if newFrame.size.height < customHeight && increaseHeight {
                newFrame.size.height = customHeight
            }
            super.frame = newFrame
        }
    }
}

class CustomSearchController: UISearchController {
    private var customSearchBar = CustomSearchBar()
    override var searchBar: UISearchBar {
        return customSearchBar
    }

    func configureSearchBar(image: UIImage, position: CGFloat, buttonPressed: @escaping (() -> Void)) {
        customSearchBar.configure(buttonImage: image, position: position, buttonPressed: buttonPressed)
    }

    func updateSearchBar(image: UIImage) {
        customSearchBar.updateImage(buttonImage: image)
    }
    func sizeChanged(to size: CGFloat, totalItems: CGFloat) {
        customSearchBar.sizeChanged(to: size, totalItems: totalItems)
    }
    func hideButton(hide: Bool) {
        customSearchBar.hideButton(hide: hide)
    }
}
