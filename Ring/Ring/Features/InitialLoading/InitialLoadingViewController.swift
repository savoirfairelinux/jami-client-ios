//
//  InitialLoadingViewController.swift
//  Ring
//
//  Created by Romain Bertozzi on 17-11-13.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import UIKit
import Reusable

final class InitialLoadingViewController: UIViewController, StoryboardBased {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.jamiBackgroundColor
    }

}
