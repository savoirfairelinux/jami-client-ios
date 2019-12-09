/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

/**
 The different configuration keys handled by Ring.
 */
enum ConfigKey: String {
    case mailbox = "Account.mailbox"
    case registrationExpire = "Account.registrationExpire"
    case credentialNumber = "Credential.count"
    case accountDTMFType = "Account.dtmfType"
    case ringtonePath = "Account.ringtonePath"
    case ringtoneEnabled = "Account.ringtoneEnabled"
    case keepAliveEnabled = "Account.keepAliveEnabled"
    case localInterface = "Account.localInterface"
    case publishedSameAsLocal = "Account.publishedSameAsLocal"
    case localPort = "Account.localPort"
    case publishedPort = "Account.publishedPort"
    case publishedAddress = "Account.publishedAddress"
    case stunServer = "STUN.server"
    case stunEnable = "STUN.enable"
    case turnServer = "TURN.server"
    case turnEnable = "TURN.enable"
    case turnUsername = "TURN.username"
    case turnPassword = "TURN.password"
    case turnRealm = "TURN.realm"
    case audioPortMin = "Account.audioPortMin"
    case audioPortMax = "Account.audioPortMax"
    case accountUserAgent = "Account.useragent"
    case accountUpnpEnabled = "Account.upnpEnabled"
    case accountRouteSet = "Account.routeset"
    case accountAutoAnswer = "Account.autoAnswer"
    case accountAlias = "Account.alias"
    case accountHostname = "Account.hostname"
    case accountUsername = "Account.username"
    case accountPassword = "Account.password"
    case accountRealm = "Account.realm"
    case accountType = "Account.type"
    case accountEnable = "Account.enable"
    case accountActive = "Account.active"
    case accountDeviceId = "Account.deviceID"
    case videoEnabled = "Account.videoEnabled"
    case videoPortMin = "Account.videoPortMin"
    case videoPortMax = "Account.videoPortMax"
    case presenceEnabled = "Account.presenceEnabled"
    case archivePassword = "Account.archivePassword"
    case archivePIN = "Account.archivePIN"
    case displayName = "Account.displayName"
    case ethAccount = "ETH.account"
    case tlsListenerPort = "TLS.listenerPort"
    case tlsEnable = "TLS.enable"
    case tlsCaListFile = "TLS.certificateListFile"
    case tlsPrivateKeyFile = "TLS.privateKeyFile"
    case tlsPassword = "TLS.password"
    case tlsMethod = "TLS.method"
    case tlsCiphers = "TLS.ciphers"
    case tlsServerName = "TLS.serverName"
    case tlsVerifyServer = "TLS.verifyServer"
    case tlsVerifyClient = "TLS.verifyClient"
    case tlsRequireClientCertificate = "TLS.requireClientCertificate"
    case tlsNegociationTimeoutSec = "TLS.negotiationTimeoutSec"
    case accountRegisteredName = "Account.registredName"
    case accountRegistrationStatus = "Account.registrationStatus"
    case accountRegistrationStateCode = "Account.registrationCode"
    case accountRegistrationStateDesc = "Account.registrationDescription"
    case srtpEnable = "SRTP.enable"
    case srtpKeyExchange = "SRTP.keyExchange"
    case srtpEncryptionAlgo = "SRTP.encryptionAlgorithm"
    case srtpRTPFallback = "SRTP.rtpFallback"
    case ringNsAccount = "RingNS.account"
    case ringNsHost = "RingNS.host"
    case dhtPort = "DHT.port"
    case dhtPublicIn = "DHT.PublicInCalls"
    case accountAllowCertFromHistory = "Account.allowCertFromHistory"
    case accountAllowCertFromTrusted = "Account.allowCertFromTrusted"
    case accountAllowCertFromContact = "Account.allowCertFromContact"
    case accountHasCustomUserAgent = "Account.hasCustomUserAgent"
    case accountActiveCallLimit = "Account.activeCallLimit"
    case tlsCertificateFile = "TLS.certificateFile"
    case ringNsURI = "RingNS.uri"
    case accountPresenceSubscribeSupported = "Account.presenceSubscribeSupported"
    case accountDeviceName = "Account.deviceName"
    case proxyEnabled = "Account.proxyEnabled"
    case proxyServer = "Account.proxyServer"
    case devicePushToken = "Account.proxyPushToken"
    case archiveHasPassword = "Account.archiveHasPassword"
    case dhtPeerDiscovery = "Account.peerDiscovery"
    case accountPeerDiscovery = "Account.accountDiscovery"
    case accountPublish = "Account.accountPublish"
    case codecQuality = "CodecInfo.quality"
    case codecType = "CodecInfo.type"
    case codecName = "CodecInfo.name"
    case codecMinQuality = "CodecInfo.min_quality"
}

/**
 A structure representing the key of a configuration element of an account.
 */
struct ConfigKeyModel: Hashable {
    /**
     The key.
     */
    let key: ConfigKey

    /**
     List of all the ConfigKeys that are considered as TwoStates configurations.
     */
    let twoStates: [ConfigKey] = [.accountEnable,
                                  .videoEnabled,
                                  .ringtoneEnabled,
                                  .keepAliveEnabled,
                                  .publishedSameAsLocal,
                                  .stunEnable,
                                  .turnEnable,
                                  .accountAutoAnswer,
                                  .accountUpnpEnabled]

    /**
     Constructor.

     - Parameter key: the key used to build the ConfigKeyModel
     */
    init(withKey key: ConfigKey) {
        self.key = key
    }

    /**
     Getter on the TwoStates attributes of a ConfigKeyModel.

     - Returns: true if the ConfigKeyModel is considered as TwoStates, false otherwise.
     */
    func isTwoState() -> Bool {
        return twoStates.contains(self.key)
    }

    // MARK: Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }

    /**
     Operator override.

     - Returns: true if the ConfigKeyModel is considered as TwoStates, false otherwise.
     */
    static func == (lhs: ConfigKeyModel, rhs: ConfigKeyModel) -> Bool {
        return lhs.key == rhs.key
    }
}
