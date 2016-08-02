/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
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

class CreateAccountViewController: UIViewController {

    // MARK: - Properties
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var joinTheRingButton: RoundedButton!
    @IBOutlet weak var logIntoExistingButton: RoundedButton!
    @IBOutlet weak var registerSwitch: UISwitch!

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Actions
    @IBAction func onJoinTheRing(sender: UIButton) {
        let username = usernameTextField.text!
        let password = passwordTextField.text!
        if username.isEmpty {
            // TODO: Add visual indication for error
        } else if password.isEmpty {

        } else {

            usernameTextField.enabled = false
            passwordTextField.enabled = false
            joinTheRingButton.enabled = false
            logIntoExistingButton.enabled = false

            // FIXME: Thread is not registered with pj_sip ...
            // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            AccountModel.sharedInstance.addAccount(accountType: .RING,
                username: username,
                password: password,
                registerOnNetwork: registerSwitch.on)
            // }
            if let pageViewController = self.parentViewController as! IntroductionPageViewController? {
                pageViewController.nextPage()
            }
        }
    }
}
