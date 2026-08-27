/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import UIKit

final class ConversationProfileEditorVM: ObservableObject {
    @Published var name: String
    @Published var description: String
    @Published var avatar: UIImage?
    @Published var saveFailed = false

    let dismissHandler = DismissHandler()

    private let context: ConversationProfileEditingContext
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

    init(context: ConversationProfileEditingContext, injectionBag: InjectionBag) {
        self.context = context
        self.conversationService = injectionBag.conversationsService
        self.profileService = injectionBag.profileService

        switch context {
        case .swarm(let swarmInfo):
            name = swarmInfo.title.value
            description = swarmInfo.description.value
            avatar = swarmInfo.avatarData.value.flatMap(UIImage.init(data:))
            initialLocalPhoto = nil
            baseContactName = nil
            baseContactAvatar = nil

        case .contact(let conversation):
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

    var isSwarm: Bool {
        if case .swarm = context { return true }
        return false
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
        switch context {
        case .swarm(let swarmInfo):
            saveSwarm(swarmInfo)
        case .contact(let conversation):
            saveContact(conversation)
        }
    }

    func dismiss() {
        dismissHandler.dismissView()
    }

    private func saveSwarm(_ swarmInfo: SwarmInfoProtocol) {
        guard let conversation = swarmInfo.conversation else {
            saveFailed = true
            return
        }
        let trimmedName = normalized(name)
        let trimmedDescription = normalized(description)
        var info = conversationService.getConversationInfo(conversationId: conversation.id,
                                                           accountId: conversation.accountId)
        info[ConversationAttributes.title.rawValue] = trimmedName
        info[ConversationAttributes.description.rawValue] = trimmedDescription
        var encodedAvatar: Data?
        if avatarWasChanged {
            if let avatar {
                guard let data = avatar.convertToDataForSwarm() else {
                    saveFailed = true
                    return
                }
                encodedAvatar = data
                info[ConversationAttributes.avatar.rawValue] = data.base64EncodedString()
            } else {
                info[ConversationAttributes.avatar.rawValue] = ""
            }
        }
        conversationService.updateConversationInfos(accountId: conversation.accountId,
                                                    conversationId: conversation.id,
                                                    infos: info)
        swarmInfo.title.accept(trimmedName)
        swarmInfo.description.accept(trimmedDescription)
        if avatarWasChanged {
            swarmInfo.avatarData.accept(encodedAvatar)
        }
        dismiss()
    }

    private func saveContact(_ conversation: ConversationModel) {
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
