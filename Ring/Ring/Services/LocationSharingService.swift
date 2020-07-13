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

class LocationSharingService: NSObject {

    private let incomingLocationSharingEndingDelay: Double = 10 * 60 // 10 mins

    private let log = SwiftyBeaver.self

    private let accountsService: AccountsService
    private let conversationService: ConversationsService
    private let dbManager: DBManager

    private let disposeBag = DisposeBag()
    private let locationManager = CLLocationManager()

    // Sharing my location
    let currentLocation = BehaviorRelay<CLLocation?>(value: nil)
    private var isSendingWithRecipientUri: [String: Bool] = [:]

    // Receiving my contact's location
    let locationReceivedFromRecipientUri = BehaviorRelay<(String?, CLLocationCoordinate2D?)>(value: (nil, nil))
    private var contactUriWithLastReceivedDate: [String: Date] = [:]

    init(withAccountService accountsService: AccountsService,
         withConversationService conversationService: ConversationsService,
         dbManager: DBManager) {
        self.accountsService = accountsService
        self.conversationService = conversationService
        self.dbManager = dbManager
        super.init()

        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
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

        Observable<Int>.interval(60, scheduler: MainScheduler.instance) // TODO: not 5
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

    func startSharingLocation(to recipientUri: String) {
        self.locationManager.startUpdatingLocation()

        self.isSendingWithRecipientUri[recipientUri] = true
    }

    private func doShareLocationAction(_ location: CLLocation) {
        guard let account = self.accountsService.currentAccount,
              let jsonLocation = LocationSharingService.serializeLocation(location: location) else { return }

        for (keyValue) in isSendingWithRecipientUri where keyValue.value {
            self.conversationService
                .sendLocation(withContent: jsonLocation,
                              from: account,
                              recipientUri: keyValue.key)
                .subscribe(onCompleted: { [weak self] in
                    self?.log.debug("LocationSharingService] Location sent")
                }).disposed(by: self.disposeBag)
        }
    }

    func stopSharingLocation(to recipientUri: String) {
        self.isSendingWithRecipientUri[recipientUri] = false

        if let account = self.accountsService.currentAccount {
            do {
                try self.dbManager.deleteLocationUpdate(incoming: false, peerUri: recipientUri, to: account.id)
            } catch {
                self.log.error("Error on stop receiving location")
            }
        }

        var allFalse = true
        for (keyValue) in isSendingWithRecipientUri where keyValue.value {
            allFalse = false
            break
        }
        if allFalse {
            self.locationManager.stopUpdatingLocation()
        }

        self.log.debug("[LocationSharingService] stopSharingLocation")
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
        do {
            try self.dbManager.deleteLocationUpdate(incoming: true, peerUri: peerUri, to: account.id)
            // TODO: Known bug: won't trigger a view update
        } catch {
            self.log.error("Error on stop receiving location")
        }

        self.contactUriWithLastReceivedDate.removeValue(forKey: peerUri)
        self.log.debug("[LocationSharingService] stopReceivingLocation")
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
