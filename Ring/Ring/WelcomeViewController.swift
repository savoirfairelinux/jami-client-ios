/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

class WelcomeViewController: UIViewController {

    @IBOutlet weak var ringImageView: UIImageView!
    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var linkDeviceButton: RoundedButton!
    @IBOutlet weak var createAccountButton: RoundedButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func setupUI() {

        let walkthroughTableName = "Walkthrough"

        self.welcomeLabel.text = NSLocalizedString("WelcomeTitle",
                                                   tableName: walkthroughTableName,
                                                   comment: "")
        self.descriptionLabel.text = NSLocalizedString("WelcomeText",
                                                       tableName: walkthroughTableName,
                                                       comment: "")
        self.linkDeviceButton.setTitle(NSLocalizedString("LinkDeviceButton",
                                                         tableName: walkthroughTableName,
                                                         comment: ""), for: .normal)
        self.createAccountButton.setTitle(NSLocalizedString("CreateAccount",
                                                            tableName: walkthroughTableName,
                                                            comment: ""), for: .normal)
    }
}
