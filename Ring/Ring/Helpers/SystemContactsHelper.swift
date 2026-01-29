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

import Contacts
import SwiftyBeaver

/// Helper that syncs Jami contacts to the system address book (add/update by identifier, alias, photo).
final class SystemContactsHelper {

    private let log = SwiftyBeaver.self
    private let queue = DispatchQueue(label: "com.jami.systemContacts", qos: .utility)

    init() {}

    func saveOrUpdate(identifier: String, alias: String?, registeredName: String?, photo: String?, accountId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let store = CNContactStore()
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized:
                self.saveOrUpdateInStore(identifier: identifier, alias: alias, registeredName: registeredName, photo: photo, store: store)
            case .notDetermined:
                self.log.debug("[SystemContacts] Requesting contacts permission for \(identifier)")
                store.requestAccess(for: .contacts) { [weak self] granted, error in
                    guard let self = self else { return }
                    if granted {
                        self.log.debug("[SystemContacts] Contacts permission granted, saving/updating for \(identifier)")
                        self.queue.async {
                            self.saveOrUpdateInStore(identifier: identifier, alias: alias, registeredName: registeredName, photo: photo, store: store)
                        }
                    } else {
                        self.log.warning("[SystemContacts] FAILED: Contacts permission denied for \(identifier). Error: \(error?.localizedDescription ?? "unknown")")
                    }
                }
            case .denied, .restricted, .limited:
                break
            @unknown default:
                break
            }
        }
    }

    private func saveOrUpdateInStore(identifier: String, alias: String?, registeredName: String?, photo: String?, store: CNContactStore) {
        // Enumerate with minimal keys only (no imageData) to find contact
        let keysForEnumeration: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        var existingIdentifier: String?
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysForEnumeration)
        fetchRequest.unifyResults = false
        do {
            try store.enumerateContacts(with: fetchRequest) { contact, stop in
                if contact.phoneNumbers.contains(where: { $0.value.stringValue == identifier }) {
                    existingIdentifier = contact.identifier
                    stop.pointee = true
                }
            }
        } catch {
            self.log.warning("[SystemContacts] FAILED: Enumerate contacts error for \(identifier): \(error.localizedDescription)")
            return
        }

        let request = CNSaveRequest()
        let displayName = alias ?? ""
        let photoString = photo ?? ""
        // Use empty image data when image not valid; or contact save can fail.
        let imageData: Data? = photoString.isEmpty
            ? UIImage().pngData()
            : photoString.toImageData()

        let keysForUpdate: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        if let existingIdentifier = existingIdentifier {
            do {
                let contact = try store.unifiedContact(withIdentifier: existingIdentifier, keysToFetch: keysForUpdate)
                guard let mutableContact = contact.mutableCopy() as? CNMutableContact else {
                    self.log.warning("[SystemContacts] FAILED: Could not get mutable contact for \(identifier)")
                    return
                }
                mutableContact.givenName = displayName
                mutableContact.imageData = imageData
                if let registeredName = registeredName {
                    mutableContact.nickname = registeredName
                }
                request.update(mutableContact)
                try store.execute(request)
            } catch {
                self.log.warning("[SystemContacts] FAILED: Update system contact for \(identifier): \(error.localizedDescription)")
            }
        } else {
            let contact = CNMutableContact()
            contact.givenName = displayName
            contact.phoneNumbers = [CNLabeledValue(label: "Jami", value: CNPhoneNumber(stringValue: identifier))]
            if !photoString.isEmpty {
                contact.imageData = imageData
            }
            if let registeredName = registeredName {
                contact.nickname = registeredName
            }
            request.add(contact, toContainerWithIdentifier: nil)
            do {
                try store.execute(request)
            } catch {
                self.log.warning("[SystemContacts] FAILED: Add system contact for \(identifier): \(error.localizedDescription)")
            }
        }
    }
}
