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

import RxSwift
import RxCocoa
import SwiftyBeaver

// swiftlint:disable redundant_string_enum_value
enum SerializableLocationTypes: String {
    case position = "position"
    case stop = "stop"
}
// swiftlint:enable redundant_string_enum_value

struct SerializableLocation: Codable {
    var type: String?   // position (optional) and stop
    var lat: Double?    // position
    var long: Double?   // position
    var alt: Double?    // position
    var time: Int64     // position and stop
    var bearing: Float? // position (optional)
    var speed: Float?   // position (optional)
}

private class LocationSharingInstanceDictionary<T: LocationSharingInstance> {
    private var instances: [String: T] = [:]

    var isEmpty: Bool { return self.instances.isEmpty }

    private func key(_ accountId: String, _ contactUri: String, _ conversationId: String) -> String {
        return accountId + contactUri + conversationId
    }

    func get(_ accountId: String, _ contactUri: String, _ conversationId: String) -> T? {
        return self.instances[key(accountId, contactUri, conversationId)]
    }

    func insertOrUpdate(_ instance: T) {
        self.instances[key(instance.accountId, instance.contactUri, instance.conversationId)] = instance
    }

    func remove(_ accountId: String, _ contactUri: String, _ conversationId: String) -> T? {
        return self.instances.removeValue(forKey: key(accountId, contactUri, conversationId))
    }

    func asArray() -> [T] {
        return self.instances.map({ $0.value })
    }
}

private class LocationSharingInstance {
    let accountId: String
    let contactUri: String
    let conversationId: String

    init(accountId: String, contactUri: String, conversationId: String) {
        self.accountId = accountId
        self.contactUri = contactUri
        self.conversationId = conversationId
    }
}

private class OutgoingLocationSharingInstance: LocationSharingInstance {

    private let locationSharingService: LocationSharingService
    let duration: TimeInterval

    private var endSharingTimer: Timer?

    init(locationSharingService: LocationSharingService, accountId: String, contactUri: String, duration: TimeInterval, conversationId: String) {
        self.locationSharingService = locationSharingService
        self.duration = duration
        super.init(accountId: accountId, contactUri: contactUri, conversationId: conversationId)

        self.endSharingTimer =
            Timer.scheduledTimer(timeInterval: self.duration,
                                 target: self,
                                 selector: #selector(self.endSharing),
                                 userInfo: nil,
                                 repeats: false)
    }

    @objc
    private func endSharing(timer: Timer) {
        self.locationSharingService.stopSharingLocation(accountId: self.accountId, contactUri: self.contactUri, conversationId: self.conversationId)
    }

    func invalidate() {
        if let timer = self.endSharingTimer {
            timer.invalidate()
            self.endSharingTimer = nil
        }
    }
}

private class IncomingLocationSharingInstance: LocationSharingInstance {

    var lastReceivedDate: Date
    var lastReceivedTimeStamp: Int64

