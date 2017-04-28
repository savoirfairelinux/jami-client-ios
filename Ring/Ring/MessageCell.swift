//
//  MessageCell.swift
//  Ring
//
//  Created by Silbino Goncalves Matado on 17-04-27.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import UIKit

enum BubblePosition {
    case received
    case sent
}

class MessageCell: UITableViewCell {

    @IBOutlet weak var bubble: UIView!
    @IBOutlet weak var messageLabel: UILabel!

    @IBOutlet weak var minimumLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerLeadingConstraint: NSLayoutConstraint!

    @IBOutlet weak var minimumTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var containerTrailingConstraint: NSLayoutConstraint!

    var bubblePosition = BubblePosition.received {
        didSet {
            if bubblePosition == .sent {
                self.minimumTrailingConstraint.priority = 1
                self.containerTrailingConstraint.priority = 999
                self.containerLeadingConstraint.priority = 1
                self.minimumLeadingConstraint.priority = 999

                self.bubble.backgroundColor = UIColor.blue
                self.messageLabel.textColor = UIColor.white
            } else {
                self.minimumLeadingConstraint.priority = 1
                self.containerLeadingConstraint.priority = 999
                self.containerTrailingConstraint.priority = 1
                self.minimumTrailingConstraint.priority = 999

                self.bubble.backgroundColor = UIColor.lightGray
                self.messageLabel.textColor = UIColor.black
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.bubblePosition = .received
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
