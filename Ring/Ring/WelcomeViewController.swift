//
//  WelcomeViewController.swift
//  Ring
//
//  Created by Silbino Goncalves Matado on 17-03-17.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

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
        self.welcomeLabel.text = NSLocalizedString("WelcomeTitle", comment: "")
        self.descriptionLabel.text = NSLocalizedString("WelcomeText", comment: "")
        self.linkDeviceButton.setTitle(NSLocalizedString("LinkDeviceButton", comment: ""), for: .normal)
        self.createAccountButton.setTitle(NSLocalizedString("CreateAccount", comment: ""), for: .normal)
    }

}
