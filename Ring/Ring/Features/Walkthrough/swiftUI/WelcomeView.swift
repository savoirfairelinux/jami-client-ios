//
//  SwiftUIView.swift
//  Ring
//
//  Created by kateryna on 2024-07-29.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

enum ActiveView: Identifiable {
    case jamiAccount
    case linkDevice
    case jamsAccount
    case sipAccount

    var id: Int {
        hashValue
    }
}

struct WelcomeView: View {
    var model: WelcomeViewModel
    @SwiftUI.State var showImportOptions = false
    @SwiftUI.State var showAdvancedOptions = false
    @SwiftUI.State var activeView: ActiveView?

    @Environment(\.verticalSizeClass)
    var verticalSizeClass

    var body: some View {
        NavigationView {
            Group {
                if verticalSizeClass == .compact {
                    HorizontalView(showImportOptions: $showImportOptions, showAdvancedOptions: $showAdvancedOptions, activeView: $activeView)
                } else {
                    PortraitView(showImportOptions: $showImportOptions, showAdvancedOptions: $showAdvancedOptions, activeView: $activeView)
                }
            }
            .navigationBarItems(
                leading: navigationItem()
            )
            .navigationBarTitleDisplayMode(.inline)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)
            .applyJamiBackground()
            .sheet(item: $activeView) { item in
                switch item {
                case .jamiAccount:
                    JoinJamiView {
                        activeView = nil
                    }
                case .linkDevice:
                    LinkNewDevice {
                        activeView = nil
                    }
                case .jamsAccount:
                    LinkNewDevice {
                        activeView = nil
                    }
                case .sipAccount:
                    LinkNewDevice {
                        activeView = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    func navigationItem() -> some View {
        if model.notCancelable {
            EmptyView()
        } else {
            Button(action: {
                model.cancelWalkthrough()
            }, label: {
                Text("Cancel")
                    .foregroundColor(Color(UIColor.label))
            })
        }
    }
}
struct HorizontalView: View {
    @Binding var showImportOptions: Bool
    @Binding var showAdvancedOptions: Bool
    @Binding var activeView: ActiveView?
    @SwiftUI.State private var height: CGFloat = 1
    var body: some View {
        HStack(spacing: 30) {
            VStack {
                Spacer()
                HeaderView()
                AboutButton()
                Spacer()
            }
            VStack {
                Spacer()
                ScrollView(showsIndicators: false) {
                    ButtonsView(showImportOptions: $showImportOptions, showAdvancedOptions: $showAdvancedOptions, activeView: $activeView)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .onChange(of: [showAdvancedOptions, showImportOptions]) { _ in
                                        height = proxy.size.height
                                    }
                                    .onAppear {
                                        height = proxy.size.height
                                    }
                            }
                        )
                }
                .frame(height: height)
                Spacer()
            }
        }
    }
}

struct PortraitView: View {
    @Binding var showImportOptions: Bool
    @Binding var showAdvancedOptions: Bool
    @Binding var activeView: ActiveView?
    var body: some View {
        VStack {
            ScrollView(showsIndicators: false) {
                Spacer(minLength: 50)
                HeaderView()
                ButtonsView(showImportOptions: $showImportOptions, showAdvancedOptions: $showAdvancedOptions, activeView: $activeView)
            }
            AboutButton()
        }
    }
}

struct HeaderView: View {
    var body: some View {
        VStack {
            Image("jami_gnupackage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
            Text("Share freely and privately with Jami")
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
                .padding(.bottom, 30)
                .padding(.top, 20)
        }
    }
}

struct ButtonsView: View {
    @Binding var showImportOptions: Bool
    @Binding var showAdvancedOptions: Bool
    @Binding var activeView: ActiveView?

    var body: some View {
        VStack(spacing: 15) {
            button("Join Jami", action: {
                withAnimation {
                    activeView = .jamiAccount
                }
            })

            button("I already have an account", action: {
                withAnimation {
                    showImportOptions.toggle()
                }
            })

            if showImportOptions {
                button("Import from another device", action: {
                    withAnimation {
                        activeView = .linkDevice
                    }
                })
            }

            advancedButton("Advanced Features", action: {
                withAnimation {
                    showAdvancedOptions.toggle()
                }
            })

            if showAdvancedOptions {
                button("Connect to Jami Account Manager Server", action: {})
                button("Configure a SIP Account", action: {})
            }
        }
        .transition(AnyTransition.move(edge: .top))
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(12)
                .frame(maxWidth: 500)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }

    private func advancedButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(12)
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
        }
    }
}

struct AboutButton: View {
    var body: some View {
        Button(action: {}) {
            Text("About Jami")
                .padding(12)
                .foregroundColor(.blue)
        }
    }
}

extension View {
    func applyJamiBackground() -> some View {
        self.background(
            Image("background_login")
                .resizable()
                .ignoresSafeArea()
                .scaledToFill()
        )
    }
}

struct JoinJamiView: View {
    @StateObject var model: CreateAccountViewModel

