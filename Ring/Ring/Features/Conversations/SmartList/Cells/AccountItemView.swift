//
//  AccountItemView.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2019-03-15.
//  Copyright © 2019 Savoir-faire Linux. All rights reserved.
//

import UIKit

class AccountItemView: UIView {

    @IBOutlet var containerView: UIView!
    @IBOutlet weak var avatarView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.commonInit()
    }

    func commonInit() {
        Bundle.main.loadNibNamed("AccountItemView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = self.bounds
    }
}
