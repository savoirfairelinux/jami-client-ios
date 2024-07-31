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
    case aboutJami

    var id: Int {
        hashValue
    }
}

struct WelcomeView: View {
    @ObservedObject var model: WelcomeViewModel
    @SwiftUI.State var showImportOptions = false
    @SwiftUI.State var showAdvancedOptions = false
    @SwiftUI.State var activeView: ActiveView?

    @Environment(\.verticalSizeClass)
    var verticalSizeClass

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Group {
                    if verticalSizeClass == .compact {
                        HorizontalView(showImportOptions: $showImportOptions, showAdvancedOptions: $showAdvancedOptions, activeView: $activeView)
                    } else {
                        PortraitView(showImportOptions: $showImportOptions, showAdvancedOptions: $showAdvancedOptions, activeView: $activeView)
                    }
                }
                .padding()
                alertView()
                    .ignoresSafeArea()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                cancelButton()
                Spacer()
            }
            .padding()
        }
        .applyJamiBackground()
        .sheet(item: $activeView) { item in
            switch item {
                case .jamiAccount:
                    CreateAccountView(injectionBag: model.injectionBag, dismissAction: {
                        activeView = nil
                    }, createAction: { name in
                        activeView = nil
                        self.model.createAccount(name: name)
                    })
                case .linkDevice:
                    LinkToAccountView {
                        activeView = nil
                    }
                case .jamsAccount:
                    LinkToAccountView {
                        activeView = nil
                    }
                case .sipAccount:
                    LinkToAccountView {
                        activeView = nil
                    }
                case .aboutJami:
                    AboutSwiftUIView()
            }
        }
    }

    @ViewBuilder
    func alertView() -> some View {
        switch model.creationState {
            case .initial, .unknown, .success:
                EmptyView()
            case .started:
                loadingView()
            case .timeOut:
                timeOutAlert()
            case .nameNotRegistered:
                registrationErrorAlert()
            case .error(let error):
                accountCreationErrorAlert(error: error)
        }
    }

    @ViewBuilder
    func accountCreationErrorAlert(error: AccountCreationError) -> some View {
        CustomAlert(content: { AlertFactory.createAlertViewWithOkButton(title: error.title, message: error.message, action: { model.creationState = .initial }) })
    }

    @ViewBuilder
    func registrationErrorAlert() -> some View {
        CustomAlert(content: { AlertFactory.createAlertViewWithOkButton(title: L10n.CreateAccount.usernameNotRegisteredTitle, message: L10n.CreateAccount.usernameNotRegisteredMessage, action: { model.finish() }) })
    }

    @ViewBuilder
    func timeOutAlert() -> some View {
        CustomAlert(content: { AlertFactory.createAlertViewWithOkButton(title: L10n.CreateAccount.timeoutTitle, message: L10n.CreateAccount.timeoutMessage, action: { model.finish() }) })
    }

    @ViewBuilder
    func loadingView() -> some View {
        CustomAlert(content: { AlertFactory.createLoadingView() })
    }

    @ViewBuilder
    func cancelButton() -> some View {
        if model.notCancelable {
            EmptyView()
        } else {
            Button(action: {
                model.cancelWalkthrough()
            }, label: {
                Text(L10n.Global.cancel)
                    .foregroundColor(Color.jamiColor)
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
                AboutButton(activeView: $activeView)
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
                .frame(height: height + 10)
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
            Spacer(minLength: 80)
            HeaderView()
            ScrollView(showsIndicators: false) {
                ButtonsView(showImportOptions: $showImportOptions, showAdvancedOptions: $showAdvancedOptions, activeView: $activeView)
            }
            AboutButton(activeView: $activeView)
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
            Text(L10n.Welcome.title)
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
        VStack(spacing: 12) {
            button(L10n.CreateAccount.createAccountFormTitle, action: {
                withAnimation {
                    activeView = .jamiAccount
                }
            })
            .accessibilityIdentifier(AccessibilityIdentifiers.joinJamiButton)

            button(L10n.Welcome.haveAccount, action: {
                withAnimation {
                    showImportOptions.toggle()
                }
            })

            if showImportOptions {
                expandedbutton(L10n.Welcome.linkDevice, action: {
                    withAnimation {
                        activeView = .linkDevice
                    }
                })
            }

            advancedButton(L10n.Account.advancedFeatures, action: {
                withAnimation {
                    showAdvancedOptions.toggle()
                }
            })

            if showAdvancedOptions {
                expandedbutton(L10n.Welcome.connectToManager, action: {})
                expandedbutton(L10n.Account.createSipAccount, action: {})
            }
        }
        .transition(AnyTransition.move(edge: .top))
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(12)
                .frame(maxWidth: 500)
                .background(Color(UIColor.jamiButtonDark))
                .foregroundColor(Color(UIColor.systemBackground))
                .cornerRadius(12)
        }
    }

    private func expandedbutton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(12)
                .frame(maxWidth: 500)
                .background(Color(UIColor.jamiButtonWithOpacity))
                .foregroundColor(Color(UIColor.jamiButtonDark))
                .frame(maxWidth: 500)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .inset(by: 1)
                        .stroke(Color(UIColor.jamiButtonDark), lineWidth: 1)
                )
        }
    }

    private func advancedButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(12)
                .frame(maxWidth: 500)
                .foregroundColor(Color.jamiColor)
        }
    }
}

struct AboutButton: View {
    @Binding var activeView: ActiveView?
    var body: some View {
        Button(action: {
            withAnimation {
                activeView = .aboutJami
            }
        }) {
            Text(L10n.Smartlist.aboutJami)
                .padding(12)
                .foregroundColor(.jamiColor)
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

struct AlertFactory {
    static func createAlertViewWithOkButton(title: String, message: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            Text(message)
            HStack {
                Spacer()
                Button(action: action, label: {
                    Text(L10n.Global.ok)
                        .foregroundColor(.jamiColor)
                        .padding(.horizontal)
                })
            }
        }
    }

    static func createLoadingView() -> some View {
        VStack(spacing: 20) {
            Text("Creating account")
            SwiftUI.ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(2)
                .padding(.bottom, 30)
        }
    }
}
