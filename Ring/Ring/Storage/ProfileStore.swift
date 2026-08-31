/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

enum ProfileSource {
    case localOverride
    case contact
    case jamsSearch
    case invitation
}

enum ManagedProfileSource: CaseIterable {
    case localOverride
    case jamsSearch
    case invitation

    var profileSource: ProfileSource {
        switch self {
        case .localOverride: return .localOverride
        case .jamsSearch: return .jamsSearch
        case .invitation: return .invitation
        }
    }
}

class ProfileStore {

    private enum Folder {
        static let jamsSearch = "jams-profiles"
        static let invitation = "invitation-profiles"
    }

    private static let lock = NSLock()

    func profile(uri: String, accountId: String, source: ProfileSource) -> Profile? {
        guard let path = path(uri: uri,
                              accountId: accountId,
                              source: source,
                              createIfNotExists: false) else { return nil }
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard let profile = VCardUtils.parseToProfile(filePath: path) else { return nil }
        switch source {
        case .contact, .localOverride:
            return profile
        case .jamsSearch, .invitation:
            return profile.isEmpty ? nil : profile
        }
    }

    @discardableResult
    func save(_ profile: Profile, accountId: String, source: ManagedProfileSource) -> Bool {
        guard !profile.isEmpty,
              let path = path(uri: profile.uri,
                              accountId: accountId,
                              source: source.profileSource,
                              createIfNotExists: true),
              let data = VCardUtils.vCardData(for: profile) else { return false }
        Self.lock.lock()
        defer { Self.lock.unlock() }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func remove(uri: String, accountId: String, source: ManagedProfileSource) {
        guard let path = path(uri: uri,
                              accountId: accountId,
                              source: source.profileSource,
                              createIfNotExists: false) else { return }
        Self.lock.lock()
        defer { Self.lock.unlock() }
        try? FileManager.default.removeItem(atPath: path)
    }

    func removeManagedProfiles(uri: String, accountId: String) {
        for source in ManagedProfileSource.allCases {
            remove(uri: uri, accountId: accountId, source: source)
        }
        removeLegacyContactProfiles(uri: uri, accountId: accountId)
    }

    func removeAllManagedProfiles(accountId: String) {
        guard let documents = Constants.documentsPath else { return }
        Self.lock.lock()
        defer { Self.lock.unlock() }
        for folder in [Folder.jamsSearch, Folder.invitation] {
            let path = ProfilePathHelper.profileFolderPath(accountId: accountId,
                                                           folder: folder,
                                                           documents: documents)
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func legacyContactProfile(uri: String, accountId: String) -> Profile? {
        guard let path = legacyContactProfilePaths(uri: uri, accountId: accountId)
                .first(where: { FileManager.default.fileExists(atPath: $0) }) else { return nil }
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return VCardUtils.parseToProfile(filePath: path)
    }

    func removeLegacyContactProfiles(uri: String, accountId: String) {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        for path in legacyContactProfilePaths(uri: uri, accountId: accountId) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func accountProfile(accountId: String) -> Profile? {
        guard let documents = Constants.documentsPath else { return nil }
        let path = ProfilePathHelper.accountProfilePath(accountId: accountId, documents: documents)
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return VCardUtils.parseToProfile(filePath: path)
    }

    @discardableResult
    func saveAccountProfile(_ profile: Profile, accountId: String) -> Bool {
        guard let documents = Constants.documentsPath,
              let data = try? VCardUtils.dataWithImageAndUUID(from: profile) else { return false }
        let path = ProfilePathHelper.accountProfilePath(accountId: accountId, documents: documents)
        let url = URL(fileURLWithPath: path)
        Self.lock.lock()
        defer { Self.lock.unlock() }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            try data.write(to: url, options: .atomic)
            return FileManager.default.fileExists(atPath: path)
        } catch {
            return false
        }
    }

    private func path(uri: String,
                      accountId: String,
                      source: ProfileSource,
                      createIfNotExists: Bool) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        switch source {
        case .contact:
            return ProfilePathHelper.contactProfilePath(accountId: accountId,
                                                        contactId: uri,
                                                        documents: documents)
        case .localOverride:
            return ProfilePathHelper.contactProfileOverridePath(accountId: accountId,
                                                                profileURI: uri,
                                                                documents: documents,
                                                                createIfNotExists: createIfNotExists)
        case .jamsSearch:
            return ProfilePathHelper.profilePath(accountId: accountId,
                                                 contactId: uri,
                                                 folder: Folder.jamsSearch,
                                                 documents: documents,
                                                 createIfNotExists: createIfNotExists)
        case .invitation:
            return ProfilePathHelper.profilePath(accountId: accountId,
                                                 contactId: uri,
                                                 folder: Folder.invitation,
                                                 documents: documents,
                                                 createIfNotExists: createIfNotExists)
        }
    }

    private func legacyContactProfilePaths(uri: String, accountId: String) -> [String] {
        guard let documents = Constants.documentsPath else { return [] }
        return ProfilePathHelper.profileURICandidates(for: uri).compactMap {
            ProfilePathHelper.legacyContactProfilePath(accountId: accountId,
                                                       profileURI: $0,
                                                       documents: documents)
        }
    }
}
