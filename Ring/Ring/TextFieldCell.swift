//
//  TextFieldCell.swift
//  Ring
//
//  Created by Silbino Goncalves Matado on 17-03-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import UIKit

class TextFieldCell: UITableViewCell {

    @IBOutlet weak var textField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
