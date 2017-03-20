//
//  SwitchCell.swift
//  Ring
//
//  Created by Silbino Goncalves Matado on 17-03-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import UIKit

class SwitchCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var registerSwitch: UISwitch!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
