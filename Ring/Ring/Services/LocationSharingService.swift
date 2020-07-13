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
    var type: String?   //position (optional) and stop
    var lat: Double?    //position
    var long: Double?   //position
    var alt: Double?    //position
    var time: Int64     //position and stop
    var bearing: Float? //position (optional)
    var speed: Float?   //position (optional)
}

private class LocationSharingInstanceDictionary<T: LocationSharingInstance> {
    private var instances: [String: T] = [:]

    var isEmpty: Bool { return self.instances.isEmpty }

    private func key(_ accountId: String, _ contactUri: String) -> String {
        return accountId + contactUri
    }

    func get(_ accountId: String, _ contactUri: String) -> T? {
        return self.instances[key(accountId, contactUri)]
    }

    func insertOrUpdate(_ instance: T) {
        self.instances[key(instance.accountId, instance.contactUri)] = instance
    }

    func remove(_ accountId: String, _ contactUri: String) -> T? {
        return self.instances.removeValue(forKey: key(accountId, contactUri))
    }

    func asArray() -> [T] {
        return instances.map({ $0.value })
    }
}

private class LocationSharingInstance {
    let accountId: String
    let contactUri: String

    init(accountId: String, contactUri: String) {
        self.accountId = accountId
        self.contactUri = contactUri
    }
}

private class OutgoingLocationSharingInstance: LocationSharingInstance {

    private let locationSharingService: LocationSharingService
    let duration: TimeInterval

    private var endSharingTimer: Timer?

    init(locationSharingService: LocationSharingService, accountId: String, contactUri: String, duration: TimeInterval) {
        self.locationSharingService = locationSharingService
        self.duration = duration
        super.init(accountId: accountId, contactUri: contactUri)

        self.endSharingTimer =
            Timer.scheduledTimer(timeInterval: self.duration,
                                 target: self,
                                 selector: #selector(self.endSharing),
                                 userInfo: nil,
                                 repeats: false)
    }

    @objc private func endSharing(timer: Timer) {
        self.locationSharingService.stopSharingLocation(accountId: self.accountId, contactUri: self.contactUri)
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

    init(accountId: String, contactUri: String, lastReceivedDate: Date) {
        self.lastReceivedDate = lastReceivedDate
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
    private let outgoingInstances = LocationSharingInstanceDictionary<OutgoingLocationSharingInstance>()

    // Receiving my contact's location
    let locationReceivedFromRecipientUri = BehaviorRelay<(String?, CLLocationCoordinate2D?)>(value: (nil, nil))
    private let incomingInstances = LocationSharingInstanceDictionary<IncomingLocationSharingInstance>()
    let stopSharingNotification = BehaviorRelay<[String: String]>(value: [:])

    // ServiceEvents
    private let sendLocationStream = PublishSubject<ServiceEvent>()
    let sendLocationShared: Observable<ServiceEvent>

    private let deleteLocationStream = PublishSubject<ServiceEvent>()
    let deleteLocationShared: Observable<ServiceEvent>

    init(dbManager: DBManager) {
        self.dbManager = dbManager

        self.sendLocationStream.disposed(by: self.disposeBag)
        self.sendLocationShared = sendLocationStream.share()
        self.deleteLocationStream.disposed(by: self.disposeBag)
        self.deleteLocationShared = deleteLocationStream.share()
        super.init()

        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.allowsBackgroundLocationUpdates = true
        self.initialize()
    }

    private func initialize() {
        self.currentLocation
            .throttle(10, scheduler: MainScheduler.instance)
            .subscribe({ [weak self] location in
                guard let self = self, let location = location.element, location != nil else { return }
                self.doShareLocationAction(location!)
            })
        .disposed(by: self.disposeBag)

        Observable<Int>.interval(60, scheduler: MainScheduler.instance)
            .subscribe({ [weak self] _ in
                guard let self = self else { return }

                for (instance) in self.incomingInstances.asArray() {
                    let positiveTimeElapsed = -instance.lastReceivedDate.timeIntervalSinceNow
                    if positiveTimeElapsed > self.incomingLocationSharingEndingDelay {
                        self.stopReceivingLocation(accountId: instance.accountId, contactUri: instance.contactUri)
                    }
                }
            })
            .disposed(by: self.disposeBag) // tmp dispoeBag
    }

    func clearLocationUpdatesFromDB(accountId: String) {
        self.dbManager
            .deleteAllLocationUpdates(accountId: accountId)
            .subscribe()
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

    private func triggerSendLocation(accountId: String, peerUri: String, content: String) {
        var event = ServiceEvent(withEventType: .sendLocation)
        event.addEventInput(.accountId, value: accountId)
        event.addEventInput(.peerUri, value: peerUri)
        event.addEventInput(.content, value: content)
        self.sendLocationStream.onNext(event)
    }

    private func triggerDeleteLocation(accountId: String, peerUri: String, incoming: Bool, shouldRefreshConversations: Bool) {
         var event = ServiceEvent(withEventType: .deleteLocation)
         event.addEventInput(.accountId, value: accountId)
         event.addEventInput(.peerUri, value: peerUri)
         event.addEventInput(.content, value: (incoming, shouldRefreshConversations))
         self.deleteLocationStream.onNext(event)
     }
}

// MARK: Sharing my location
extension LocationSharingService {

    func isAlreadySharing(accountId: String, contactUri: String) -> Bool {
        return self.outgoingInstances.get(accountId, contactUri) != nil
    }

    func startSharingLocation(from accountId: String, to recipientUri: String, duration: TimeInterval) {
        guard !self.isAlreadySharing(accountId: accountId, contactUri: recipientUri) else { return }

        let instanceToInsert = OutgoingLocationSharingInstance(locationSharingService: self,
                                                               accountId: accountId,
                                                               contactUri: recipientUri,
                                                               duration: duration)
        self.outgoingInstances.insertOrUpdate(instanceToInsert)

        self.locationManager.startUpdatingLocation()
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
                                     peerUri: instance.contactUri,
                                     content: jsonLocation)
        }
    }

    func stopSharingLocation(accountId: String, contactUri: String) {
        (self.outgoingInstances.get(accountId, contactUri)! as OutgoingLocationSharingInstance).invalidate()
        _ = self.outgoingInstances.remove(accountId, contactUri)

        if self.outgoingInstances.isEmpty {
            self.locationManager.stopUpdatingLocation()
        }

        self.triggerDeleteLocation(accountId: accountId, peerUri: contactUri, incoming: false, shouldRefreshConversations: true)

        self.sendStopSharingLocationMessage(from: accountId, to: contactUri)
    }

    private func sendStopSharingLocationMessage(from accountId: String, to contactUri: String) {
        let serializable = SerializableLocation(type: SerializableLocationTypes.stop.rawValue,
                                                time: Int64(Date().timeIntervalSince1970))
        guard let jsonLocation = LocationSharingService.serializeLocation(location: serializable) else { return }

        self.triggerSendLocation(accountId: accountId,
                                 peerUri: contactUri,
                                 content: jsonLocation)
    }
}

// MARK: Receiving my contact's location
extension LocationSharingService {

