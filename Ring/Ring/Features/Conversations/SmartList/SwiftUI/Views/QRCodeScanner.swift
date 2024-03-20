//
//  QRCodeScanner.swift
//  Ring
//
//  Created by kateryna on 2024-04-28.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI
import AVFoundation

struct ScanView: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    let injectionBag: InjectionBag
    typealias UIViewControllerType = ScanViewController

    func makeUIViewController(context: Context) -> ScanViewController {
        let viewController = ScanViewController.instantiate(with: self.injectionBag)
        viewController.onCodeScanned = onCodeScanned
        return viewController
    }

    func updateUIViewController(_ uiViewController: ScanViewController, context: Context) {
    }

    static func dismantleUIViewController(_ uiViewController: ScanViewController, coordinator: ()) {
    }
}

