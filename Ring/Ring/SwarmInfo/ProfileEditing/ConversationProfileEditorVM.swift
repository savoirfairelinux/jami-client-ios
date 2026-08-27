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

import UIKit

final class ConversationProfileEditorVM: ObservableObject {
    @Published var name: String
    @Published var description: String
    @Published var avatar: UIImage?
    @Published var saveFailed = false

    let dismissHandler = DismissHandler()
    let isSwarm: Bool

    private let conversation: ConversationModel
    private let conversationService: ConversationsService
    private let profileService: ProfilesService
    private var initialName = ""
    private var initialDescription = ""
    private let initialLocalPhoto: String?
    private let baseContactName: String?
    private let baseContactAvatar: UIImage?
    @Published private var avatarWasChanged = false
    @Published private var useOriginalContactAvatar = false
    private var contactURI: String?

    init(conversation: ConversationModel, injectionBag: InjectionBag) {
        self.conversation = conversation
        self.conversationService = injectionBag.conversationsService
        self.profileService = injectionBag.profileService

        let isGroup = !conversation.isCoredialog()
        isSwarm = isGroup

        if isGroup {
            let info = injectionBag.conversationsService
                .getConversationInfo(conversationId: conversation.id,
                                     accountId: conversation.accountId)
            name = info[ConversationAttributes.title.rawValue] ?? ""
            description = info[ConversationAttributes.description.rawValue] ?? ""
            avatar = info[ConversationAttributes.avatar.rawValue]?
                .toImageData()
                .flatMap { $0.isEmpty ? nil : UIImage(data: $0) }
            initialLocalPhoto = nil
            baseContactName = nil
            baseContactAvatar = nil
        } else {
            description = ""
            let uri = Self.contactURI(for: conversation, injectionBag: injectionBag)
            contactURI = uri
            let base = uri.flatMap {
                injectionBag.profileService.getProfileWithoutLocalOverride(uri: $0,
                                                                           accountId: conversation.accountId)
            }
            let local = uri.flatMap {
                injectionBag.profileService.getLocalProfileOverride(uri: $0,
                                                                    accountId: conversation.accountId)
            }
            let merged = base?.merging(localOverride: local) ?? local
            name = merged?.alias ?? ""
            avatar = merged?.photo?.toImageData().flatMap(UIImage.init(data:))
            initialLocalPhoto = local?.photo
            baseContactName = base?.alias
            baseContactAvatar = base?.photo?.toImageData().flatMap(UIImage.init(data:))
        }

        initialName = name
        initialDescription = description
    }

    var navigationTitle: String {
        isSwarm ? L10n.ProfileEditor.editGroup : L10n.ProfileEditor.editContact
    }

    var namePlaceholder: String {
        isSwarm ? L10n.ProfileEditor.groupNamePlaceholder : L10n.ProfileEditor.contactNamePlaceholder
    }

    var hasChanges: Bool {
        normalized(name) != normalized(initialName) ||
            normalized(description) != normalized(initialDescription) || avatarWasChanged
    }

    var canResetContactProfile: Bool {
        guard !isSwarm else { return false }
        return normalized(name) != normalized(baseContactName ?? "") || hasContactPictureOverride
    }

    var canRemoveAvatar: Bool {
        isSwarm ? avatar != nil : hasContactPictureOverride
    }

    private var hasContactPictureOverride: Bool {
        !useOriginalContactAvatar && (initialLocalPhoto != nil || avatarWasChanged)
    }

    func avatarDidChange() {
        avatarWasChanged = true
        useOriginalContactAvatar = false
    }

    func removeAvatar() {
        avatarWasChanged = true
        if isSwarm {
            avatar = nil
        } else {
            useOriginalContactAvatar = true
            avatar = baseContactAvatar
        }
    }

    func resetContactProfile() {
        guard !isSwarm else { return }
        name = baseContactName ?? ""
        useOriginalContactAvatar = true
        avatarWasChanged = true
        avatar = baseContactAvatar
    }

    func save() {
        saveFailed = false
        if isSwarm {
            saveSwarm()
        } else {
            saveContact()
        }
    }

    func dismiss() {
        dismissHandler.dismissView()
    }

    private func saveSwarm() {
        var info = conversationService.getConversationInfo(conversationId: conversation.id,
                                                           accountId: conversation.accountId)
        info[ConversationAttributes.title.rawValue] = normalized(name)
        info[ConversationAttributes.description.rawValue] = normalized(description)
        if avatarWasChanged {
            if let avatar {
                guard let data = avatar.convertToDataForSwarm() else {
                    saveFailed = true
                    return
                }
                info[ConversationAttributes.avatar.rawValue] = data.base64EncodedString()
            } else {
                info[ConversationAttributes.avatar.rawValue] = ""
            }
        }
        conversationService.updateConversationInfos(accountId: conversation.accountId,
                                                    conversationId: conversation.id,
                                                    infos: info)
        dismiss()
    }

    private func saveContact() {
        guard let contactURI else {
            saveFailed = true
            return
        }
        let trimmedName = normalized(name)
        let originalName = normalized(baseContactName ?? "")
        let aliasOverride = trimmedName.isEmpty || trimmedName == originalName ? nil : trimmedName
        var photoOverride = initialLocalPhoto
        if avatarWasChanged {
            if useOriginalContactAvatar {
                photoOverride = nil
            } else {
                guard let image = avatar?.fixOrientation(),
                      let data = image.convertToDataForSwarm() else {
                    saveFailed = true
                    return
                }
                photoOverride = data.base64EncodedString()
            }
        }
        let saved = profileService.updateLocalProfileOverride(uri: contactURI,
                                                              accountId: conversation.accountId,
                                                              alias: aliasOverride,
                                                              photo: photoOverride)
        guard saved else {
            saveFailed = true
            return
        }
        dismiss()
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func contactURI(for conversation: ConversationModel,
                                   injectionBag: InjectionBag) -> String? {
        guard let jamiId = conversation.getParticipants().first?.jamiId,
              let account = injectionBag.accountService.getAccount(fromAccountId: conversation.accountId) else {
            return nil
        }
        let schema: URIType = account.type == .sip ? .sip : .ring
        return JamiURI(schema: schema, infoHash: jamiId).uriString
    }
}
