/*
 *  Copyright (C) 2020 Savoir-faire Linux Inc.
 *
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

import RxCocoa
import RxSwift
import SwiftyBeaver

enum SerializableLocationTypes: String {
    case position = "Position"
    case stop = "Stop"
}

// swiftlint:enable redundant_string_enum_value

struct SerializableLocation: Codable {
    var type: String? // position (optional) and stop
    var lat: Double? // position
    var long: Double? // position
    var alt: Double? // position
    var time: Int64? // position and stop
    var bearing: Float? // position (optional)
    var speed: Float? // position (optional)
}

class LocationSharingInstanceDictionary<T: LocationSharingInstance> {
    private var instances: [String: T] = [:]

    var isEmpty: Bool { return instances.isEmpty }

    private func key(_ accountId: String, _ contactUri: String) -> String {
        return accountId + contactUri.replacingOccurrences(of: "ring:", with: "")
    }

    func get(_ accountId: String, _ contactUri: String) -> T? {
        return instances[key(accountId, contactUri.replacingOccurrences(of: "ring:", with: ""))]
    }

    func insertOrUpdate(_ instance: T) {
        instances[key(
            instance.accountId,
            instance.contactUri.replacingOccurrences(of: "ring:", with: "")
        )] = instance
    }

    func remove(_ accountId: String, _ contactUri: String) -> T? {
        return instances.removeValue(forKey: key(
            accountId,
            contactUri.replacingOccurrences(of: "ring:", with: "")
        ))
    }

    func asArray() -> [T] {
        return instances.map { $0.value }
    }
}

class LocationSharingInstance {
    let accountId: String
    let contactUri: String

    init(accountId: String, contactUri: String) {
        self.accountId = accountId
        self.contactUri = contactUri
    }
}

class OutgoingLocationSharingInstance: LocationSharingInstance {
    private let locationSharingService: LocationSharingService
    let duration: TimeInterval
    var remainingTime: Int {
        let nowTime = Date()
        guard let sharingTime = endSharingTimer?.fireDate else { return 0 }
        return Int(round(sharingTime.timeIntervalSince(nowTime) / 60))
    }

    private var endSharingTimer: Timer?

    init(
        locationSharingService: LocationSharingService,
        accountId: String,
        contactUri: String,
        duration: TimeInterval
    ) {
        self.locationSharingService = locationSharingService
        self.duration = duration
        super.init(accountId: accountId, contactUri: contactUri)

        endSharingTimer =
            Timer.scheduledTimer(timeInterval: self.duration,
                                 target: self,
                                 selector: #selector(endSharing),
                                 userInfo: nil,
                                 repeats: false)
    }

    init(locationSharingService: LocationSharingService, accountId: String, contactUri: String) {
        self.locationSharingService = locationSharingService
        duration = 0
        super.init(accountId: accountId, contactUri: contactUri)
    }

    @objc
    private func endSharing(timer _: Timer) {
        locationSharingService.stopSharingLocation(accountId: accountId, contactUri: contactUri)
    }

    func invalidate() {
        if let timer = endSharingTimer {
            timer.invalidate()
            endSharingTimer = nil
        }
    }
}

class IncomingLocationSharingInstance: LocationSharingInstance {
    var lastReceivedDate: Date
    var lastReceivedTimeStamp: Int64

    init(
        accountId: String,
        contactUri: String,
        lastReceivedDate: Date,
        lastReceivedTimeStamp: Int64
    ) {
        self.lastReceivedDate = lastReceivedDate
        self.lastReceivedTimeStamp = lastReceivedTimeStamp
        super.init(accountId: accountId, contactUri: contactUri)
    }
}

class LocationSharingService: NSObject {
    private let incomingLocationSharingEndingDelay: TimeInterval = 10 * 60 // 10 mins

    private let log = SwiftyBeaver.self

    private let dbManager: DBManager

    private let disposeBag = DisposeBag()
    private let locationManager = CLLocationManager()

    // Sharing my location
    let currentLocation = BehaviorRelay<CLLocation?>(value: nil)
    private let outgoingInstances =
        LocationSharingInstanceDictionary<OutgoingLocationSharingInstance>()

    // Receiving my contact's location
    let peerUriAndLocationReceived = BehaviorRelay<(
        String?,
        CLLocationCoordinate2D?,
        Int?
    )>(value: (nil, nil, nil))
    private let incomingInstances =
        LocationSharingInstanceDictionary<IncomingLocationSharingInstance>()

    var receivingService: Disposable?

    // ServiceEvents
    private let locationServiceEventStream = PublishSubject<ServiceEvent>()
    let locationServiceEventShared: Observable<ServiceEvent>

    init(dbManager: DBManager) {
        self.dbManager = dbManager

        locationServiceEventStream.disposed(by: disposeBag)
        locationServiceEventShared = locationServiceEventStream.share()
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        initialize()
    }

    private func initialize() {
        currentLocation
            .throttle(Durations.tenSeconds.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] location in
                guard let self = self, let location = location else { return }
                self.doShareLocationAction(location)
            })
            .disposed(by: disposeBag)
    }

    static func serializeLocation(location: SerializableLocation) -> String? {
        do {
            let data = try JSONEncoder().encode(location)
            return String(data: data, encoding: .utf8)!
        } catch {
            return nil
        }
    }

    static func deserializeLocation(json: String) -> SerializableLocation? {
        do {
            return try JSONDecoder().decode(
                SerializableLocation.self,
                from: json.data(using: .utf8)!
            )
        } catch {
            return nil
        }
    }

    func triggerSendLocation(
        accountId: String,
        peerUri: String,
        content: String,
        shouldTryToSave: Bool
    ) {
        var event = ServiceEvent(withEventType: .sendLocation)
        event.addEventInput(.accountId, value: accountId)
        event.addEventInput(.peerUri, value: peerUri)
        event.addEventInput(.content, value: (content, shouldTryToSave))
        locationServiceEventStream.onNext(event)
    }

    func triggerStopSharing(accountId: String, peerUri: String, content: String) {
        var event = ServiceEvent(withEventType: .stopLocationSharing)
        event.addEventInput(.accountId, value: accountId)
        event.addEventInput(.peerUri, value: peerUri)
        event.addEventInput(.content, value: content)
        locationServiceEventStream.onNext(event)
    }

    func getLocationServiceEventStream() -> PublishSubject<ServiceEvent> {
        return locationServiceEventStream
    }

    func getOutgoingInstances()
    -> LocationSharingInstanceDictionary<OutgoingLocationSharingInstance> {
        return outgoingInstances
    }

    func getIncomingInstances()
    -> LocationSharingInstanceDictionary<IncomingLocationSharingInstance> {
        return incomingInstances
    }
}

// MARK: Sharing my location

extension LocationSharingService {
    func isAlreadySharing(accountId: String, contactUri: String) -> Bool {
        return incomingInstances.get(accountId, contactUri) != nil
    }

    func isAlreadySharingMyLocation(accountId: String, contactUri: String) -> Bool {
        return outgoingInstances.get(accountId, contactUri) != nil
    }

    func getMyLocationSharingRemainedTime(accountId: String, contactUri: String) -> Int {
        return Int(outgoingInstances.get(accountId, contactUri)?.remainingTime ?? 0)
    }

    func startSharingLocation(
        from accountId: String,
        to recipientUri: String,
        duration: TimeInterval? = nil
    ) {
        guard !isAlreadySharingMyLocation(accountId: accountId, contactUri: recipientUri)
        else { return }

        var instanceToInsert: OutgoingLocationSharingInstance!
        if let duration = duration {
            instanceToInsert = OutgoingLocationSharingInstance(locationSharingService: self,
                                                               accountId: accountId,
                                                               contactUri: recipientUri,
                                                               duration: duration)
        } else {
            instanceToInsert = OutgoingLocationSharingInstance(locationSharingService: self,
                                                               accountId: accountId,
                                                               contactUri: recipientUri)
        }

        outgoingInstances.insertOrUpdate(instanceToInsert)

        if let location = CLLocationManager().location {
            currentLocation.accept(location)
        }

        locationManager.startUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = true
    }

    private func doShareLocationAction(_ location: CLLocation) {
        let serializable = SerializableLocation(type: SerializableLocationTypes.position.rawValue,
                                                lat: location.coordinate.latitude,
                                                long: location.coordinate.longitude,
                                                alt: location.altitude,
                                                time: Int64(Date().timeIntervalSince1970))
        guard let jsonLocation = LocationSharingService.serializeLocation(location: serializable)
        else { return }

        for instance in outgoingInstances.asArray() {
            triggerSendLocation(accountId: instance.accountId,
                                peerUri: instance.contactUri,
                                content: jsonLocation,
                                shouldTryToSave: true)
        }
    }

    func stopSharingLocation(accountId: String, contactUri: String) {
        outgoingInstances.get(accountId, contactUri)?.invalidate()
        locationManager.allowsBackgroundLocationUpdates = false
        _ = outgoingInstances.remove(accountId, contactUri)

        if outgoingInstances.isEmpty {
            locationManager.stopUpdatingLocation()
            currentLocation.accept(nil)
        }

        sendStopSharingLocationMessage(from: accountId, to: contactUri)
    }

    private func sendStopSharingLocationMessage(from accountId: String, to contactUri: String) {
        let serializable = SerializableLocation(type: SerializableLocationTypes.stop.rawValue,
                                                time: Int64(Date().timeIntervalSince1970))
        guard let jsonLocation = LocationSharingService.serializeLocation(location: serializable)
        else { return }

        triggerSendLocation(accountId: accountId,
                            peerUri: contactUri,
                            content: jsonLocation,
                            shouldTryToSave: false)
    }
}

// MARK: Receiving my contact's location

extension LocationSharingService {
    func handleReceivedLocationUpdate(
        from peerUri: String,
        to accountId: String,
        messageId _: String,
        locationJSON content: String
    ) {
        guard let incomingData = LocationSharingService.deserializeLocation(json: content)
        else { return }

        if incomingInstances.isEmpty {
            startReceivingService()
        }

        if let incomingInstance = incomingInstances.get(accountId, peerUri) {
            if let incomingTime = incomingData.time {
                if incomingInstance.lastReceivedTimeStamp < incomingTime {
                    incomingInstance.lastReceivedDate = Date()
                    incomingInstance.lastReceivedTimeStamp = incomingTime
                } else {
                    return // ignore messages older than the newest we have (when receiving not in
                    // order)
                }
            }
        } else {
            if let incomingTime = incomingData.time {
                incomingInstances.insertOrUpdate(IncomingLocationSharingInstance(
                    accountId: accountId,
                    contactUri: peerUri,
                    lastReceivedDate: Date(),
                    lastReceivedTimeStamp: incomingTime
                ))
            }
        }

        if incomingData.type == nil || incomingData.type == SerializableLocationTypes.position
            .rawValue {
            // TODO: altitude?
            if let incomingTime = incomingData.time {
                let peerUriAndData = (
                    peerUri,
                    CLLocationCoordinate2D(latitude: incomingData.lat!,
                                           longitude: incomingData.long!),
                    Int(incomingTime) / 60000
                )
                peerUriAndLocationReceived.accept(peerUriAndData)
            }
        } else if incomingData.type == SerializableLocationTypes.stop.rawValue {
            stopReceivingLocation(accountId: accountId, contactUri: peerUri)
        }
    }

    func stopReceivingLocation(accountId: String, contactUri: String) {
        peerUriAndLocationReceived.accept((contactUri, nil, nil))

        _ = incomingInstances.remove(accountId, contactUri)

        if incomingInstances.isEmpty {
            stopReceivingService()
        }

        triggerStopSharing(
            accountId: accountId,
            peerUri: contactUri,
            content: L10n.Notifications.locationSharingStopped
        )
    }

    func startReceivingService() {
        stopReceivingService()
        receivingService = Observable<Int>.interval(
            Durations.sixtySeconds.toTimeInterval(),
            scheduler: MainScheduler.instance
        )
        .subscribe { [weak self] _ in
            guard let self = self else { return }

            for instance in self.incomingInstances.asArray() {
                let positiveTimeElapsed = -instance.lastReceivedDate.timeIntervalSinceNow
                if positiveTimeElapsed > self.incomingLocationSharingEndingDelay {
                    self.stopReceivingLocation(
                        accountId: instance.accountId,
                        contactUri: instance.contactUri
                    )
                }
            }
        }
    }

    func stopReceivingService() {
        receivingService?.dispose()
        receivingService = nil
    }
}

// MARK: CLLocationManagerDelegate

extension LocationSharingService: CLLocationManagerDelegate {
    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation.accept(location)
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        log.debug("[LocationSharingService] didFailWithError: \(error)")
    }

    func locationManager(
        _: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        if status == .notDetermined || status == .denied || status == .restricted {
            for instance in outgoingInstances.asArray() {
                stopSharingLocation(accountId: instance.accountId, contactUri: instance.contactUri)
            }
        }
    }
}
