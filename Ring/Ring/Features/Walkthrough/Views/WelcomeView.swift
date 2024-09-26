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

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: WelcomeVM
    @SwiftUI.State var showImportOptions = false
    @SwiftUI.State var showAdvancedOptions = false

    init(injectionBag: InjectionBag) {
        _viewModel = ObservedObject(wrappedValue:
                                        WelcomeVM(with: injectionBag))
    }

    @Environment(\.verticalSizeClass)
    var verticalSizeClass

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Group {
                    if verticalSizeClass == .compact {
                        HorizontalView(showImportOptions: $showImportOptions,
                                       showAdvancedOptions: $showAdvancedOptions,
                                       model: viewModel)
                    } else {
                        PortraitView(showImportOptions: $showImportOptions,
                                     showAdvancedOptions: $showAdvancedOptions,
                                     model: viewModel)
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
    }

    @ViewBuilder
    func alertView() -> some View {
        switch viewModel.creationState {
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
        CustomAlert(content: { AlertFactory
            .alertWithOkButton(title: error.title,
                               message: error.message,
                               action: { [weak viewModel] in
                                guard let viewModel = viewModel else { return }
                                viewModel.creationState = .initial
                               })
        })
    }

    @ViewBuilder
    func registrationErrorAlert() -> some View {
        let title = L10n.CreateAccount.usernameNotRegisteredTitle
        let message = L10n.CreateAccount.usernameNotRegisteredMessage
        CustomAlert(content: { AlertFactory
            .alertWithOkButton(title: title,
                               message: message,
                               action: {[weak viewModel] in
                                guard let viewModel = viewModel else { return }
                                viewModel.finish()
                               })
        })
    }

    @ViewBuilder
    func timeOutAlert() -> some View {
        let title = L10n.CreateAccount.timeoutTitle
        let message = L10n.CreateAccount.timeoutMessage
        CustomAlert(content: { AlertFactory
            .alertWithOkButton(title: title,
                               message: message,
                               action: {[weak viewModel] in
                                guard let viewModel = viewModel else { return }
                                viewModel.finish()
                               })
        })
    }

    @ViewBuilder
    func loadingView() -> some View {
        CustomAlert(content: { AlertFactory.createLoadingView() })
    }

    @ViewBuilder
    func cancelButton() -> some View {
        if viewModel.notCancelable {
            EmptyView()
        } else {
            Button(action: { [weak viewModel] in
                guard let viewModel = viewModel else { return }
                viewModel.finish()
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
    var model: WelcomeVM
    @SwiftUI.State private var height: CGFloat = 1
    var body: some View {
        HStack(spacing: 30) {
            VStack {
                Spacer()
                HeaderView()
                AboutButton(model: model)
                Spacer()
            }
            VStack {
                Spacer()
                ScrollView(showsIndicators: false) {
                    ButtonsView(showImportOptions: $showImportOptions,
                                showAdvancedOptions: $showAdvancedOptions,
                                model: model)
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
    var model: WelcomeVM
    var body: some View {
        VStack {
            Spacer(minLength: 80)
            HeaderView()
            ScrollView(showsIndicators: false) {
                ButtonsView(showImportOptions: $showImportOptions,
                            showAdvancedOptions: $showAdvancedOptions,
                            model: model)
            }
            AboutButton(model: model)
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
    var model: WelcomeVM

    var body: some View {
        VStack(spacing: 12) {
            button(L10n.CreateAccount.createAccountFormTitle,
                   action: {
                    model.openAccountCreation()
                   })
                .accessibilityIdentifier(AccessibilityIdentifiers.joinJamiButton)

            button(L10n.Welcome.haveAccount, action: {
                withAnimation {
                    showImportOptions.toggle()
                }
            })

            if showImportOptions {
                expandedbutton(L10n.Welcome.linkDevice, action: {
                    model.openLinkDevice()
                })
                expandedbutton(L10n.Welcome.linkBackup, action: {
                    model.openImportArchive()
                })
            }

            advancedButton(L10n.Account.advancedFeatures, action: {
                withAnimation {
                    showAdvancedOptions.toggle()
                }
            })

            if showAdvancedOptions {
                expandedbutton(L10n.Welcome.connectToJAMS, action: {
                    model.openJAMS()
                })
                expandedbutton(L10n.Account.createSipAccount, action: {
                    model.openSIP()
                })
            }
        }
        .transition(AnyTransition.move(edge: .top))
    }

    private func button(_ title: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(12)
                .frame(maxWidth: 500)
                .background(Color(UIColor.jamiButtonDark))
                .foregroundColor(Color(UIColor.systemBackground))
                .cornerRadius(12)
        }
    }

    private func expandedbutton(_ title: String,
                                action: @escaping () -> Void) -> some View {
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

    private func advancedButton(_ title: String,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(12)
                .frame(maxWidth: 500)
                .foregroundColor(Color.jamiColor)
        }
    }
}

struct AboutButton: View {
    var model: WelcomeVM
    var body: some View {
        Button(action: {
            model.openAboutJami()
        }, label: {
            Text(L10n.Smartlist.aboutJami)
                .padding(12)
                .foregroundColor(.jamiColor)
        })
    }
}

extension View {
    func applyJamiBackground() -> some View {
        self.background(
            Image("background_login")
                .resizable()
                .ignoresSafeArea()
                .scaledToFill()
                .accessibilityIdentifier(AccessibilityIdentifiers.welcomeWindow)
        )
    }
}
