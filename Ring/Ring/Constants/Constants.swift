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
Adrien Béraud
Albert Babí
Alexander Lussier-Cullen
Alexandr Sergheev
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
Charlotte Hoffmann
Cyrille Béraud
Dorina Mosku
Eden Abitbol
Edric Milaret
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
Julien Grossholtz
Kateryna Kostiuk
Kessler Dupont-Teevin
Léo Banno-Cloutier
Liam Courdoson
Loïc Siret
Marianne Forget
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
Vsevolod Ivanov
Xavier Jouslin de Noray
Yang Wang
"""

let contributorsArts: String = """
Charlotte Hoffman
Marianne Forget
"""

public class Constants: NSObject {
    @objc public static let notificationReceived = "com.savoirfairelinux.notificationExtension.receivedNotification" as CFString
    @objc public static let notificationAppIsActive = "com.savoirfairelinux.jami.appActive" as CFString
    @objc public static let notificationAppBecomeActive = "com.savoirfairelinux.jami.appBecomeActive" as CFString
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

    public static let swarmColors: [String] = ["#E91E63",
                                               "#9C27B0",
                                               "#673AB7",
                                               "#3F51B5",
                                               "#2196F3",
                                               "#00BCD4",
                                               "#009688",
                                               "#4CAF50",
                                               "#8BC34A",
                                               "#9E9E9E",
                                               "#CDDC39",
                                               "#FFC107",
                                               "#FF5722",
                                               "#795548",
                                               "#607D8B"]
    public static let MAX_PROFILE_IMAGE_SIZE: CGFloat = 512

    public static let versionName = "Εἰρήνη"
}
