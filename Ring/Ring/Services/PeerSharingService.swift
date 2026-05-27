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

import RxSwift
import RxRelay
import SwiftyBeaver

// MARK: - Models

enum PeerServicesStatus: Int {
    case success = 0
    case noDevices = 1
    case unreachable = 2
    case timeout = 3
    case internalError = 4

    init(code: Int) {
        self = PeerServicesStatus(rawValue: code) ?? .internalError
    }
}

struct PeerServiceInfo {
    let id: String
    let name: String
    let description: String
    let scheme: String
    let device: String
}

struct PeerTunnelInfo {
    let tunnelId: String
    let accountId: String
    let peerUri: String
    let serviceId: String
    let serviceName: String
    let scheme: String
    let localPort: Int
}

struct PeerTunnelState {
    var activeTunnels: [String: PeerTunnelInfo] = [:]
    var pendingServices: Set<String> = []
}

struct PeerServicesResult {
    let requestId: UInt32
    let accountId: String
    let peerId: String
    let status: PeerServicesStatus
    let services: [PeerServiceInfo]
}

// MARK: - Service

class PeerSharingService {

    private let peerServicesAdapter: PeerServicesAdapter
    private let log = SwiftyBeaver.self

    private let serviceQueue = DispatchQueue(label: "com.jami.PeerSharingService")
    private let peerServicesSubject = PublishSubject<PeerServicesResult>()
    private var tunnelStates = [String: BehaviorRelay<PeerTunnelState>]()
    private let tunnelOpenedSubject = PublishSubject<PeerTunnelInfo>()
    private var pendingOpens = [String: PendingOpen]()

    private struct PendingOpen {
        let accountId: String
        let peerUri: String
        let serviceId: String
        let serviceName: String
        let scheme: String
    }

    init(withPeerServicesAdapter adapter: PeerServicesAdapter) {
        self.peerServicesAdapter = adapter
        PeerServicesAdapter.delegate = self
    }

    // MARK: - Thread-safe dispatch

    /// All daemon callbacks and state mutations go through this helper.
    /// Uses .async only (never .sync) to prevent deadlock when the daemon
    /// fires TunnelOpened synchronously on the same thread that called openServiceTunnel.
    private func onDaemonCallback(_ work: @escaping (PeerSharingService) -> Void) {
        serviceQueue.async { [weak self] in
            guard let self = self else { return }
            work(self)
        }
    }

    // MARK: - Public API

    func queryPeerServices(accountId: String, peerUri: String) -> Observable<PeerServicesResult> {
        return Observable.deferred { [weak self] in
            guard let self = self else { return .empty() }

            let requestId = self.peerServicesAdapter.queryPeerServices(withAccountId: accountId, peerUri: peerUri)
            guard requestId != 0 else {
                return .just(PeerServicesResult(
                    requestId: 0,
                    accountId: accountId,
                    peerId: peerUri,
                    status: .internalError,
                    services: []
                ))
            }

            return self.peerServicesSubject
                .filter { $0.requestId == requestId && $0.accountId == accountId && $0.peerId == peerUri }
                .take(1)
        }
    }

    func openTunnel(accountId: String, peerUri: String, service: PeerServiceInfo) {
        onDaemonCallback { svc in
            let key = svc.stateKey(accountId: accountId, peerUri: peerUri)
            let subject = svc.getOrCreateState(accountId: accountId, peerUri: peerUri)
            var current = subject.value
            current.pendingServices.insert(service.id)
            subject.accept(current)

            let tunnelId = svc.peerServicesAdapter.openServiceTunnel(
                withAccountId: accountId,
                peerUri: peerUri,
                deviceId: service.device,
                serviceId: service.id,
                serviceName: service.name,
                localPort: 0
            ) ?? ""

            if tunnelId.isEmpty {
                var updated = subject.value
                updated.pendingServices.remove(service.id)
                subject.accept(updated)
                if updated.activeTunnels.isEmpty && updated.pendingServices.isEmpty {
                    svc.tunnelStates.removeValue(forKey: key)
                }
            } else {
                svc.pendingOpens[tunnelId] = PendingOpen(
                    accountId: accountId,
                    peerUri: peerUri,
                    serviceId: service.id,
                    serviceName: service.name,
                    scheme: service.scheme
                )
            }
        }
    }

    func closeTunnel(accountId: String, peerUri: String, serviceId: String) {
        onDaemonCallback { svc in
            let key = svc.stateKey(accountId: accountId, peerUri: peerUri)
            guard let tunnelId = svc.tunnelStates[key]?.value.activeTunnels[serviceId]?.tunnelId else { return }
            _ = svc.peerServicesAdapter.closeServiceTunnel(withAccountId: accountId, tunnelId: tunnelId)
        }
    }

