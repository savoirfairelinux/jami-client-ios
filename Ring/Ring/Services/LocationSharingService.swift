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

struct SerializableLocation: Codable {
    var lat: Double
    var long: Double
    var alt: Double
    var time: Int64
}

class OutgoingLocationSharingInstance {

    private let locationSharingService: LocationSharingService

    let contactUri: String
    let duration: TimeInterval
    private var endSharingTimer: Timer?

    init(locationSharingService: LocationSharingService, contactUri: String, duration: TimeInterval) {
        self.locationSharingService = locationSharingService
        self.contactUri = contactUri
        self.duration = duration

        self.endSharingTimer =
            Timer.scheduledTimer(timeInterval: self.duration,
                                 target: self,
                                 selector: #selector(self.endSharing),
                                 userInfo: nil,
                                 repeats: false)
    }

    @objc private func endSharing(timer: Timer) {
        self.locationSharingService.stopSharingLocation(to: self.contactUri)
    }

    func invalidate() {
        if let timer = self.endSharingTimer {
            timer.invalidate()
            self.endSharingTimer = nil
        }
    }
}

class LocationSharingService: NSObject {

    private let incomingLocationSharingEndingDelay: TimeInterval = 10 * 60 // 10 mins

    private let log = SwiftyBeaver.self

    private let accountsService: AccountsService
    private let conversationService: ConversationsService
    private let dbManager: DBManager

    private let disposeBag = DisposeBag()
    private let locationManager = CLLocationManager()

    // Sharing my location
    let currentLocation = BehaviorRelay<CLLocation?>(value: nil)
    private var outgoingInstances: [String: OutgoingLocationSharingInstance] = [:]

    // Receiving my contact's location
    let locationReceivedFromRecipientUri = BehaviorRelay<(String?, CLLocationCoordinate2D?)>(value: (nil, nil))
    private var contactUriWithLastReceivedDate: [String: Date] = [:]
    let stopSharingNotification = BehaviorRelay<[String: String]>(value: [:])

    init(withAccountService accountsService: AccountsService,
         withConversationService conversationService: ConversationsService,
         dbManager: DBManager) {
        self.accountsService = accountsService
        self.conversationService = conversationService
        self.dbManager = dbManager
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

                for (keyValue) in self.contactUriWithLastReceivedDate {
                    let positiveTimeElapsed = -keyValue.value.timeIntervalSinceNow
                    if positiveTimeElapsed > self.incomingLocationSharingEndingDelay {
                        self.stopReceivingLocation(from: keyValue.key)
                    }
                }
            })
            .disposed(by: self.disposeBag)
    }

    func clearLocationUpdatesFromDB(accountId: String) {
        self.conversationService
            .deleteAllLocationUpdates(accountId: accountId)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    private static func serializeLocation(location: CLLocation) -> String? {
        // TODO: time?
        let sLocation = SerializableLocation(lat: location.coordinate.latitude, long: location.coordinate.longitude, alt: location.altitude, time: 0)

        do {
            let data = try JSONEncoder().encode(sLocation)
            return String(data: data, encoding: .utf8)!
        } catch {
            return nil
        }
    }

    private static func deserializeLocation(json: String) -> CLLocationCoordinate2D? {
        do {
            // TODO: altitude and time?
            let sLocation = try JSONDecoder().decode(SerializableLocation.self, from: json.data(using: .utf8)!)
            return CLLocationCoordinate2D(latitude: sLocation.lat, longitude: sLocation.long)
        } catch {
            return nil
        }
    }
}

// MARK: Sharing my location
extension LocationSharingService {

    func startSharingLocation(to recipientUri: String, duration: TimeInterval) {
        guard self.outgoingInstances[recipientUri] == nil else { return } //already sharing

        self.outgoingInstances[recipientUri] = OutgoingLocationSharingInstance(locationSharingService: self,
                                                                               contactUri: recipientUri,
                                                                               duration: duration)
        self.locationManager.startUpdatingLocation()
    }

    private func doShareLocationAction(_ location: CLLocation) {
        guard let account = self.accountsService.currentAccount,
              let jsonLocation = LocationSharingService.serializeLocation(location: location) else { return }

        for (keyValue) in outgoingInstances {
            self.conversationService
                .sendLocation(withContent: jsonLocation,
                              from: account,
                              recipientUri: keyValue.key)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.debug("[LocationSharingService] Location sent")
                }).disposed(by: self.disposeBag)
        }
    }

    func stopSharingLocation(to recipientUri: String) {
        self.outgoingInstances[recipientUri]?.invalidate()
        self.outgoingInstances.removeValue(forKey: recipientUri)

        if self.outgoingInstances.isEmpty {
            self.log.debug("[LocationSharingService] stopUpdatingLocation")
            self.locationManager.stopUpdatingLocation()
        }

        if let account = self.accountsService.currentAccount {
            self.conversationService.deleteLocationUpdate(incoming: false,
                                                          peerUri: recipientUri,
                                                          to: account.id,
                                                          shouldRefreshConversations: true)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }
}

// MARK: Receiving my contact's location
extension LocationSharingService {

    func handleReceivedLocationUpdate(from peerUri: String, to accountId: String, messageId: String, locationJSON content: String) {
        self.contactUriWithLastReceivedDate[peerUri] = Date()

        let value = (peerUri, LocationSharingService.deserializeLocation(json: content))
        self.locationReceivedFromRecipientUri.accept(value)
    }

    func stopReceivingLocation(from peerUri: String) {
        guard let account = self.accountsService.currentAccount else { return }

        self.conversationService.deleteLocationUpdate(incoming: true,
                                                      peerUri: peerUri,
                                                      to: account.id,
                                                      shouldRefreshConversations: true)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe()
            .disposed(by: self.disposeBag)

        self.contactUriWithLastReceivedDate.removeValue(forKey: peerUri)

        self.showStopReceivingNotification(contactUri: peerUri, accoundId: account.id)

        self.log.debug("[LocationSharingService] stopReceivingLocation")
    }

    // Notification
    private func packageNotificationData(body: String, peerUri: String, accoundId: String) -> [String: String] {
        var data = [String: String]()
        data[NotificationUserInfoKeys.messageContent.rawValue] = body
        data[NotificationUserInfoKeys.participantID.rawValue] = peerUri
        data[NotificationUserInfoKeys.accountID.rawValue] = accoundId
        return data
    }

    private func showStopReceivingNotification(contactUri: String, accoundId: String) {
        let data = self.packageNotificationData(body: L10n.Notifications.locationSharingStopped, peerUri: contactUri, accoundId: accoundId)
        self.stopSharingNotification.accept(data)
    }
}

// MARK: CLLocationManagerDelegate
extension LocationSharingService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentLocation.accept(location)
//        self.log.debug("[LocationSharingService] didUpdateLocations: \(location.coordinate)")
     }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.log.debug("[LocationSharingService] didFailWithError: \(error)")
    }

//     func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
//         checkLocationAuthorization()
//     }
}
