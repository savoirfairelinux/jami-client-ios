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

import Foundation
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
    let peerId: String
    let serviceId: String
    let serviceName: String
    let scheme: String
    let localPort: Int
}

private enum PeerTunnelEndpoint {
    static let loopbackHost = "127.0.0.1"
    static let webSchemes: Set<String> = ["http", "https"]

    static func normalizedScheme(_ scheme: String) -> String? {
        let normalized = scheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    static func isWebScheme(_ scheme: String) -> Bool {
        guard let normalized = normalizedScheme(scheme) else { return false }
        return webSchemes.contains(normalized)
    }

    /// RFC 3986 scheme charset: `ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`, ASCII only.
    /// The scheme is peer-supplied; rejecting invalid values prevents a crash, because the
    /// `URLComponents.scheme` setter raises an exception on illegal characters.
    static func isValidScheme(_ scheme: String) -> Bool {
        guard let first = scheme.first, first.isASCII, first.isLetter else { return false }
        return scheme.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber
                                    || character == "+" || character == "-" || character == ".")
        }
    }

    static func url(scheme: String, localPort: Int) -> URL? {
        guard let normalizedScheme = normalizedScheme(scheme),
              isValidScheme(normalizedScheme),
              (1...Int(UInt16.max)).contains(localPort) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = normalizedScheme
        components.host = loopbackHost
        components.port = localPort
        return components.url
    }
}

extension PeerServiceInfo {
    var isWebService: Bool {
        PeerTunnelEndpoint.isWebScheme(scheme)
    }
}

extension PeerTunnelInfo {
    /// Loopback endpoint for any scheme — used for copy-to-clipboard.
    var loopbackURL: URL? {
        PeerTunnelEndpoint.url(scheme: scheme, localPort: localPort)
    }

    var isWebEndpoint: Bool {
        PeerTunnelEndpoint.isWebScheme(scheme) && loopbackURL != nil
    }

    /// Browsable URL — only web (http/https) schemes load in the in-app WKWebView.
    var browsableURL: URL? {
        isWebEndpoint ? loopbackURL : nil
    }
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

extension PeerServicesResult {
    var hasExposedServices: Bool {
        status == .success && !services.isEmpty
    }
}

// MARK: - Service

class PeerSharingService {

    private let peerServicesAdapter: PeerServicesAdapter
    private let log = SwiftyBeaver.self

    private let serviceQueue = DispatchQueue(label: "com.jami.PeerSharingService")
    private let peerServicesSubject = PublishSubject<PeerServicesResult>()
    private var peerServicesRelays = [String: BehaviorRelay<PeerServicesResult?>]()
    private var tunnelStates = [String: BehaviorRelay<PeerTunnelState>]()
    private let tunnelOpenedSubject = PublishSubject<PeerTunnelInfo>()
    private var pendingOpens = [String: PendingOpen]()

    private struct PendingOpen {
        let accountId: String
        let peerId: String
        let serviceId: String
        let serviceName: String
        let scheme: String
    }

    private struct QueuedTunnelOpen {
        let accountId: String
        let peerId: String
        let service: PeerServiceInfo
    }

    /// Opens requested after an active tunnel for the same service is closed (close-then-open).
    private var queuedOpensAfterClose = [String: QueuedTunnelOpen]()

    /// Tunnels closed optimistically before `ServiceTunnelClosed` arrives.
    private var closingTunnels = [String: (accountId: String, peerId: String, serviceId: String)]()

    /// Pending tunnel ids canceled before `TunnelOpened` arrives (background / sheet dismiss race).
    private var canceledPendingTunnelIds = Set<String>()

    private struct PeerScope {
        let accountId: String
        let peerId: String
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

    func queryPeerServices(accountId: String, peerId: String) -> Observable<PeerServicesResult> {
        return Observable.deferred { [weak self] in
            guard let self = self else { return .empty() }

            let requestId = self.peerServicesAdapter.queryPeerServices(withAccountId: accountId, peerUri: peerId)
            guard requestId != 0 else {
                return .just(PeerServicesResult(
                    requestId: 0,
                    accountId: accountId,
                    peerId: peerId,
                    status: .internalError,
                    services: []
                ))
            }

            return self.peerServicesSubject
                .filter { $0.requestId == requestId && $0.accountId == accountId && $0.peerId == peerId }
                .take(1)
        }
    }

    /// All peer service updates for this account+peer, including proactive cache fills (requestId == 0).
    func observePeerServices(accountId: String, peerId: String) -> Observable<PeerServicesResult> {
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onCompleted()
                return Disposables.create()
            }
            let serial = SerialDisposable()
            self.onDaemonCallback { service in
                let relay = service.getOrCreatePeerServicesRelay(accountId: accountId, peerId: peerId)
                serial.disposable = relay
                    .compactMap { $0 }
                    .subscribe(observer)
            }
            return serial
        }
    }

