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
import RxSwift

struct PresentedPeerService: Identifiable {
    let service: PeerServiceInfo

    var id: String { service.id }
}

class PeerSharingViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var services = [PeerServiceInfo]()
    @Published var activeTunnels = [String: PeerTunnelInfo]()
    @Published var pendingServices = Set<String>()
    @Published var errorMessage: String?
    @Published var presentedBrowseSession: PresentedPeerService?
    /// Loopback URL for the presented session, set once its tunnel is established. Nil while
    /// the viewer is still loading.
    @Published var browseURL: URL?
    /// True when the presented session's tunnel could not be opened — the viewer shows an error.
    @Published var browseFailed = false

    private let accountId: String
    private let peerId: String
    private let peerSharingService: PeerSharingService
    private let disposeBag = DisposeBag()
    private let queryDisposable = SerialDisposable()
    /// Set once the presented session's tunnel has been seen pending, so a later
    /// "neither pending nor active" state is recognized as a failed open (not the initial gap).
    private var sawPendingForBrowse = false

    init(accountId: String, peerId: String, peerSharingService: PeerSharingService) {
        self.accountId = accountId
        self.peerId = peerId
        self.peerSharingService = peerSharingService
        queryDisposable.disposed(by: disposeBag)
        observeTunnelState()
        refresh()
    }

    func refresh() {
        isLoading = true
        errorMessage = nil
        services = []

        // SerialDisposable swaps in the new subscription, disposing the previous query.
        queryDisposable.disposable = peerSharingService.queryPeerServices(accountId: accountId, peerId: peerId)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] result in
                guard let self = self else { return }
                self.isLoading = false
                if result.status == .success {
                    self.services = result.services
                    self.errorMessage = nil
                } else {
                    self.services = []
                    self.errorMessage = self.errorText(for: result.status)
                }
            })
    }

    func openTunnel(_ service: PeerServiceInfo) {
        peerSharingService.openTunnel(accountId: accountId, peerId: peerId, service: service)
    }

    func beginBrowsing(_ service: PeerServiceInfo) {
        guard service.isWebService else { return }

        // Present the viewer immediately in a loading state; the page loads once the tunnel
        // opens (browseURL), or shows an error if it can't (browseFailed).
        presentedBrowseSession = PresentedPeerService(service: service)
        browseURL = nil
        browseFailed = false
        sawPendingForBrowse = false
        openTunnel(service)
    }

    func dismissBrowsingSession() {
        let serviceId = presentedBrowseSession?.service.id
        clearBrowseState()
        if let serviceId = serviceId {
            closeTunnel(serviceId: serviceId)
        }
    }

    func closePeerSession() {
        clearBrowseState()
        peerSharingService.closeAllTunnels(accountId: accountId, peerId: peerId)
    }

    private func clearBrowseState() {
        presentedBrowseSession = nil
        browseURL = nil
        browseFailed = false
        sawPendingForBrowse = false
    }

    func closeTunnel(serviceId: String) {
        peerSharingService.closeTunnel(accountId: accountId, peerId: peerId, serviceId: serviceId)
    }

    private func observeTunnelState() {
        peerSharingService.observeTunnelState(accountId: accountId, peerId: peerId)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                guard let self = self else { return }
                self.activeTunnels = state.activeTunnels
                self.pendingServices = state.pendingServices
                self.dismissOrphanedBrowseSession()
                self.updateBrowseState()
            })
            .disposed(by: disposeBag)
    }

    /// Dismisses an *established* browse session when its backing tunnel disappears externally
    /// (peer disconnect, daemon close, or app-background `closeAllTunnels`), so the WebView
    /// never lingers on a dead loopback URL. Gated on `browseURL != nil` so it does not tear
    /// down the viewer while it is still loading (the tunnel isn't active yet at that point).
    private func dismissOrphanedBrowseSession() {
        guard let session = presentedBrowseSession,
              browseURL != nil,
              activeTunnels[session.service.id] == nil else { return }
        clearBrowseState()
    }

    /// Advances the presented (loading) session: hands it the loopback URL once its tunnel is
    /// established, or flags failure if the open finished without ever becoming active.
    private func updateBrowseState() {
        guard let session = presentedBrowseSession, browseURL == nil, !browseFailed else { return }
        let id = session.service.id

        if let url = activeTunnels[id]?.browsableURL {
            browseURL = url
            return
        }
        if pendingServices.contains(id) {
            sawPendingForBrowse = true   // opening — wait for TunnelOpened
            return
        }
        if activeTunnels[id] != nil {
            // Tunnel is active but loopback URL cannot be built (invalid port/scheme) — won't recover.
            browseFailed = true
            return
        }
        // Neither pending nor active. If we previously saw it pending, the open failed.
        if sawPendingForBrowse {
            browseFailed = true
        }
    }

    private func errorText(for status: PeerServicesStatus) -> String {
        switch status {
        case .noDevices:
            return L10n.PeerServices.errorOffline
        case .unreachable:
            return L10n.PeerServices.errorUnreachable
        case .timeout:
            return L10n.PeerServices.errorTimeout
        default:
            return L10n.PeerServices.errorUnknown
        }
    }
}
