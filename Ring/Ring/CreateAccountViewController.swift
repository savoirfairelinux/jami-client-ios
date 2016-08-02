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

    // MARK: - TextField validation feedback

    func giveVisualFeedback(field: UITextField) {
        if !(field.text?.isEmpty)! {
            field.rightViewMode = .Never
            return
        }
        field.rightViewMode = .Always
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        imageView.image = UIImage(named: "ic_warning.png")
        imageView.contentMode = .ScaleAspectFit
        field.rightView = imageView
    }

    // MARK: - Actions
    @IBAction func onJoinTheRing(sender: UIButton) {

        if let username = usernameTextField.text where !username.isEmpty {
            if let password = passwordTextField.text where !password.isEmpty {
                usernameTextField.enabled = false
                passwordTextField.enabled = false
                joinTheRingButton.enabled = false
                logIntoExistingButton.enabled = false
                registerSwitch.enabled = false

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
                return
            }
        }

        giveVisualFeedback(usernameTextField)
        giveVisualFeedback(passwordTextField)
    }
}