    func handleReceivedLocationUpdate(from peerUri: String, to accountId: String, messageId: String, locationJSON content: String) {
        if let incomingInstance = self.incomingInstances.get(accountId, peerUri) {
            incomingInstance.lastReceivedDate = Date()
        } else {
            self.incomingInstances.insertOrUpdate(IncomingLocationSharingInstance(accountId: accountId, contactUri: peerUri, lastReceivedDate: Date()))
        }

        if let incomingData = LocationSharingService.deserializeLocation(json: content) {
            if incomingData.type == nil || incomingData.type == SerializableLocationTypes.position.rawValue {
                // TODO: altitude and time?
                let peerUriAndData = (peerUri, CLLocationCoordinate2D(latitude: incomingData.lat!, longitude: incomingData.long!))
                self.locationReceivedFromRecipientUri.accept(peerUriAndData)
            } else if incomingData.type == SerializableLocationTypes.stop.rawValue {
                self.stopReceivingLocation(accountId: accountId, contactUri: peerUri)
            }
        }
    }

    func stopReceivingLocation(accountId: String, contactUri: String) {
        self.triggerDeleteLocation(accountId: accountId, peerUri: contactUri, incoming: true, shouldRefreshConversations: true)

        _ = self.incomingInstances.remove(accountId, contactUri)

        self.showStopReceivingNotification(contactUri: contactUri, accoundId: accountId)
    }

    // Notification
    private func packageNotificationData(body: String, contactUri: String, accoundId: String) -> [String: String] {
        var data = [String: String]()
        data[NotificationUserInfoKeys.messageContent.rawValue] = body
        data[NotificationUserInfoKeys.participantID.rawValue] = contactUri
        data[NotificationUserInfoKeys.accountID.rawValue] = accoundId
        return data
    }

    private func showStopReceivingNotification(contactUri: String, accoundId: String) {
        let data = self.packageNotificationData(body: L10n.Notifications.locationSharingStopped, contactUri: contactUri, accoundId: accoundId)
        self.stopSharingNotification.accept(data)
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
                self.stopSharingLocation(accountId: instance.accountId, contactUri: instance.contactUri)
            }
        }
    }
}