    func observeTunnelState(accountId: String, peerUri: String) -> Observable<PeerTunnelState> {
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onCompleted()
                return Disposables.create()
            }
            var disposable: Disposable?
            self.onDaemonCallback { svc in
                let relay = svc.getOrCreateState(accountId: accountId, peerUri: peerUri)
                disposable = relay.asObservable().subscribe(observer)
            }
            return Disposables.create { disposable?.dispose() }
        }
    }

    func observeTunnelUrl(accountId: String, peerUri: String) -> Observable<String> {
        return tunnelOpenedSubject
            .filter { $0.accountId == accountId && $0.peerUri == peerUri }
            .filter { $0.scheme.lowercased() == "http" || $0.scheme.lowercased() == "https" }
            .map { "\($0.scheme.lowercased())://127.0.0.1:\($0.localPort)" }
    }

    func closeAllTunnels() {
        onDaemonCallback { svc in
            for (_, relay) in svc.tunnelStates {
                let state = relay.value
                for (_, tunnelInfo) in state.activeTunnels {
                    _ = svc.peerServicesAdapter.closeServiceTunnel(
                        withAccountId: tunnelInfo.accountId,
                        tunnelId: tunnelInfo.tunnelId
                    )
                }
            }
        }
    }

    // MARK: - Private helpers

    private func stateKey(accountId: String, peerUri: String) -> String {
        return "\(accountId)\0\(peerUri)"
    }

    private func getOrCreateState(accountId: String, peerUri: String) -> BehaviorRelay<PeerTunnelState> {
        let key = stateKey(accountId: accountId, peerUri: peerUri)
        if let existing = tunnelStates[key] {
            return existing
        }
        let relay = BehaviorRelay<PeerTunnelState>(value: PeerTunnelState())
        tunnelStates[key] = relay
        return relay
    }

    private func parseServicesJson(_ json: String) -> [PeerServiceInfo] {
        guard !json.isEmpty,
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { obj in
            guard let id = obj["id"] as? String else { return nil }
            return PeerServiceInfo(
                id: id,
                name: obj["name"] as? String ?? "",
                description: obj["description"] as? String ?? "",
                scheme: obj["scheme"] as? String ?? "",
                device: obj["device"] as? String ?? ""
            )
        }
    }
}

// MARK: - PeerServicesAdapterDelegate

extension PeerSharingService: PeerServicesAdapterDelegate {

    func peerServicesReceived(withRequestId requestId: UInt32,
                              accountId: String,
                              peerId: String,
                              status: Int32,
                              servicesJson: String) {
        let services = parseServicesJson(servicesJson)
        let result = PeerServicesResult(
            requestId: requestId,
            accountId: accountId,
            peerId: peerId,
            status: PeerServicesStatus(code: Int(status)),
            services: services
        )
        onDaemonCallback { svc in
            svc.peerServicesSubject.onNext(result)
        }
    }

    func serviceTunnelOpened(withAccountId accountId: String,
                             tunnelId: String,
                             localPort: UInt16) {
        onDaemonCallback { svc in
            guard let pending = svc.pendingOpens.removeValue(forKey: tunnelId) else {
                svc.log.warning("TunnelOpened with no pending open for tunnelId=\(tunnelId)")
                return
            }

            let key = svc.stateKey(accountId: pending.accountId, peerUri: pending.peerUri)
            guard let subject = svc.tunnelStates[key] else { return }

            let info = PeerTunnelInfo(
                tunnelId: tunnelId,
                accountId: pending.accountId,
                peerUri: pending.peerUri,
                serviceId: pending.serviceId,
                serviceName: pending.serviceName,
                scheme: pending.scheme,
                localPort: Int(localPort)
            )
            var current = subject.value
            current.activeTunnels[pending.serviceId] = info
            current.pendingServices.remove(pending.serviceId)
            subject.accept(current)

            svc.tunnelOpenedSubject.onNext(info)
        }
    }

    func serviceTunnelClosed(withAccountId accountId: String,
                             tunnelId: String,
                             reason: String) {
        onDaemonCallback { svc in
            for (key, relay) in svc.tunnelStates {
                var current = relay.value
                if let serviceId = current.activeTunnels.first(where: { $0.value.tunnelId == tunnelId })?.key {
                    current.activeTunnels.removeValue(forKey: serviceId)
                    relay.accept(current)
                    if current.activeTunnels.isEmpty && current.pendingServices.isEmpty {
                        svc.tunnelStates.removeValue(forKey: key)
                    }
                    return
                }
            }
            if let pending = svc.pendingOpens.removeValue(forKey: tunnelId) {
                let key = svc.stateKey(accountId: pending.accountId, peerUri: pending.peerUri)
                guard let relay = svc.tunnelStates[key] else { return }
                var current = relay.value
                current.pendingServices.remove(pending.serviceId)
                relay.accept(current)
                if current.activeTunnels.isEmpty && current.pendingServices.isEmpty {
                    svc.tunnelStates.removeValue(forKey: key)
                }
            }
        }
    }
}
