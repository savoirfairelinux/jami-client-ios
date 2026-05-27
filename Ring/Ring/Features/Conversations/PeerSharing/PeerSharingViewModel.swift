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
    let url: URL

    var id: String { service.id }
}

class PeerSharingViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var services = [PeerServiceInfo]()
    @Published var activeTunnels = [String: PeerTunnelInfo]()
    @Published var pendingServices = Set<String>()
    @Published var errorMessage: String?
    @Published var presentedBrowseSession: PresentedPeerService?

    private let accountId: String
    private let peerId: String
    private let peerSharingService: PeerSharingService
    private let disposeBag = DisposeBag()
    private var queryDisposable: Disposable?
    private var pendingPresentationServiceId: String?

    init(accountId: String, peerId: String, peerSharingService: PeerSharingService) {
        self.accountId = accountId
        self.peerId = peerId
        self.peerSharingService = peerSharingService
        observeTunnelState()
        refresh()
    }

    func refresh() {
        isLoading = true
        errorMessage = nil
        services = []

        queryDisposable?.dispose()
        queryDisposable = peerSharingService.queryPeerServices(accountId: accountId, peerId: peerId)
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
                    self.pendingPresentationServiceId = nil
                }
            })
        queryDisposable?.disposed(by: disposeBag)
    }

    func openTunnel(_ service: PeerServiceInfo) {
        peerSharingService.openTunnel(accountId: accountId, peerId: peerId, service: service)
    }

    func beginBrowsing(_ service: PeerServiceInfo) {
        pendingPresentationServiceId = service.id
        openTunnel(service)
    }

    func dismissBrowsingSession() {
        let serviceId = presentedBrowseSession?.service.id
        presentedBrowseSession = nil
        pendingPresentationServiceId = nil
        if let serviceId = serviceId {
            closeTunnel(serviceId: serviceId)
        }
    }

    func closePeerSession() {
        presentedBrowseSession = nil
        pendingPresentationServiceId = nil
        peerSharingService.closeAllTunnels(accountId: accountId, peerId: peerId)
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
                self.tryPresentPendingBrowseSession()
            })
            .disposed(by: disposeBag)

        peerSharingService.observeTunnelUrl(accountId: accountId, peerId: peerId)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.tryPresentPendingBrowseSession()
            })
            .disposed(by: disposeBag)
    }

    private func tryPresentPendingBrowseSession() {
        guard presentedBrowseSession == nil,
              let pendingId = pendingPresentationServiceId,
              activeTunnels[pendingId] != nil,
              let service = services.first(where: { $0.id == pendingId }) else { return }
        presentWebView(for: service)
    }

    private func presentWebView(for service: PeerServiceInfo) {
        guard let tunnel = activeTunnels[service.id],
              let url = tunnel.endpointURL else { return }
        presentedBrowseSession = PresentedPeerService(service: service, url: url)
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
