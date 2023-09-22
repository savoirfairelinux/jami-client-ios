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

class CustomNavigationBar: UINavigationBar {

    var customHeight: CGFloat = 44.0
    var customSearchView: UIView?

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: UIScreen.main.bounds.width, height: customHeight)
    }

    func addCustomSearchView() {
        customSearchView = UIView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: 50))
        customSearchView?.backgroundColor = .clear  // Or any color you prefer

        let label = UILabel(frame: CGRect(x: 10, y: 0, width: 200, height: 40))
        label.text = "Custom Label"

        let button = UIButton(frame: CGRect(x: self.bounds.width - 200, y: 0, width: 100, height: 40))
        button.setTitle("Button", for: .normal)
        button.addTarget(self, action: #selector(handleButtonTap), for: .touchUpInside)

        customSearchView?.addSubview(label)
        customSearchView?.addSubview(button)

        if let customView = customSearchView {
            addSubview(customView)
        }
    }

    @objc
    func handleButtonTap() {}

    func removeCustomSearchView() {
        customSearchView?.removeFromSuperview()
        customSearchView = nil
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
