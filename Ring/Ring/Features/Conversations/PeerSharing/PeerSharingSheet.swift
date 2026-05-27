/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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
import WebKit

// MARK: - Main Sheet

struct PeerSharingSheet: View {
    @ObservedObject var viewModel: PeerSharingViewModel

    var body: some View {
        NavigationView {
            content
                .navigationTitle(L10n.PeerServices.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: viewModel.refresh) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel(L10n.PeerServices.refresh)
                    }
                }
        }
        .fullScreenCover(item: browseSessionBinding) { _ in
            PeerServiceBrowser(viewModel: viewModel, onDone: viewModel.dismissBrowsingSession)
        }
    }

    private var browseSessionBinding: Binding<PresentedPeerService?> {
        Binding(
            get: { viewModel.presentedBrowseSession },
            set: { newValue in
                if newValue == nil {
                    viewModel.dismissBrowsingSession()
                }
            }
        )
    }

    @ViewBuilder private var content: some View {
        if viewModel.isLoading {
            loadingView
        } else if let error = viewModel.errorMessage {
            statusView(text: error, isError: true)
        } else if viewModel.services.isEmpty {
            statusView(text: L10n.PeerServices.empty)
        } else {
            servicesList
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func statusView(text: String, isError: Bool = false) -> some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundColor(isError ? Color.jamiFailure : Color(UIColor.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var servicesList: some View {
        List(viewModel.services, id: \.id) { service in
            serviceRow(service)
        }
        .listStyle(PlainListStyle())
    }

    // MARK: - Service Row
    //
    // Currently only Web services are supported.
    //
    // TODO: support a specific protocol (e.g. SSH or VNC) by adding an in-app client for it
    // that connects to the loopback endpoint while Jami stays foreground.

    private func serviceRow(_ service: PeerServiceInfo) -> some View {
        let isSupported = service.isWebService

        return Button {
            viewModel.beginBrowsing(service)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .foregroundColor(isSupported ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                        .lineLimit(1)
                    if !service.description.isEmpty {
                        Text(service.description)
                            .font(.footnote)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSupported {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .accessibilityHidden(true)
                } else {
                    Text(L10n.PeerServices.notSupported)
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(!isSupported)
        .accessibilityLabel(accessibilityText(for: service))
        .accessibilityHint(isSupported ? L10n.PeerServices.open : L10n.PeerServices.notSupported)
    }

    // MARK: - Helpers

    private func accessibilityText(for service: PeerServiceInfo) -> String {
        let description = service.description.isEmpty ? service.name : "\(service.name), \(service.description)"
        return service.isWebService ? description : "\(description), \(L10n.PeerServices.notSupported)"
    }
}

// MARK: - WKWebView Wrapper
//
// The loopback tunnel (127.0.0.1:<port>) only works while the app is foreground —
// backgrounding suspends the process and the loopback stops answering. The viewer must
// therefore stay in-app; external Safari and SFSafariViewController would background the
// app and break the page.
//
// Limitations vs SFSafariViewController: no Safari Reader, no built-in page Translate,
// and we maintain the chrome + origin pinning ourselves.
//
// Done dismisses the viewer and closes the tunnel (browse-scoped session).
struct PeerServiceBrowser: View {
    @ObservedObject var viewModel: PeerSharingViewModel
    let onDone: () -> Void

    var body: some View {
        NavigationView {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L10n.PeerServices.done, action: onDone)
                    }
                }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.browseFailed {
            Text(L10n.PeerServices.errorUnreachable)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        } else if let url = viewModel.browseURL {
            WebViewRepresentable(url: url)
        } else {
            ProgressView()
        }
    }

    // Show the real loopback origin (host:port) as the title once loaded — never the
    // peer-supplied service name. Empty while loading or on error.
    private var title: String {
        guard let url = viewModel.browseURL, let host = url.host else { return "" }
        if let port = url.port { return "\(host):\(port)" }
        return host
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(allowedScheme: url.scheme, allowedHost: url.host, allowedPort: url.port)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // Pin every navigation to the exact loopback tunnel origin (scheme + host +
    // port). The viewer has no address bar, so without this a peer-served page
    // could redirect to an external site
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let allowedScheme: String?
        private let allowedHost: String?
        private let allowedPort: Int?

        init(allowedScheme: String?, allowedHost: String?, allowedPort: Int?) {
            self.allowedScheme = allowedScheme?.lowercased()
            self.allowedHost = allowedHost
            self.allowedPort = allowedPort
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            let scheme = url?.scheme?.lowercased()
            let isPinned = scheme == allowedScheme
                && url?.host == allowedHost
                && url?.port == allowedPort
            decisionHandler(isPinned ? .allow : .cancel)
        }
    }
}
