//
//  LogViewController.swift
//  Ring
//
//  Created by kateryna on 2023-01-17.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import SwiftyBeaver
import Reusable
import SwiftUI

class LogViewController: UIViewController, ViewModelBased, StoryboardBased {
    var viewModel: LogViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureRingNavigationBar()
        let logMonitorView = LogUI()
        let swiftUIView = UIHostingController(rootView: logMonitorView)
        addChild(swiftUIView)
        swiftUIView.view.frame = self.view.frame
        self.view.addSubview(swiftUIView.view)
        swiftUIView.view.translatesAutoresizingMaskIntoConstraints = false
        swiftUIView.view.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
        swiftUIView.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
        swiftUIView.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 0).isActive = true
        swiftUIView.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: 0).isActive = true
        swiftUIView.didMove(toParent: self)
        self.view.backgroundColor = UIColor.systemBackground
        self.view.sendSubviewToBack(swiftUIView.view)
    }
}