    init(accountId: String, contactUri: String, lastReceivedDate: Date, lastReceivedTimeStamp: Int64, conversationId: String) {
        self.lastReceivedDate = lastReceivedDate
        self.lastReceivedTimeStamp = lastReceivedTimeStamp
        super.init(accountId: accountId, contactUri: contactUri, conversationId: conversationId)
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
    private let outgoingInstances = LocationSharingInstanceDictionary<OutgoingLocationSharingInstance>()

    // Receiving my contact's location
    typealias ContactLocation = (conversationId: String?, contactUri: String?, location: CLLocationCoordinate2D?)
    let locationReceived = BehaviorRelay<(ContactLocation)>(value: (nil, nil, nil))
    private let incomingInstances = LocationSharingInstanceDictionary<IncomingLocationSharingInstance>()

    var receivingService: Disposable?

    // ServiceEvents
    private let locationServiceEventStream = PublishSubject<ServiceEvent>()
    let locationServiceEventShared: Observable<ServiceEvent>

    init(dbManager: DBManager) {
        self.dbManager = dbManager

        self.locationServiceEventStream.disposed(by: self.disposeBag)
        self.locationServiceEventShared = self.locationServiceEventStream.share()
        super.init()

        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.initialize()
    }

    private func initialize() {
        self.currentLocation
            .throttle(Durations.tenSeconds.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] location in
                guard let self = self, let location = location else { return }
                self.doShareLocationAction(location)
            })
        .disposed(by: self.disposeBag)
    }

    private static func serializeLocation(location: SerializableLocation) -> String? {
        do {
            let data = try JSONEncoder().encode(location)
            return String(data: data, encoding: .utf8)!
        } catch {
            return nil
        }
    }

    private static func deserializeLocation(json: String) -> SerializableLocation? {
        do {
            return try JSONDecoder().decode(SerializableLocation.self, from: json.data(using: .utf8)!)
        } catch {
            return nil
        }
    }

    private func triggerSendLocation(accountId: String, conversationId: String, content: String, shouldTryToSave: Bool) {
        var event = ServiceEvent(withEventType: .sendLocation)
        event.addEventInput(.accountId, value: accountId)
        event.addEventInput(.conversationId, value: conversationId)
        event.addEventInput(.content, value: (content, shouldTryToSave))
        self.locationServiceEventStream.onNext(event)
    }

    private func triggerDeleteLocation(accountId: String, contactUri: String, incoming: Bool, shouldRefreshConversations: Bool, conversationId: String) {
         var event = ServiceEvent(withEventType: .deleteLocation)
         event.addEventInput(.accountId, value: accountId)
         event.addEventInput(.peerUri, value: contactUri)
         event.addEventInput(.conversationId, value: conversationId)
         event.addEventInput(.content, value: (incoming, shouldRefreshConversations))
         self.locationServiceEventStream.onNext(event)
     }

    private func triggerStopSharing(accountId: String, contactUri: String, content: String, conversationId: String) {
        var event = ServiceEvent(withEventType: .stopLocationSharing)
        event.addEventInput(.accountId, value: accountId)
        event.addEventInput(.peerUri, value: contactUri)
        event.addEventInput(.conversationId, value: conversationId)
        event.addEventInput(.content, value: content)
        self.locationServiceEventStream.onNext(event)
    }
}

// MARK: Sharing my location
extension LocationSharingService {

    func isAlreadySharing(accountId: String, contactUri: String, conversationId: String) -> Bool {
        return self.outgoingInstances.get(accountId, contactUri, conversationId) != nil
    }

    func startSharingLocation(from accountId: String, to recipientUri: String, duration: TimeInterval, conversationId: String) {
        guard !self.isAlreadySharing(accountId: accountId, contactUri: recipientUri, conversationId: conversationId) else { return }

        let instanceToInsert = OutgoingLocationSharingInstance(locationSharingService: self,
                                                               accountId: accountId,
                                                               contactUri: recipientUri,
                                                               duration: duration,
                                                               conversationId: conversationId)
        self.outgoingInstances.insertOrUpdate(instanceToInsert)

        self.locationManager.startUpdatingLocation()
        self.locationManager.allowsBackgroundLocationUpdates = true
    }

    private func doShareLocationAction(_ location: CLLocation) {
        let serializable = SerializableLocation(type: SerializableLocationTypes.position.rawValue,
                                                lat: location.coordinate.latitude,
                                                long: location.coordinate.longitude,
                                                alt: location.altitude,
                                                time: Int64(Date().timeIntervalSince1970))
        guard let jsonLocation = LocationSharingService.serializeLocation(location: serializable) else { return }

        for instance in outgoingInstances.asArray() {
            self.triggerSendLocation(accountId: instance.accountId,
                                     conversationId: instance.conversationId,
                                     content: jsonLocation,
                                     shouldTryToSave: true)
        }
    }

    func stopSharingLocation(accountId: String, contactUri: String, conversationId: String) {
        self.outgoingInstances.get(accountId, contactUri, conversationId)?.invalidate()
        self.locationManager.allowsBackgroundLocationUpdates = false
        _ = self.outgoingInstances.remove(accountId, contactUri, conversationId)

        if self.outgoingInstances.isEmpty {
            self.locationManager.stopUpdatingLocation()
            self.currentLocation.accept(nil)
        }

        self.triggerDeleteLocation(accountId: accountId, contactUri: contactUri, incoming: false, shouldRefreshConversations: true, conversationId: conversationId)

        self.sendStopSharingLocationMessage(from: accountId, to: contactUri)
    }

