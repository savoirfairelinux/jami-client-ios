//
//  RoundedButton.swift
//  Ring
//
//  Created by Edric on 16-08-02.
//  Copyright © 2016 Savoir-faire Linux. All rights reserved.
//

import UIKit

class RoundedButton: UIButton {

    /*
     // Only override drawRect: if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func drawRect(rect: CGRect) {
     // Drawing code
     }
     */

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layer.borderColor = self.backgroundColor?.CGColor
        self.layer.borderWidth = 1.0
        self.clipsToBounds = true
        self.layer.cornerRadius = 15.0
    }

}
