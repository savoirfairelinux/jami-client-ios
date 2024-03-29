/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

class DisposableCell: UITableViewCell {
    var disposeBag = DisposeBag()

    override func prepareForReuse() {
        super.prepareForReuse()
        self.backgroundColor = .systemBackground
        self.disposeBag = DisposeBag()
    }
}

class EditableDetailTableViewCell: DisposableCell {
    let editableTextField = UITextField()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupTextField()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private func setupTextField() {
        editableTextField.font = UIFont.preferredFont(forTextStyle: .callout)
        editableTextField.returnKeyType = .done
        self.contentView.addSubview(editableTextField)
        detailTextLabel?.numberOfLines = 0
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
        detailTextLabel?.textColor = .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let detailTextFrame = detailTextLabel?.frame {
            editableTextField.frame = detailTextFrame
        }
    }

    func setEditText(withTitle title: String) {
        detailTextLabel?.text = title
        editableTextField.text = title
    }
}
