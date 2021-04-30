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

class CustomSearchController: UISearchController {
    private var customSearchBar = CustomSearchBar()
    override var searchBar: UISearchBar {
        return customSearchBar
    }

    func configureSearchBar(image: UIImage, buttonPressed: @escaping (() -> Void)) {
        customSearchBar.configure(buttonImage: image, buttonPressed: buttonPressed)
    }

    func updateSearchBar(image: UIImage) {
        customSearchBar.updateImage(buttonImage: image)
    }
    func sizeChanged(to size: CGFloat) {
        customSearchBar.sizeChanged(to: size)
    }
    func hideButton(hide: Bool) {
        customSearchBar.hideButton(hide: hide)
    }
}
