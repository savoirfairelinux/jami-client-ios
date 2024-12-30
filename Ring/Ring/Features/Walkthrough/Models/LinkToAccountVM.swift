/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import Foundation
import RxSwift
import SwiftUI

class LinkToAccountVM: ObservableObject {
    @Published var pin: String = ""
    @Published var password: String = ""
    @Published var scannedCode: String?
    @Published var animatableScanSwitch: Bool = true
    @Published var notAnimatableScanSwitch: Bool = true
    @Published var showQRCode: Bool = false

    private var tempAccount: String?
    private var accountsService: AccountsService
    private let disposeBag = DisposeBag()
    
    @Published private(set) var uiState: LinkDeviceUIState = .initial

    var linkAction: ((_ pin: String, _ password: String) -> Void)

    var isLinkButtonEnabled: Bool {
        return !pin.isEmpty
    }

    var linkButtonColor: Color {
        return pin.isEmpty ? Color(UIColor.secondaryLabel) : .jamiColor
    }

    init(with injectionBag: InjectionBag, linkAction: @escaping ((_ pin: String, _ password: String) -> Void)) {
        self.linkAction = linkAction
        self.accountsService = injectionBag.accountService
        self.retryConnection()
       // tempAccount = self.accountService.createTemplateAccount()
        setupDeviceAuthObserver()
    }

    func link() {
        linkAction(pin, password)
    }

    func switchToQRCode() {
        withAnimation {
            showQRCode = true
        }
    }

    func switchToPin() {
        withAnimation {
            showQRCode = false
        }
    }

    func didScanQRCode(_ code: String) {
        self.pin = code
        self.scannedCode = code
    }

    private func setupDeviceAuthObserver() {
        accountsService.authStateSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] result in
                self?.updateDeviceAuthState(result: result)
            })
            .disposed(by: disposeBag)
    }

    private func updateDeviceAuthState(result: AuthResult) {
        switch result.state {
            case .initializing:
                self.onInitSignal()
            case .tokenAvailable:
                self.onTokenAvailableSignal(details: result.details)
            case .connecting:
                self.onConnectingSignal()
            case .authenticating:
                self.onAuthenticatingSignal(details: result.details)
            case .inProgress:
                self.onInProgressSignal()
            case .done:
                self.onDoneSignal(details: result.details)
        }
    }
    
    private func onInitSignal() {
        uiState = .awaitingPin
    }
    
    private func onTokenAvailableSignal(details: [String: String]) {
        if let pin = details["token"] {
            self.pin = pin
            uiState = .displayingPin(pin: pin)
        }
    }
    
    private func onConnectingSignal() {
        uiState = .connecting
    }
    
    private func onAuthenticatingSignal(details: [String: String]) {
        uiState = .authenticating
    }
    
    private func onInProgressSignal() {
        uiState = .inProgress
    }
    
    private func onDoneSignal(details: [String: String]) {
        uiState = .success
    }

    func retryConnection() {
        // Reset the state
        uiState = .initial
        // Attempt to recreate the temporary account and restart the process
        Task {
            tempAccount = try await accountsService.createTemplateAccount()
        }
    }
}

// Define UI states
enum LinkDeviceUIState {
    case initial
    case awaitingPin
    case displayingPin(pin: String)
    case connecting
    case authenticating
    case inProgress
    case success
    case error(message: String)
}


enum QRCodeGenerator {
    static func generateQRCode(from string: String) -> UIImage? {
        // Convert string to data
        let data = string.data(using: String.Encoding.ascii)

        // Create QR code filter
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("H", forKey: "inputCorrectionLevel") // H = High error correction

        // Get output image
        guard let qrImage = qrFilter.outputImage else { return nil }

        // Scale the image
        let scale = UIScreen.main.scale
        let transform = CGAffineTransform(scaleX: 10 * scale, y: 10 * scale)
        let scaledQrImage = qrImage.transformed(by: transform)

        // Convert to CGImage using shared context for better performance
        let context = CIContext.shared
        guard let cgImage = context.createCGImage(scaledQrImage, from: scaledQrImage.extent) else { return nil }

        // Create final UIImage with proper scale
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

// Shared CIContext for better performance
extension CIContext {
    static let shared: CIContext = {
        let options = [CIContextOption.useSoftwareRenderer: false]
        return CIContext(options: options)
    }()
}
