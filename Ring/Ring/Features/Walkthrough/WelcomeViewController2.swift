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

class WelcomeViewController2: UIViewController {

    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var linkDeviceButton: DesignableButton!
    @IBOutlet weak var createAccountButton: DesignableButton!

    let createProfileSegueIdentifier = "CreateProfileSegue"
    let linkDeviceToAccountSegueIdentifier = "LinkDeviceToAccountSegue"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    @IBAction func linkDeviceToAccountAction(_ sender: Any) {
        self.performSegue(withIdentifier: linkDeviceToAccountSegueIdentifier, sender: nil)
    }

    @IBAction func createAccountAction(_ sender: Any) {
        self.performSegue(withIdentifier: createProfileSegueIdentifier, sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)

        var profileCreationType: ProfileCreationType?

        if segue.identifier == createProfileSegueIdentifier {
            profileCreationType = .createProfile
        } else if segue.identifier == linkDeviceToAccountSegueIdentifier {
            profileCreationType = .linkDeviceToAccount
        }

        if let createProfileViewController = segue.destination as? CreateProfileViewController {
            createProfileViewController.profileCreationType = profileCreationType
        }
    }

    func setupUI() {

        self.welcomeLabel.text = L10n.Welcome.title.smartString
        self.descriptionLabel.text = L10n.Welcome.text.smartString
        self.linkDeviceButton.setTitle(L10n.Welcome.linkDevice.smartString, for: .normal)
        self.createAccountButton.setTitle(L10n.Welcome.createAccount.smartString, for: .normal)
    }
}
