//
//  MessageCellInTheMiddle.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-09-28.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation
import Reusable

class MessageCellGenerated : UITableViewCell, NibReusable {

    @IBOutlet weak var bubble: MessageBubble!
    @IBOutlet weak var messageLabel: UILabel!
    
}