    func openTunnel(accountId: String, peerId: String, service: PeerServiceInfo) {
        onDaemonCallback { sharingService in
            sharingService.requestOpenTunnel(accountId: accountId, peerId: peerId, service: service)
        }
    }

    func closeTunnel(accountId: String, peerId: String, serviceId: String) {
        onDaemonCallback { service in
            let key = service.stateKey(accountId: accountId, peerId: peerId)
            guard let relay = service.tunnelStates[key],
                  let tunnelId = relay.value.activeTunnels[serviceId]?.tunnelId else { return }

            var current = relay.value
            current.activeTunnels.removeValue(forKey: serviceId)
            relay.accept(current)
            service.closingTunnels[tunnelId] = (accountId, peerId, serviceId)

            _ = service.peerServicesAdapter.closeServiceTunnel(withAccountId: accountId, tunnelId: tunnelId)
        }
    }

    func observeTunnelState(accountId: String, peerId: String) -> Observable<PeerTunnelState> {
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onCompleted()
                return Disposables.create()
            }
            let serial = SerialDisposable()
            self.onDaemonCallback { service in
                let relay = service.getOrCreateState(accountId: accountId, peerId: peerId)
                serial.disposable = relay.asObservable().subscribe(observer)
            }
            return serial
        }
    }

    func observeTunnelUrl(accountId: String, peerId: String) -> Observable<URL> {
        return tunnelOpenedSubject
            .filter { $0.accountId == accountId && $0.peerId == peerId }
            .compactMap { $0.browsableURL }
    }

    func closeAllTunnels() {
        onDaemonCallback { service in
            service.closeTunnels(matching: nil)
        }
    }

    func closeAllTunnels(accountId: String, peerId: String) {
        onDaemonCallback { service in
            service.closeTunnels(matching: PeerScope(accountId: accountId, peerId: peerId))
        }
    }

    // MARK: - Private helpers

    private func stateKey(accountId: String, peerId: String) -> String {
        return "\(accountId)\0\(peerId)"
    }

    private func queuedOpenKey(accountId: String, peerId: String, serviceId: String) -> String {
        return "\(stateKey(accountId: accountId, peerId: peerId))\0\(serviceId)"
    }

    private func queuedOpenMatchesScope(_ key: String, scope: PeerScope) -> Bool {
        return key.hasPrefix(stateKey(accountId: scope.accountId, peerId: scope.peerId) + "\0")
    }

    /// Must run on `serviceQueue`. `matching == nil` closes all peers (app background).
    private func closeTunnels(matching scope: PeerScope?) {
        if let scope = scope {
            queuedOpensAfterClose = queuedOpensAfterClose.filter { !queuedOpenMatchesScope($0.key, scope: scope) }
            closingTunnels = closingTunnels.filter { _, value in
                value.accountId != scope.accountId || value.peerId != scope.peerId
            }
        } else {
            queuedOpensAfterClose.removeAll()
            closingTunnels.removeAll()
            canceledPendingTunnelIds.removeAll()
        }

        let pendingToCancel = pendingOpens.filter { _, pending in
            guard let scope = scope else { return true }
            return pending.accountId == scope.accountId && pending.peerId == scope.peerId
        }
        for (tunnelId, pending) in pendingToCancel {
            canceledPendingTunnelIds.insert(tunnelId)
            _ = peerServicesAdapter.closeServiceTunnel(withAccountId: pending.accountId, tunnelId: tunnelId)
            pendingOpens.removeValue(forKey: tunnelId)
        }

        for (key, relay) in tunnelStates {
            if let scope = scope, key != stateKey(accountId: scope.accountId, peerId: scope.peerId) {
                continue
            }
            let state = relay.value
            for (_, tunnelInfo) in state.activeTunnels {
                _ = peerServicesAdapter.closeServiceTunnel(
                    withAccountId: tunnelInfo.accountId,
                    tunnelId: tunnelInfo.tunnelId
                )
            }
            relay.accept(PeerTunnelState())
        }
    }

    /// Must run on `serviceQueue`. Closes an existing tunnel for the service before opening when needed.
    private func requestOpenTunnel(accountId: String, peerId: String, service: PeerServiceInfo) {
        let subject = getOrCreateState(accountId: accountId, peerId: peerId)
        let current = subject.value

        if current.pendingServices.contains(service.id) {
            return
        }

        if let active = current.activeTunnels[service.id] {
            queuedOpensAfterClose[queuedOpenKey(accountId: accountId, peerId: peerId, serviceId: service.id)] =
                QueuedTunnelOpen(accountId: accountId, peerId: peerId, service: service)
            var updated = current
            updated.pendingServices.insert(service.id)
            subject.accept(updated)
            _ = peerServicesAdapter.closeServiceTunnel(withAccountId: accountId, tunnelId: active.tunnelId)
            return
        }

        performOpenTunnel(accountId: accountId, peerId: peerId, service: service)
    }

    private func performOpenTunnel(accountId: String,
                                   peerId: String,
                                   service: PeerServiceInfo) {
        let subject = getOrCreateState(accountId: accountId, peerId: peerId)
        var current = subject.value
        current.pendingServices.insert(service.id)
        subject.accept(current)

        let tunnelId = peerServicesAdapter.openServiceTunnel(
            withAccountId: accountId,
            peerUri: peerId,
            deviceId: service.device,
            serviceId: service.id,
            serviceName: service.name,
            localPort: 0
        ) ?? ""

        if tunnelId.isEmpty {
            var updated = subject.value
            updated.pendingServices.remove(service.id)
            subject.accept(updated)
        } else {
            pendingOpens[tunnelId] = PendingOpen(
                accountId: accountId,
                peerId: peerId,
                serviceId: service.id,
                serviceName: service.name,
                scheme: service.scheme
            )
        }
    }

    private func processQueuedOpenAfterClose(accountId: String, peerId: String, serviceId: String) {
        let queueKey = queuedOpenKey(accountId: accountId, peerId: peerId, serviceId: serviceId)
        guard let queued = queuedOpensAfterClose.removeValue(forKey: queueKey) else { return }
        performOpenTunnel(accountId: queued.accountId, peerId: queued.peerId, service: queued.service)
    }

    private func getOrCreateState(accountId: String, peerId: String) -> BehaviorRelay<PeerTunnelState> {
        let key = stateKey(accountId: accountId, peerId: peerId)
        if let existing = tunnelStates[key] {
            return existing
        }
        let relay = BehaviorRelay<PeerTunnelState>(value: PeerTunnelState())
        tunnelStates[key] = relay
        return relay
    }

    private func getOrCreatePeerServicesRelay(accountId: String, peerId: String) -> BehaviorRelay<PeerServicesResult?> {
        let key = stateKey(accountId: accountId, peerId: peerId)
        if let existing = peerServicesRelays[key] {
            return existing
        }
        let relay = BehaviorRelay<PeerServicesResult?>(value: nil)
        peerServicesRelays[key] = relay
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
        onDaemonCallback { service in
            service.peerServicesSubject.onNext(result)
            service.getOrCreatePeerServicesRelay(accountId: accountId, peerId: peerId).accept(result)
        }
    }

    func serviceTunnelOpened(withAccountId accountId: String,
                             tunnelId: String,
                             localPort: UInt16) {
        onDaemonCallback { service in
            if service.canceledPendingTunnelIds.remove(tunnelId) != nil {
                _ = service.peerServicesAdapter.closeServiceTunnel(withAccountId: accountId, tunnelId: tunnelId)
                return
            }

            guard let pending = service.pendingOpens.removeValue(forKey: tunnelId) else {
                service.log.warning("TunnelOpened with no pending open for tunnelId=\(tunnelId)")
                _ = service.peerServicesAdapter.closeServiceTunnel(withAccountId: accountId, tunnelId: tunnelId)
                return
            }

            let key = service.stateKey(accountId: pending.accountId, peerId: pending.peerId)
            guard let subject = service.tunnelStates[key] else { return }

            let info = PeerTunnelInfo(
                tunnelId: tunnelId,
                accountId: pending.accountId,
                peerId: pending.peerId,
                serviceId: pending.serviceId,
                serviceName: pending.serviceName,
                scheme: pending.scheme,
                localPort: Int(localPort)
            )
            var current = subject.value
            current.activeTunnels[pending.serviceId] = info
            current.pendingServices.remove(pending.serviceId)
            subject.accept(current)

            service.tunnelOpenedSubject.onNext(info)
        }
    }

    func serviceTunnelClosed(withAccountId accountId: String,
                             tunnelId: String,
                             reason: String) {
        onDaemonCallback { service in
            if let closing = service.closingTunnels.removeValue(forKey: tunnelId) {
                service.processQueuedOpenAfterClose(
                    accountId: closing.accountId,
                    peerId: closing.peerId,
                    serviceId: closing.serviceId
                )
                return
            }

            for (_, relay) in service.tunnelStates {
                var current = relay.value
                if let serviceId = current.activeTunnels.first(where: { $0.value.tunnelId == tunnelId })?.key {
                    let tunnelInfo = current.activeTunnels[serviceId]!
                    current.activeTunnels.removeValue(forKey: serviceId)
                    relay.accept(current)
                    service.processQueuedOpenAfterClose(
                        accountId: tunnelInfo.accountId,
                        peerId: tunnelInfo.peerId,
                        serviceId: serviceId
                    )
                    return
                }
            }
            if let pending = service.pendingOpens.removeValue(forKey: tunnelId) {
                let key = service.stateKey(accountId: pending.accountId, peerId: pending.peerId)
                guard let relay = service.tunnelStates[key] else { return }
                var current = relay.value
                current.pendingServices.remove(pending.serviceId)
                relay.accept(current)
            }
        }
    }
}