    private func sendStopSharingLocationMessage(from accountId: String, to conversationId: String) {
        let serializable = SerializableLocation(type: SerializableLocationTypes.stop.rawValue,
                                                time: Int64(Date().timeIntervalSince1970))
        guard let jsonLocation = LocationSharingService.serializeLocation(location: serializable) else { return }

        self.triggerSendLocation(accountId: accountId,
                                 conversationId: conversationId,
                                 content: jsonLocation,
                                 shouldTryToSave: false)
    }
}

// MARK: Receiving my contact's location
extension LocationSharingService {

    func handleReceivedLocationUpdate(from contactUri: String, to accountId: String, messageId: String, locationJSON content: String, conversationId: String) {
        guard let incomingData = LocationSharingService.deserializeLocation(json: content) else { return }

        if incomingInstances.isEmpty {
            self.startReceivingService()
        }

        if let incomingInstance = self.incomingInstances.get(accountId, contactUri, conversationId) {
            if incomingInstance.lastReceivedTimeStamp < incomingData.time {
                incomingInstance.lastReceivedDate = Date()
                incomingInstance.lastReceivedTimeStamp = incomingData.time
            } else {
                return // ignore messages older than the newest we have (when receiving not in order)
            }
        } else {
            self.incomingInstances.insertOrUpdate(IncomingLocationSharingInstance(accountId: accountId,
                                                                                  contactUri: contactUri,
                                                                                  lastReceivedDate: Date(),
                                                                                  lastReceivedTimeStamp: incomingData.time,
                                                                                  conversationId: conversationId))
        }

        if incomingData.type == nil || incomingData.type == SerializableLocationTypes.position.rawValue {
            // TODO: altitude?
            let locationData = (ContactLocation(conversationId, contactUri, CLLocationCoordinate2D(latitude: incomingData.lat!, longitude: incomingData.long!)))
             self.locationReceived.accept(locationData)

        } else if incomingData.type == SerializableLocationTypes.stop.rawValue {
            self.stopReceivingLocation(accountId: accountId, contactUri: contactUri, conversationId: conversationId)
        }
    }

    func stopReceivingLocation(accountId: String, contactUri: String, conversationId: String) {
        self.locationReceived.accept(ContactLocation(conversationId, contactUri, nil))

        self.triggerDeleteLocation(accountId: accountId, contactUri: contactUri, incoming: true, shouldRefreshConversations: true, conversationId: conversationId)

        _ = self.incomingInstances.remove(accountId, contactUri, conversationId)

        if incomingInstances.isEmpty {
            self.stopReceivingService()
        }

        self.triggerStopSharing(accountId: accountId, contactUri: contactUri, content: L10n.Notifications.locationSharingStopped, conversationId: conversationId)
    }

    func startReceivingService() {
        self.stopReceivingService()
        self.receivingService = Observable<Int>.interval(Durations.sixtySeconds.toTimeInterval(), scheduler: MainScheduler.instance)
            .subscribe({ [weak self] _ in
                guard let self = self else { return }

                for (instance) in self.incomingInstances.asArray() {
                    let positiveTimeElapsed = -instance.lastReceivedDate.timeIntervalSinceNow
                    if positiveTimeElapsed > self.incomingLocationSharingEndingDelay {
                        self.stopReceivingLocation(accountId: instance.accountId, contactUri: instance.contactUri, conversationId: instance.accountId)
                    }
                }
            })
    }

    func stopReceivingService() {
        self.receivingService?.dispose()
        self.receivingService = nil
    }
}

// MARK: CLLocationManagerDelegate
extension LocationSharingService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentLocation.accept(location)
     }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.log.debug("[LocationSharingService] didFailWithError: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .notDetermined || status == .denied || status == .restricted {
            for instance in outgoingInstances.asArray() {
                self.stopSharingLocation(accountId: instance.accountId, contactUri: instance.contactUri, conversationId: instance.conversationId)
            }
        }
    }
}
