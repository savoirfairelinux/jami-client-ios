/*
 *  Copyright (C) 2022-2025 Savoir-faire Linux Inc.
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

let contributorsDevelopers: String = """
Abhishek Ojha
Adrien Béraud
Albert Babí
Alexander Lussier-Cullen
Alexandr Sergheev
Alexandre Eberhardt
Alexandre Lision
Alexandre Viau
Aline Bonnet
Aline Gondim Santos
Alireza Toghiani
Amin Bandali
AmirHossein Naghshzan
Amna Snene
Andreas Traczyk
Anthony Léonard
Brando Tovar
Capucine Berthet
Charles-Francis Damedey
Christophe Villemer
Cyrille Béraud
Dorina Mosku
Eden Abitbol
Édric Milaret
Éloi Bail
Emma Falkiewitz
Emmanuel Lepage-Vallée
Fadi Shehadeh
Franck Laurent
François-Simon Fauteux-Chapleau
Frédéric Guimont
Guillaume Heller
Guillaume Roguez
Hadrien De Sousa
Hugo Lefeuvre
Ilyas Erdogan
Julien Grossholtz
Julien Robert
Kateryna Kostiuk
Kessler DuPont-Teevin
Léo Banno-Cloutier
Léopold Chappuis
Liam Courdoson
Loïc Siret
Louis Maillard
Mathéo Joseph
Michel Schmit
Mingrui Zhang
Mohamed Chibani
Mohamed Amine Younes Bouacida
Nicolas Jäger
Nicolas Reynaud
Nicolas Vengeon
Olivier Gregoire
Olivier Soldano
Patrick Keroulas
Peymane Marandi
Philippe Gorley
Pierre Duchemin
Pierre Lespagnol
Pierre Nicolas
Raphaël Brulé
Rayan Osseiran
Romain Bertozzi
Saher Azer
Sébastien Blin
Seva Ivanov
Silbino Gonçalves Matado
Simon Désaulniers
Simon Zeni
Stepan Salenikovich
Thibault Wittemberg
Thomas Ballasi
Trevor Tabah
Vitalii Nikitchyn
Vsevolod Ivanov
Xavier Jouslin de Noray
Yang Wang
"""

let contributorsMedia: String = """
Charlotte Hoffman
Marianne Forget
"""

public class Constants: NSObject {
    @objc public static let notificationReceived = "com.savoirfairelinux.notificationExtension.receivedNotification" as CFString
    @objc public static let notificationAppIsActive = "com.savoirfairelinux.jami.appActive" as CFString
    @objc public static let notificationShareExtensionIsActive = "com.savoirfairelinux.shareExtension.isActive" as CFString
    @objc public static let notificationShareExtensionResponse = "com.savoirfairelinux.shareExtension.response" as CFString
    @objc public static let notificationExtensionIsActive = "com.savoirfairelinux.notificationExtension.isActive" as CFString
    @objc public static let notificationExtensionResponse = "com.savoirfairelinux.notificationExtension.accountActive" as CFString
    @objc public static let notificationData = "notificationData"
    @objc public static let updatedConversations = "updatedConversations"
    @objc public static let queriedAccountId = "queriedAccountId"
    @objc public static let shareExtensionActiveAccounts = "shareExtensionActiveAccounts"
    @objc public static let appGroupIdentifier = "group.com.savoirfairelinux.ring"
    @objc public static let notificationsCount = "notificationsCount"
    @objc public static let appIdentifier = "com.savoirfairelinux.jami"

    public static let selectedAccountID = "SELECTED_ACCOUNT_ID"

    @objc public static let documentsPath: URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("Documents")
    }()

    @objc public static let cachesPath: URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("Library").appendingPathComponent("Caches")
    }()

    @objc public static let versionNumber: String? = {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }()

    @objc public static let buildNumber: String? = {
        let dateDefault = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYYMMdd"
        let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
        if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
           let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
           let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date {
            return dateFormatter.string(from: infoDate)
        }
        return dateDefault
    }()

    @objc public static let fullVersion: String? = {
        if let versionNumber:String = Constants.versionNumber,
           let buildNumber = Constants.buildNumber {
            return "\(versionNumber)(\(buildNumber))"
        }
        return nil
    }()

    enum NotificationUserInfoKeys: String {
        case callID
        case name
        case messageContent
        case participantID
        case accountID
        case conversationID
        case callURI
    }

    enum NotificationCategory: String {
        case call = "CALL_CATEGORY"
    }

    enum NotificationAction: String {
        case answerVideo = "GROUP_ANSWER_VIDEO_ACTION"
        case answerAudio = "GROUP_ANSWER_AUDIO_ACTION"
    }

    enum NotificationActionIcon: String {
        case video = "video.fill"
        case audio = "phone.fill"
    }

    enum NotificationActionTitle {
        case answerWithVideo
        case answerWithAudio

        func toString() -> String {
            switch self {
                case .answerWithVideo:
                    return L10n.Calls.acceptWithVideo
                case .answerWithAudio:
                    return L10n.Calls.acceptWithAudio
            }
        }
    }
    
    public static let swarmColors: [String: String] = [
        "#E91E63": L10n.SwarmColors.vibrantPink,
        "#9C27B0": L10n.SwarmColors.purple,
        "#673AB7": L10n.SwarmColors.violet,
        "#3F51B5": L10n.SwarmColors.indigoBlue,
        "#2196F3": L10n.SwarmColors.skyBlue,
        "#00BCD4": L10n.SwarmColors.cyan,
        "#009688": L10n.SwarmColors.teal,
        "#4CAF50": L10n.SwarmColors.green,
        "#8BC34A": L10n.SwarmColors.limeGreen,
        "#9E9E9E": L10n.SwarmColors.mediumGray,
        "#CDDC39": L10n.SwarmColors.yellowGreen,
        "#FFC107": L10n.SwarmColors.amber,
        "#FF5722": L10n.SwarmColors.brightOrange,
        "#795548": L10n.SwarmColors.brown,
        "#607D8B": L10n.SwarmColors.steelBlue
    ]

    public static let MAX_PROFILE_IMAGE_SIZE: CGFloat = 512

    enum AvatarSize: CGFloat {
        case conversation20 = 20
        case conversation30 = 30
        case medium40 = 40
        case default55 = 55
        case conversationInfo80 = 80
        case call160 = 160
        case account100 = 100
        case account60 = 60
        case account28 = 28

        var points: CGFloat { rawValue }
    }

    public static let defaultAvatarSize: CGFloat = AvatarSize.default55.points

    public static let versionName = "Atlas"
}
