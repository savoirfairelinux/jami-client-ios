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
    @SwiftUI.State private var showCopiedToast = false
    @SwiftUI.State private var copiedToastDismissWorkItem: DispatchWorkItem?

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
        .fullScreenCover(item: browseSessionBinding) { session in
            PeerServiceWebView(
                url: session.url,
                onDone: viewModel.dismissBrowsingSession
            )
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
            statusView(text: error)
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

    private func statusView(text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundColor(.secondary)
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
        .overlay(
            Group {
                if showCopiedToast {
                    copiedToastView
                }
            },
            alignment: .bottom
        )
    }

    // MARK: - Service Row

    private enum RowState {
        case idle, connecting, connected
    }

    private func rowState(for service: PeerServiceInfo) -> RowState {
        if viewModel.pendingServices.contains(service.id) { return .connecting }
        if viewModel.activeTunnels[service.id] != nil { return .connected }
        return .idle
    }

    @ViewBuilder
    private func serviceRow(_ service: PeerServiceInfo) -> some View {
        let state = rowState(for: service)

        HStack(spacing: 12) {
            Button {
                handleTap(service: service, state: state)
            } label: {
                HStack(spacing: 12) {
                    leadingIcon(state: state)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.name)
                            .foregroundColor(.primary)
                        Text(rowSubtitle(service: service, state: state))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
                .opacity(state == .connecting ? 0.6 : 1.0)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(state == .connecting)
            .accessibilityLabel(accessibilityText(service: service, state: state))
            .accessibilityHint(accessibilityHint(service: service, state: state))

            trailingAccessory(service: service, state: state)
        }
    }

    @ViewBuilder
    private func leadingIcon(state: RowState) -> some View {
        switch state {
        case .connecting:
            ProgressView()
                .frame(width: 24, height: 24)
        case .connected:
            Image(systemName: "network")
                .foregroundColor(.accentColor)
                .frame(width: 24)
        case .idle:
            Image(systemName: "network")
                .foregroundColor(.secondary)
                .frame(width: 24)
        }
    }

    @ViewBuilder
    private func trailingAccessory(service: PeerServiceInfo, state: RowState) -> some View {
        if !service.isWebService {
            switch state {
            case .idle:
                Text(L10n.PeerServices.connect)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            case .connected:
                Button(L10n.PeerServices.disconnect) {
                    viewModel.closeTunnel(serviceId: service.id)
                }
                .buttonStyle(BorderlessButtonStyle())
                .font(.caption)
                .foregroundColor(.accentColor)
            case .connecting:
                EmptyView()
            }
        }
    }

    // MARK: - Helpers

    private func rowSubtitle(service: PeerServiceInfo, state: RowState) -> String {
        switch state {
        case .connecting:
            return L10n.PeerServices.connecting
        case .connected:
            // Non-web: show the copyable loopback endpoint. Web has no copyable endpoint.
            if let endpoint = viewModel.activeTunnels[service.id]?.loopbackURL?.absoluteString {
                return endpoint
            }
            return service.description.isEmpty ? service.scheme : service.description
        case .idle:
            return service.description.isEmpty ? service.scheme : service.description
        }
    }

    private func handleTap(service: PeerServiceInfo, state: RowState) {
        guard state != .connecting else { return }

        if service.isWebService {
            viewModel.beginBrowsing(service)
            return
        }

        switch state {
        case .connected:
            if let tunnel = viewModel.activeTunnels[service.id] {
                copyEndpoint(tunnel: tunnel)
            }
        case .idle:
            viewModel.openTunnel(service)
        case .connecting:
            break
        }
    }

    private func copyEndpoint(tunnel: PeerTunnelInfo) {
        guard let endpoint = tunnel.loopbackURL?.absoluteString else { return }
        UIPasteboard.general.string = endpoint

        copiedToastDismissWorkItem?.cancel()
        withAnimation { showCopiedToast = true }

        let dismissWorkItem = DispatchWorkItem {
            withAnimation { showCopiedToast = false }
        }
        copiedToastDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: dismissWorkItem)
    }

    private func accessibilityText(service: PeerServiceInfo, state: RowState) -> String {
        switch state {
        case .idle where service.description.isEmpty:
            return service.name
        default:
            return "\(service.name), \(rowSubtitle(service: service, state: state))"
        }
    }

    private func accessibilityHint(service: PeerServiceInfo, state: RowState) -> String {
        switch state {
        case .connecting:
            return L10n.PeerServices.connecting
        case .connected:
            return service.isWebService ? openServiceHint : L10n.Global.copy
        case .idle:
            return service.isWebService ? openServiceHint : L10n.PeerServices.connect
        }
    }

    private var openServiceHint: String {
        NSLocalizedString(
            "peerServices.open",
            tableName: nil,
            bundle: .main,
            value: "Open",
            comment: "Accessibility hint for opening a shared web service"
        )
    }

    private var copiedToastView: some View {
        Text(L10n.PeerServices.linkCopied)
            .font(.footnote)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(8)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - WKWebView Wrapper
//
// Peer HTTP services load through a daemon loopback tunnel. We use in-app WKWebView
// instead of SFSafariViewController or external Safari because:
// - SFSafariViewController exposes "Open in Safari"; leaving Jami backgrounds the app and
//   closes all tunnels, so the page breaks.
// - External Safari has the same problem
// - WKWebView keeps the user in-app with no escape hatch, so the tunnel stays alive while
//   the page is shown.
// Done dismisses the viewer and closes the tunnel (browse-scoped session).

struct PeerServiceWebView: View {
    let url: URL
    let onDone: () -> Void

    // Show the real loopback origin (host:port) as the title — never the
    // peer-supplied service name.
    private var originLabel: String {
        guard let host = url.host else { return url.absoluteString }
        if let port = url.port { return "\(host):\(port)" }
        return host
    }

    var body: some View {
        NavigationView {
            WebViewRepresentable(url: url)
                .navigationTitle(originLabel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L10n.PeerServices.done, action: onDone)
                    }
                }
        }
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