    init(injectionBag: InjectionBag) {
        _model = StateObject(wrappedValue:
                                CreateAccountViewModel(with: injectionBag))
    }
    @SwiftUI.State private var isTextFieldFocused = false
    @SwiftUI.State var name: String = ""
    let dismissAction: () -> Void
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(footer: footerView()) {
                        FocusableTextField(text: $name, isFirstResponder: $isTextFieldFocused, placeholder: "Choose username")
                    }
                }
                Spacer()
            }
            .onAppear {
                // Delay focusing the text field to ensure the view is fully loaded and visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isTextFieldFocused = true
                }
            }
            .onChange(of: name) { _ in
                model.nameUpdated(name: name)
            }
            .navigationBarTitle("Join Jami", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    dismissAction()
                }, label: {
                    Text("Cancel")
                        .foregroundColor(Color(UIColor.label))
                }),
                trailing: Button(action: {
                    model.createAccount()
                    //                    model.updateProfile()
                    //                    isPresented = false
                }, label: {
                    Text("Join")
                        .foregroundColor(Color(UIColor.label))
                })
            )
        }
    }

    func footerView() -> some View {
        return Text(model.nameRegistrationStatus)
            .foregroundColor(model.nameRegistrationStatusColor)
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRCodeScannerView

        init(parent: QRCodeScannerView) {
            self.parent = parent
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                parent.didFindCode(stringValue)
            }
        }
    }

    var didFindCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return viewController }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return viewController
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            return viewController
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
            metadataOutput.rectOfInterest = CGRect(x: 0, y: 0, width: 300, height: 300)
        } else {
            return viewController
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.cornerRadius = 20
        viewController.view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct LinkNewDevice: View {
    let dismissAction: () -> Void
    @SwiftUI.State var value: String = ""
    @SwiftUI.State private var scannedCode: String?
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    Text("A PIN is requered to use an existing Jami account on this device")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    HStack {
                        Text("Provided PIN:")
                        if let scannedCode = scannedCode {
                            Text(scannedCode)
                        }
                    }
                    .padding()
                    if let scannedCode = scannedCode {
                        Text("Rescan qrCode")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.blue)
                            .cornerRadius(12)
                    } else {
                        VStack {
                            Text("Scan qrCode")
                            ZStack {
                                QRCodeScannerView {
                                    self.scannedCode = $0
                                }
                                .frame(width: 300, height: 300)
                                .cornerRadius(20)
                                QRCodeScannerOverlayView()
                                    .frame(width: 300, height: 300)
                            }
                        }
                    }

                    Text("Or enter pin manually")
                        .padding(.top)

                    TextField("Enter PIN", text: $value)
                        .padding(.horizontal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("Fill if the account password encrypted")
                        .padding(.top)
                    TextField("Enter password", text: $value)
                        .padding(.horizontal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Spacer()
            }
            .ignoresSafeArea()
            .background(Color(UIColor.secondarySystemBackground))
            .navigationBarTitle("Link device", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    dismissAction()
                }, label: {
                    Text("Cancel")
                        .foregroundColor(Color(UIColor.label))
                }),
                trailing: Button(action: {
                    //                    model.updateProfile()
                    //                    isPresented = false
                }, label: {
                    Text("Import")
                        .foregroundColor(Color(UIColor.label))
                })
            )
        }
    }
}

struct QRCodeScannerOverlayView: View {
    var body: some View {
        GeometryReader { geometry in
            let frameSize: CGFloat = 150
            let cornerLength: CGFloat = 20
            let lineWidth: CGFloat = 4

            let rect = CGRect(
                x: (geometry.size.width - frameSize) / 2,
                y: (geometry.size.height - frameSize) / 2,
                width: frameSize,
                height: frameSize
            )

            Path { path in
                // Top-left corner
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

                // Top-right corner
                path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

                // Bottom-left corner
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))

                // Bottom-right corner
                path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
            }
            .stroke(Color.white, lineWidth: lineWidth)
        }
        .background(Color.clear)
    }
}
