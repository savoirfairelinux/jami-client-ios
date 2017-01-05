/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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
    case Mailbox = "Account.mailbox"
    case RegistrationExpire = "Account.registrationExpire"
    case CredentialNumber = "Credential.count"
    case AccountDTMFType = "Account.dtmfType"
    case RingtonePath = "Account.ringtonePath"
    case RingtoneEnabled = "Account.ringtoneEnabled"
    case KeepAliveEnabled = "Account.keepAliveEnabled"
    case LocalInterface = "Account.localInterface"
    case PublishedSameAsLocal = "Account.publishedSameAsLocal"
    case LocalPort = "Account.localPort"
    case PublishedPort = "Account.publishedPort"
    case PublishedAddress = "Account.publishedAddress"
    case StunServer = "STUN.server"
    case StunEnable = "STUN.enable"
    case TurnServer = "TURN.server"
    case TurnEnable = "TURN.enable"
    case TurnUsername = "TURN.username"
    case TurnPassword = "TURN.password"
    case TurnRealm = "TURN.realm"
    case AudioPortMin = "Account.audioPortMin"
    case AudioPortMax = "Account.audioPortMax"
    case AccountUserAgent = "Account.useragent"
    case AccountUpnpEnabled = "Account.upnpEnabled"
    case AccountRouteSet = "Account.routeset"
    case AccountAutoAnswer = "Account.autoAnswer"
    case AccountAlias = "Account.alias"
    case AccountHostname = "Account.hostname"
    case AccountUsername = "Account.username"
    case AccountPassword = "Account.password"
    case AccountRealm = "Account.realm"
    case AccountType = "Account.type"
    case AccountEnable = "Account.enable"
    case AccountActive = "Account.active"
    case AccountDeviceId = "Account.deviceID"
    case VideoEnabled = "Account.videoEnabled"
    case VideoPortMin = "Account.videoPortMin"
    case VideoPortMax = "Account.videoPortMax"
    case PresenceEnabled = "Account.presenceEnabled"
    case ArchivePassword = "Account.archivePassword"
    case ArchivePIN = "Account.archivePIN"
    case DisplayName = "Account.displayName"
    case EthAccount = "ETH.account"
    case TLSListenerPort = "TLS.listenerPort"
    case TLSEnable = "TLS.enable"
    case TLSCaListFile = "TLS.certificateListFile"
    case TLSPrivateKeyFile = "TLS.privateKeyFile"
    case TLSPassword = "TLS.password"
    case TLSMethod = "TLS.method"
    case TLSCiphers = "TLS.ciphers"
    case TLSServerName = "TLS.serverName"
    case TLSVerifyServer = "TLS.verifyServer"
    case TLSVerifyClient = "TLS.verifyClient"
    case TLSRequireClientCertificate = "TLS.requireClientCertificate"
    case TLSNegociationTimeoutSec = "TLS.negotiationTimeoutSec"
    case AccountRegisteredName = "Account.registredName"
    case AccountRegistrationStatus = "Account.registrationStatus"
    case AccountRegistrationStateCode = "Account.registrationCode"
    case AccountRegistrationStateDesc = "Account.registrationDescription"
    case SRTPEnable = "SRTP.enable"
    case SRTPKeyExchange = "SRTP.keyExchange"
    case SRTPEncryptionAlgo = "SRTP.encryptionAlgorithm"
    case SRTPRTPFallback = "SRTP.rtpFallback"
    case RingNsAccount = "RingNS.account"
    case RingNsHost = "RingNS.host"
    case DHTPort = "DHT.port"
    case DHTPublicIn = "DHT.PublicInCalls"
    case AccountAllowCertFromHistory = "Account.allowCertFromHistory"
    case AccountAllowCertFromTrusted = "Account.allowCertFromTrusted"
    case AccountAllowCertFromContact = "Account.allowCertFromContact"
    case AccountHasCustomUserAgent = "Account.hasCustomUserAgent"
    case AccountActiveCallLimit = "Account.activeCallLimit"
    case TLSCertificateFile = "TLS.certificateFile"
    case RingNsURI = "RingNS.uri"
    case AccountPresenceSubscribeSupported = "Account.presenceSubscribeSupported"
    case AccountDeviceName = "Account.deviceName"
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
    let twoStates: Array<ConfigKey> = [.AccountEnable,
                                       .VideoEnabled,
                                       .RingtoneEnabled,
                                       .KeepAliveEnabled,
                                       .PublishedSameAsLocal,
                                       .StunEnable,
                                       .TurnEnable,
                                       .AccountAutoAnswer,
                                       .AccountUpnpEnabled]

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
    var hashValue: Int {
        return key.hashValue
    }

    /**
     Operator override.

     - Returns: true if the ConfigKeyModel is considered as TwoStates, false otherwise.
     */
    static func == (lhs: ConfigKeyModel, rhs: ConfigKeyModel) -> Bool {
        return lhs.key == rhs.key
    }
}
