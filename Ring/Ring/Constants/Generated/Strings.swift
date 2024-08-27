// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  internal enum AboutJami {
    /// Artwork by
    internal static let artworkBy = L10n.tr("Localizable", "aboutJami.artworkBy", fallback: "Artwork by")
    /// Contribute
    internal static let contribute = L10n.tr("Localizable", "aboutJami.contribute", fallback: "Contribute")
    /// Created by
    internal static let createdBy = L10n.tr("Localizable", "aboutJami.createdBy", fallback: "Created by")
    /// Jami, a GNU package, is software for universal and distributed peer-to-peer communication that respects the freedom and privacy of its users. Visit
    internal static let declaration1 = L10n.tr("Localizable", "aboutJami.declaration1", fallback: "Jami, a GNU package, is software for universal and distributed peer-to-peer communication that respects the freedom and privacy of its users. Visit")
    /// to learn more.
    internal static let declaration2 = L10n.tr("Localizable", "aboutJami.declaration2", fallback: "to learn more.")
    /// Feedback
    internal static let feedback = L10n.tr("Localizable", "aboutJami.feedback", fallback: "Feedback")
    /// This program comes with absolutely no warranty. See the
    internal static let noWarranty1 = L10n.tr("Localizable", "aboutJami.noWarranty1", fallback: "This program comes with absolutely no warranty. See the")
    /// version 3 or later for details.
    internal static let noWarranty2 = L10n.tr("Localizable", "aboutJami.noWarranty2", fallback: "version 3 or later for details.")
  }
  internal enum Account {
    /// Account Status
    internal static let accountStatus = L10n.tr("Localizable", "account.accountStatus", fallback: "Account Status")
    /// Advanced Features
    internal static let advancedFeatures = L10n.tr("Localizable", "account.advancedFeatures", fallback: "Advanced Features")
    /// Configure
    internal static let configure = L10n.tr("Localizable", "account.configure", fallback: "Configure")
    /// Configure a SIP Account
    internal static let createSipAccount = L10n.tr("Localizable", "account.createSipAccount", fallback: "Configure a SIP Account")
    /// Enable Account
    internal static let enableAccount = L10n.tr("Localizable", "account.enableAccount", fallback: "Enable Account")
    /// Me
    internal static let me = L10n.tr("Localizable", "account.me", fallback: "Me")
    /// account need to be migrated
    internal static let needMigration = L10n.tr("Localizable", "account.needMigration", fallback: "account need to be migrated")
    /// Port
    internal static let port = L10n.tr("Localizable", "account.port", fallback: "Port")
    /// Enter Port Number
    internal static let portLabel = L10n.tr("Localizable", "account.portLabel", fallback: "Enter Port Number")
    /// Proxy
    internal static let proxyServer = L10n.tr("Localizable", "account.proxyServer", fallback: "Proxy")
    /// Enter Address
    internal static let serverLabel = L10n.tr("Localizable", "account.serverLabel", fallback: "Enter Address")
    /// SIP Account
    internal static let sipAccount = L10n.tr("Localizable", "account.sipAccount", fallback: "SIP Account")
    /// Server
    internal static let sipServer = L10n.tr("Localizable", "account.sipServer", fallback: "Server")
    /// Connecting
    internal static let statusConnecting = L10n.tr("Localizable", "account.statusConnecting", fallback: "Connecting")
    /// Connection Error
    internal static let statusConnectionerror = L10n.tr("Localizable", "account.statusConnectionerror", fallback: "Connection Error")
    /// Offline
    internal static let statusOffline = L10n.tr("Localizable", "account.statusOffline", fallback: "Offline")
    /// Online
    internal static let statusOnline = L10n.tr("Localizable", "account.statusOnline", fallback: "Online")
    /// Unknown
    internal static let statusUnknown = L10n.tr("Localizable", "account.statusUnknown", fallback: "Unknown")
  }
  internal enum AccountPage {
    /// Account
    internal static let accountHeader = L10n.tr("Localizable", "accountPage.accountHeader", fallback: "Account")
    /// Account identity
    internal static let accountIdentity = L10n.tr("Localizable", "accountPage.accountIdentity", fallback: "Account identity")
    /// These settings will only apply for this account
    internal static let accountSettingsExplanation = L10n.tr("Localizable", "accountPage.accountSettingsExplanation", fallback: "These settings will only apply for this account")
    /// App settings
    internal static let appSettings = L10n.tr("Localizable", "accountPage.appSettings", fallback: "App settings")
    /// These settings will apply on all the application
    internal static let appSettingsExplanation = L10n.tr("Localizable", "accountPage.appSettingsExplanation", fallback: "These settings will apply on all the application")
    /// Auto register after expiration
    internal static let autoRegistration = L10n.tr("Localizable", "accountPage.autoRegistration", fallback: "Auto register after expiration")
    /// Blocked contacts
    internal static let blockedContacts = L10n.tr("Localizable", "accountPage.blockedContacts", fallback: "Blocked contacts")
    /// After enabling booth mode all your conversations will be removed.
    internal static let boothModeAlertMessage = L10n.tr("Localizable", "accountPage.boothModeAlertMessage", fallback: "After enabling booth mode all your conversations will be removed.")
    /// In booth mode conversation history not saved and jami functionality limited by making outgoing calls. When you enable booth mode all your conversations will be removed.
    internal static let boothModeExplanation = L10n.tr("Localizable", "accountPage.boothModeExplanation", fallback: "In booth mode conversation history not saved and jami functionality limited by making outgoing calls. When you enable booth mode all your conversations will be removed.")
    /// Allow incoming calls from unknown contacts
    internal static let callsFromUnknownContacts = L10n.tr("Localizable", "accountPage.callsFromUnknownContacts", fallback: "Allow incoming calls from unknown contacts")
    /// Change password
    internal static let changePassword = L10n.tr("Localizable", "accountPage.changePassword", fallback: "Change password")
    /// Password incorrect
    internal static let changePasswordError = L10n.tr("Localizable", "accountPage.changePasswordError", fallback: "Password incorrect")
    /// Connectivity and configurations
    internal static let connectivityAndConfiguration = L10n.tr("Localizable", "accountPage.connectivityAndConfiguration", fallback: "Connectivity and configurations")
    /// Connectivity
    internal static let connectivityHeader = L10n.tr("Localizable", "accountPage.connectivityHeader", fallback: "Connectivity")
    /// Contact me using "%s" on the Jami distributed communication platform: https://jami.net
    internal static func contactMeOnJamiContant(_ p1: UnsafePointer<CChar>) -> String {
      return L10n.tr("Localizable", "accountPage.contactMeOnJamiContant", p1, fallback: "Contact me using \"%s\" on the Jami distributed communication platform: https://jami.net")
    }
    /// Contact me on Jami!
    internal static let contactMeOnJamiTitle = L10n.tr("Localizable", "accountPage.contactMeOnJamiTitle", fallback: "Contact me on Jami!")
    /// Encrypt account
    internal static let createPassword = L10n.tr("Localizable", "accountPage.createPassword", fallback: "Encrypt account")
    /// Account Details
    internal static let credentialsHeader = L10n.tr("Localizable", "accountPage.credentialsHeader", fallback: "Account Details")
    /// Device revocation error
    internal static let deviceRevocationError = L10n.tr("Localizable", "accountPage.deviceRevocationError", fallback: "Device revocation error")
    /// Removing…
    internal static let deviceRevocationProgress = L10n.tr("Localizable", "accountPage.deviceRevocationProgress", fallback: "Removing…")
    /// Device removed
    internal static let deviceRevocationSuccess = L10n.tr("Localizable", "accountPage.deviceRevocationSuccess", fallback: "Device removed")
    /// Try again
    internal static let deviceRevocationTryAgain = L10n.tr("Localizable", "accountPage.deviceRevocationTryAgain", fallback: "Try again")
    /// Unknown device
    internal static let deviceRevocationUnknownDevice = L10n.tr("Localizable", "accountPage.deviceRevocationUnknownDevice", fallback: "Unknown device")
    /// Incorrect password
    internal static let deviceRevocationWrongPassword = L10n.tr("Localizable", "accountPage.deviceRevocationWrongPassword", fallback: "Incorrect password")
    /// Device revocation completed
    internal static let deviceRevoked = L10n.tr("Localizable", "accountPage.deviceRevoked", fallback: "Device revocation completed")
    /// Devices
    internal static let devicesListHeader = L10n.tr("Localizable", "accountPage.devicesListHeader", fallback: "Devices")
    /// Disable Booth Mode
    internal static let disableBoothMode = L10n.tr("Localizable", "accountPage.disableBoothMode", fallback: "Disable Booth Mode")
    /// Please provide your account password
    internal static let disableBoothModeExplanation = L10n.tr("Localizable", "accountPage.disableBoothModeExplanation", fallback: "Please provide your account password")
    /// Edit Profile
    internal static let editProfile = L10n.tr("Localizable", "accountPage.editProfile", fallback: "Edit Profile")
    /// Expiration time
    internal static let editSipExpirationTime = L10n.tr("Localizable", "accountPage.editSipExpirationTime", fallback: "Expiration time")
    /// Enable Booth Mode
    internal static let enableBoothMode = L10n.tr("Localizable", "accountPage.enableBoothMode", fallback: "Enable Booth Mode")
    /// Enable notifications
    internal static let enableNotifications = L10n.tr("Localizable", "accountPage.enableNotifications", fallback: "Enable notifications")
    /// Encrypt media streams (SRTP)
    internal static let enableSRTP = L10n.tr("Localizable", "accountPage.enableSRTP", fallback: "Encrypt media streams (SRTP)")
    /// Encrypt account with a password
    internal static let encryptAccount = L10n.tr("Localizable", "accountPage.encryptAccount", fallback: "Encrypt account with a password")
    /// Generating PIN…
    internal static let generatingPin = L10n.tr("Localizable", "accountPage.generatingPin", fallback: "Generating PIN…")
    /// Invite friends
    internal static let inviteFriends = L10n.tr("Localizable", "accountPage.inviteFriends", fallback: "Invite friends")
    /// Link another device
    internal static let linkDeviceTitle = L10n.tr("Localizable", "accountPage.linkDeviceTitle", fallback: "Link another device")
    /// Linked devices
    internal static let linkedDevices = L10n.tr("Localizable", "accountPage.linkedDevices", fallback: "Linked devices")
    /// Manage account
    internal static let manageAccount = L10n.tr("Localizable", "accountPage.manageAccount", fallback: "Manage account")
    /// Confirm new password
    internal static let newPasswordConfirmPlaceholder = L10n.tr("Localizable", "accountPage.newPasswordConfirmPlaceholder", fallback: "Confirm new password")
    /// Enter new password
    internal static let newPasswordPlaceholder = L10n.tr("Localizable", "accountPage.newPasswordPlaceholder", fallback: "Enter new password")
    /// To enable Booth mode encrypt your account first.
    internal static let noBoothMode = L10n.tr("Localizable", "accountPage.noBoothMode", fallback: "To enable Booth mode encrypt your account first.")
    /// Your device won't receive notifications when proxy is disabled
    internal static let noProxyExplanationLabel = L10n.tr("Localizable", "accountPage.noProxyExplanationLabel", fallback: "Your device won't receive notifications when proxy is disabled")
    /// Notifications for Jami are disabled. Please enable them in your device settings
    internal static let notificationError = L10n.tr("Localizable", "accountPage.notificationError", fallback: "Notifications for Jami are disabled. Please enable them in your device settings")
    /// Notifications
    internal static let notificationsHeader = L10n.tr("Localizable", "accountPage.notificationsHeader", fallback: "Notifications")
    /// Notifications
    internal static let notificationTitle = L10n.tr("Localizable", "accountPage.notificationTitle", fallback: "Notifications")
    /// Enter old password
    internal static let oldPasswordPlaceholder = L10n.tr("Localizable", "accountPage.oldPasswordPlaceholder", fallback: "Enter old password")
    /// Other
    internal static let other = L10n.tr("Localizable", "accountPage.other", fallback: "Other")
    /// Other linked devices
    internal static let otherDevices = L10n.tr("Localizable", "accountPage.otherDevices", fallback: "Other linked devices")
    /// Password created
    internal static let passwordCreated = L10n.tr("Localizable", "accountPage.passwordCreated", fallback: "Password created")
    /// Your Jami account is only stored locally on this device as an archive containing your accoutn keys. Access to this archive can be protected by a password.
    internal static let passwordExplanation = L10n.tr("Localizable", "accountPage.passwordExplanation", fallback: "Your Jami account is only stored locally on this device as an archive containing your accoutn keys. Access to this archive can be protected by a password.")
    /// This account is password encrypted, enter a password to generate PIN code
    internal static let passwordForPin = L10n.tr("Localizable", "accountPage.passwordForPin", fallback: "This account is password encrypted, enter a password to generate PIN code")
    /// Enter account password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "accountPage.passwordPlaceholder", fallback: "Enter account password")
    /// Passwords do not match
    internal static let passwordsDoNotMatch = L10n.tr("Localizable", "accountPage.passwordsDoNotMatch", fallback: "Passwords do not match")
    /// Password updated
    internal static let passwordUpdated = L10n.tr("Localizable", "accountPage.passwordUpdated", fallback: "Password updated")
    /// Enable local peer discovery
    internal static let peerDiscovery = L10n.tr("Localizable", "accountPage.peerDiscovery", fallback: "Enable local peer discovery")
    /// Connect to other DHT nodes advertising on our local network
    internal static let peerDiscoveryExplanation = L10n.tr("Localizable", "accountPage.peerDiscoveryExplanation", fallback: "Connect to other DHT nodes advertising on our local network")
    /// Failed to generate PIN
    internal static let pinError = L10n.tr("Localizable", "accountPage.pinError", fallback: "Failed to generate PIN")
    /// Install and launch Jami, select import from another device and scan QR code or manually enter the PIN.
    internal static let pinExplanationMessage = L10n.tr("Localizable", "accountPage.pinExplanationMessage", fallback: "Install and launch Jami, select import from another device and scan QR code or manually enter the PIN.")
    /// On another device
    internal static let pinExplanationTitle = L10n.tr("Localizable", "accountPage.pinExplanationTitle", fallback: "On another device")
    /// Profile
    internal static let profileHeader = L10n.tr("Localizable", "accountPage.profileHeader", fallback: "Profile")
    /// Profile name
    internal static let profileName = L10n.tr("Localizable", "accountPage.profileName", fallback: "Profile name")
    /// Name not selected
    internal static let profileNameNotSelected = L10n.tr("Localizable", "accountPage.profileNameNotSelected", fallback: "Name not selected")
    /// Enter profile name
    internal static let profileNamePlaceholder = L10n.tr("Localizable", "accountPage.profileNamePlaceholder", fallback: "Enter profile name")
    /// Provide proxy address
    internal static let proxyAddressAlert = L10n.tr("Localizable", "accountPage.proxyAddressAlert", fallback: "Provide proxy address")
    /// In order to receive notifications, please enable proxy
    internal static let proxyDisabledAlertBody = L10n.tr("Localizable", "accountPage.proxyDisabledAlertBody", fallback: "In order to receive notifications, please enable proxy")
    /// Proxy Server Disabled
    internal static let proxyDisabledAlertTitle = L10n.tr("Localizable", "accountPage.proxyDisabledAlertTitle", fallback: "Proxy Server Disabled")
    /// Notifications are routed through a proxy. You can either use the default proxy, enter a custom proxy address, or provide a URL with a list of proxies.
    internal static let proxyExplanation = L10n.tr("Localizable", "accountPage.proxyExplanation", fallback: "Notifications are routed through a proxy. You can either use the default proxy, enter a custom proxy address, or provide a URL with a list of proxies.")
    /// Proxy
    internal static let proxyHeader = L10n.tr("Localizable", "accountPage.proxyHeader", fallback: "Proxy")
    /// Proxy list URL
    internal static let proxyListURL = L10n.tr("Localizable", "accountPage.proxyListURL", fallback: "Proxy list URL")
    /// Proxy address
    internal static let proxyPaceholder = L10n.tr("Localizable", "accountPage.proxyPaceholder", fallback: "Proxy address")
    /// Chosen username is not available
    internal static let registerNameErrorMessage = L10n.tr("Localizable", "accountPage.registerNameErrorMessage", fallback: "Chosen username is not available")
    /// Register a username to help others more easily find and reach you on Jami.
    internal static let registerNameExplanation = L10n.tr("Localizable", "accountPage.registerNameExplanation", fallback: "Register a username to help others more easily find and reach you on Jami.")
    /// If your account has not been backed up or added to another device, your account and registered name will be irrevocably lost.
    internal static let removeAccountMessage = L10n.tr("Localizable", "accountPage.removeAccountMessage", fallback: "If your account has not been backed up or added to another device, your account and registered name will be irrevocably lost.")
    /// Remove device
    internal static let removeDeviceTitle = L10n.tr("Localizable", "accountPage.removeDeviceTitle", fallback: "Remove device")
    /// Revoke
    internal static let revokeDeviceButton = L10n.tr("Localizable", "accountPage.revokeDeviceButton", fallback: "Revoke")
    /// Are you sure you want to remove this device? This action cannot be undone.
    internal static let revokeDeviceMessage = L10n.tr("Localizable", "accountPage.revokeDeviceMessage", fallback: "Are you sure you want to remove this device? This action cannot be undone.")
    /// Enter your password
    internal static let revokeDevicePlaceholder = L10n.tr("Localizable", "accountPage.revokeDevicePlaceholder", fallback: "Enter your password")
    /// Security
    internal static let security = L10n.tr("Localizable", "accountPage.security", fallback: "Security")
    /// Set time (in seconds) for registration expiration
    internal static let selectSipExpirationTime = L10n.tr("Localizable", "accountPage.selectSipExpirationTime", fallback: "Set time (in seconds) for registration expiration")
    /// Settings
    internal static let settingsHeader = L10n.tr("Localizable", "accountPage.settingsHeader", fallback: "Settings")
    /// Registration expiration time (seconds)
    internal static let sipExpirationTime = L10n.tr("Localizable", "accountPage.sipExpirationTime", fallback: "Registration expiration time (seconds)")
    /// This device
    internal static let thisDevice = L10n.tr("Localizable", "accountPage.thisDevice", fallback: "This device")
    /// Disable secure dialog check for incoming TLS data
    internal static let tlsDisableSecureDlgCheck = L10n.tr("Localizable", "accountPage.tlsDisableSecureDlgCheck", fallback: "Disable secure dialog check for incoming TLS data")
    /// Require a certificate for incoming TLS connections
    internal static let tlsRequireTlsCertificate = L10n.tr("Localizable", "accountPage.tlsRequireTlsCertificate", fallback: "Require a certificate for incoming TLS connections")
    /// Verify client TLS certificates
    internal static let tlsVerifyClientCertificates = L10n.tr("Localizable", "accountPage.tlsVerifyClientCertificates", fallback: "Verify client TLS certificates")
    /// Verify server TLS certificates
    internal static let tlsVerifyServerCertificates = L10n.tr("Localizable", "accountPage.tlsVerifyServerCertificates", fallback: "Verify server TLS certificates")
    /// Enable TURN
    internal static let turnEnabled = L10n.tr("Localizable", "accountPage.turnEnabled", fallback: "Enable TURN")
    /// TURN password
    internal static let turnPassword = L10n.tr("Localizable", "accountPage.turnPassword", fallback: "TURN password")
    /// TURN realm
    internal static let turnRealm = L10n.tr("Localizable", "accountPage.turnRealm", fallback: "TURN realm")
    /// TURN address
    internal static let turnServer = L10n.tr("Localizable", "accountPage.turnServer", fallback: "TURN address")
    /// TURN username
    internal static let turnUsername = L10n.tr("Localizable", "accountPage.turnUsername", fallback: "TURN username")
    /// UNBLOCK
    internal static let unblockContact = L10n.tr("Localizable", "accountPage.unblockContact", fallback: "UNBLOCK")
    /// Unlink
    internal static let unlink = L10n.tr("Localizable", "accountPage.unlink", fallback: "Unlink")
    /// Use UPnP
    internal static let upnpEnabled = L10n.tr("Localizable", "accountPage.upnpEnabled", fallback: "Use UPnP")
    /// Use proxy list
    internal static let useProxyList = L10n.tr("Localizable", "accountPage.useProxyList", fallback: "Use proxy list")
    /// username: not registered
    internal static let usernameNotRegistered = L10n.tr("Localizable", "accountPage.usernameNotRegistered", fallback: "username: not registered")
    /// Enter desired username
    internal static let usernamePlaceholder = L10n.tr("Localizable", "accountPage.usernamePlaceholder", fallback: "Enter desired username")
    /// Register
    internal static let usernameRegisterAction = L10n.tr("Localizable", "accountPage.usernameRegisterAction", fallback: "Register")
    /// Registering
    internal static let usernameRegistering = L10n.tr("Localizable", "accountPage.usernameRegistering", fallback: "Registering")
    /// Please check your password.
    internal static let usernameRegistrationFailed = L10n.tr("Localizable", "accountPage.usernameRegistrationFailed", fallback: "Please check your password.")
    /// Registration Failed
    internal static let usernameRegistrationFailedTitle = L10n.tr("Localizable", "accountPage.usernameRegistrationFailedTitle", fallback: "Registration Failed")
  }
  internal enum Actions {
    /// Back
    internal static let backAction = L10n.tr("Localizable", "actions.backAction", fallback: "Back")
    /// Clear
    internal static let clearAction = L10n.tr("Localizable", "actions.clearAction", fallback: "Clear")
    /// Delete
    internal static let deleteAction = L10n.tr("Localizable", "actions.deleteAction", fallback: "Delete")
    /// Done
    internal static let doneAction = L10n.tr("Localizable", "actions.doneAction", fallback: "Done")
    /// Go to Settings
    internal static let goToSettings = L10n.tr("Localizable", "actions.goToSettings", fallback: "Go to Settings")
    ///   Audio Call
    internal static let startAudioCall = L10n.tr("Localizable", "actions.startAudioCall", fallback: "  Audio Call")
    ///   Video Call
    internal static let startVideoCall = L10n.tr("Localizable", "actions.startVideoCall", fallback: "  Video Call")
    /// Stop sharing
    internal static let stopLocationSharing = L10n.tr("Localizable", "actions.stopLocationSharing", fallback: "Stop sharing")
  }
  internal enum Alerts {
    /// Account Added
    internal static let accountAddedTitle = L10n.tr("Localizable", "alerts.accountAddedTitle", fallback: "Account Added")
    /// Account couldn't be found on the Jami network. Make sure it was exported on Jami from an existing device, and that provided credentials are correct.
    internal static let accountCannotBeFoundMessage = L10n.tr("Localizable", "alerts.accountCannotBeFoundMessage", fallback: "Account couldn't be found on the Jami network. Make sure it was exported on Jami from an existing device, and that provided credentials are correct.")
    /// Can't find account
    internal static let accountCannotBeFoundTitle = L10n.tr("Localizable", "alerts.accountCannotBeFoundTitle", fallback: "Can't find account")
    /// The account couldn't be created.
    internal static let accountDefaultErrorMessage = L10n.tr("Localizable", "alerts.accountDefaultErrorMessage", fallback: "The account couldn't be created.")
    /// Unknown error
    internal static let accountDefaultErrorTitle = L10n.tr("Localizable", "alerts.accountDefaultErrorTitle", fallback: "Unknown error")
    /// Linking account
    internal static let accountLinkedTitle = L10n.tr("Localizable", "alerts.accountLinkedTitle", fallback: "Linking account")
    /// Could not add account because Jami couldn't connect to the distributed network. Check your device connectivity.
    internal static let accountNoNetworkMessage = L10n.tr("Localizable", "alerts.accountNoNetworkMessage", fallback: "Could not add account because Jami couldn't connect to the distributed network. Check your device connectivity.")
    /// Can't connect to the network
    internal static let accountNoNetworkTitle = L10n.tr("Localizable", "alerts.accountNoNetworkTitle", fallback: "Can't connect to the network")
    /// Already sharing location with this user
    internal static let alreadylocationSharing = L10n.tr("Localizable", "alerts.alreadylocationSharing", fallback: "Already sharing location with this user")
    /// Are you sure you want to block this contact? The conversation history with this contact will also be deleted permanently.
    internal static let confirmBlockContact = L10n.tr("Localizable", "alerts.confirmBlockContact", fallback: "Are you sure you want to block this contact? The conversation history with this contact will also be deleted permanently.")
    /// Are you sure you want to clear the conversation with this contact?
    internal static let confirmClearConversation = L10n.tr("Localizable", "alerts.confirmClearConversation", fallback: "Are you sure you want to clear the conversation with this contact?")
    /// Clear Conversation
    internal static let confirmClearConversationTitle = L10n.tr("Localizable", "alerts.confirmClearConversationTitle", fallback: "Clear Conversation")
    /// Are you sure you want to delete this conversation permanently?
    internal static let confirmDeleteConversation = L10n.tr("Localizable", "alerts.confirmDeleteConversation", fallback: "Are you sure you want to delete this conversation permanently?")
    /// Are you sure you want to delete the conversation with this contact?
    internal static let confirmDeleteConversationFromContact = L10n.tr("Localizable", "alerts.confirmDeleteConversationFromContact", fallback: "Are you sure you want to delete the conversation with this contact?")
    /// Delete Conversation
    internal static let confirmDeleteConversationTitle = L10n.tr("Localizable", "alerts.confirmDeleteConversationTitle", fallback: "Delete Conversation")
    /// Please close application and try to open it again
    internal static let dbFailedMessage = L10n.tr("Localizable", "alerts.dbFailedMessage", fallback: "Please close application and try to open it again")
    /// An error happened when launching Jami
    internal static let dbFailedTitle = L10n.tr("Localizable", "alerts.dbFailedTitle", fallback: "An error happened when launching Jami")
    /// Cannot connect to provided account manager. Please check your credentials
    internal static let errorWrongCredentials = L10n.tr("Localizable", "alerts.errorWrongCredentials", fallback: "Cannot connect to provided account manager. Please check your credentials")
    /// Incoming call from 
    internal static let incomingCallAllertTitle = L10n.tr("Localizable", "alerts.incomingCallAllertTitle", fallback: "Incoming call from ")
    /// Ignore
    internal static let incomingCallButtonIgnore = L10n.tr("Localizable", "alerts.incomingCallButtonIgnore", fallback: "Ignore")
    /// Turn on "Location Services" to allow "Jami" to determine your location.
    internal static let locationServiceIsDisabled = L10n.tr("Localizable", "alerts.locationServiceIsDisabled", fallback: "Turn on \"Location Services\" to allow \"Jami\" to determine your location.")
    /// Share my location
    internal static let locationSharing = L10n.tr("Localizable", "alerts.locationSharing", fallback: "Share my location")
    /// 10 min
    internal static let locationSharingDuration10min = L10n.tr("Localizable", "alerts.locationSharingDuration10min", fallback: "10 min")
    /// 1 hour
    internal static let locationSharingDuration1hour = L10n.tr("Localizable", "alerts.locationSharingDuration1hour", fallback: "1 hour")
    /// How long should the location sharing be?
    internal static let locationSharingDurationTitle = L10n.tr("Localizable", "alerts.locationSharingDurationTitle", fallback: "How long should the location sharing be?")
    /// Map information
    internal static let mapInformation = L10n.tr("Localizable", "alerts.mapInformation", fallback: "Map information")
    /// Access to photo library not granted
    internal static let noLibraryPermissionsTitle = L10n.tr("Localizable", "alerts.noLibraryPermissionsTitle", fallback: "Access to photo library not granted")
    /// Access to location not granted
    internal static let noLocationPermissionsTitle = L10n.tr("Localizable", "alerts.noLocationPermissionsTitle", fallback: "Access to location not granted")
    /// Media permission not granted
    internal static let noMediaPermissionsTitle = L10n.tr("Localizable", "alerts.noMediaPermissionsTitle", fallback: "Media permission not granted")
    /// © OpenStreetMap contributors
    internal static let openStreetMapCopyright = L10n.tr("Localizable", "alerts.openStreetMapCopyright", fallback: "© OpenStreetMap contributors")
    /// Learn more
    internal static let openStreetMapCopyrightMoreInfo = L10n.tr("Localizable", "alerts.openStreetMapCopyrightMoreInfo", fallback: "Learn more")
    /// Take photo
    internal static let profileTakePhoto = L10n.tr("Localizable", "alerts.profileTakePhoto", fallback: "Take photo")
    /// Upload photo
    internal static let profileUploadPhoto = L10n.tr("Localizable", "alerts.profileUploadPhoto", fallback: "Upload photo")
    /// Record an audio message
    internal static let recordAudioMessage = L10n.tr("Localizable", "alerts.recordAudioMessage", fallback: "Record an audio message")
    /// Record a video message
    internal static let recordVideoMessage = L10n.tr("Localizable", "alerts.recordVideoMessage", fallback: "Record a video message")
    /// Send file
    internal static let uploadFile = L10n.tr("Localizable", "alerts.uploadFile", fallback: "Send file")
    /// Open gallery
    internal static let uploadPhoto = L10n.tr("Localizable", "alerts.uploadPhoto", fallback: "Open gallery")
  }
  internal enum BackupAccount {
    /// Select a name for the archive.
    internal static let archiveName = L10n.tr("Localizable", "backupAccount.archiveName", fallback: "Select a name for the archive.")
    /// Archive name
    internal static let archiveNamePlaceholder = L10n.tr("Localizable", "backupAccount.archiveNamePlaceholder", fallback: "Archive name")
    /// Backup
    internal static let backupButton = L10n.tr("Localizable", "backupAccount.backupButton", fallback: "Backup")
    /// Creating backup
    internal static let creating = L10n.tr("Localizable", "backupAccount.creating", fallback: "Creating backup")
    /// Open backup location
    internal static let documentPickerButton = L10n.tr("Localizable", "backupAccount.documentPickerButton", fallback: "Open backup location")
    /// Access to the selected location was denied.
    internal static let errorAccessDenied = L10n.tr("Localizable", "backupAccount.errorAccessDenied", fallback: "Access to the selected location was denied.")
    /// The export operation failed.
    internal static let errorFailed = L10n.tr("Localizable", "backupAccount.errorFailed", fallback: "The export operation failed.")
    /// The selected file path is invalid. Please choose a different location.
    internal static let errorWrongLocation = L10n.tr("Localizable", "backupAccount.errorWrongLocation", fallback: "The selected file path is invalid. Please choose a different location.")
    /// This Jami account exists only on this device. The account will be lost if this device is lost or if the application is uninstalled. It is recommended to make a backup of this account.
    internal static let explanation = L10n.tr("Localizable", "backupAccount.explanation", fallback: "This Jami account exists only on this device. The account will be lost if this device is lost or if the application is uninstalled. It is recommended to make a backup of this account.")
    /// Backup created
    internal static let exportSuccess = L10n.tr("Localizable", "backupAccount.exportSuccess", fallback: "Backup created")
    /// Enter the password used to encrypt the account.
    internal static let passwordRequest = L10n.tr("Localizable", "backupAccount.passwordRequest", fallback: "Enter the password used to encrypt the account.")
    /// Backup account
    internal static let title = L10n.tr("Localizable", "backupAccount.title", fallback: "Backup account")
  }
  internal enum BlockListPage {
    /// No blocked contacts
    internal static let noBlockedContacts = L10n.tr("Localizable", "blockListPage.noBlockedContacts", fallback: "No blocked contacts")
  }
  internal enum Calls {
    /// Call finished
    internal static let callFinished = L10n.tr("Localizable", "calls.callFinished", fallback: "Call finished")
    /// Connecting…
    internal static let connecting = L10n.tr("Localizable", "calls.connecting", fallback: "Connecting…")
    /// Call with 
    internal static let currentCallWith = L10n.tr("Localizable", "calls.currentCallWith", fallback: "Call with ")
    /// hang up
    internal static let haghUp = L10n.tr("Localizable", "calls.haghUp", fallback: "hang up")
    /// wants to talk to you
    internal static let incomingCallInfo = L10n.tr("Localizable", "calls.incomingCallInfo", fallback: "wants to talk to you")
    /// lower hand
    internal static let lowerHand = L10n.tr("Localizable", "calls.lowerHand", fallback: "lower hand")
    /// maximize
    internal static let maximize = L10n.tr("Localizable", "calls.maximize", fallback: "maximize")
    /// minimize
    internal static let minimize = L10n.tr("Localizable", "calls.minimize", fallback: "minimize")
    /// mute audio
    internal static let muteAudio = L10n.tr("Localizable", "calls.muteAudio", fallback: "mute audio")
    /// unset moderator
    internal static let removeModerator = L10n.tr("Localizable", "calls.removeModerator", fallback: "unset moderator")
    /// Ringing…
    internal static let ringing = L10n.tr("Localizable", "calls.ringing", fallback: "Ringing…")
    /// set moderator
    internal static let setModerator = L10n.tr("Localizable", "calls.setModerator", fallback: "set moderator")
    /// unmute audio
    internal static let unmuteAudio = L10n.tr("Localizable", "calls.unmuteAudio", fallback: "unmute audio")
  }
  internal enum ContactPage {
    /// Clear Chat
    internal static let clearConversation = L10n.tr("Localizable", "contactPage.clearConversation", fallback: "Clear Chat")
    /// Remove Conversation
    internal static let removeConversation = L10n.tr("Localizable", "contactPage.removeConversation", fallback: "Remove Conversation")
    /// Send Message
    internal static let sendMessage = L10n.tr("Localizable", "contactPage.sendMessage", fallback: "Send Message")
    /// Start Audio Call
    internal static let startAudioCall = L10n.tr("Localizable", "contactPage.startAudioCall", fallback: "Start Audio Call")
    /// Start Video Call
    internal static let startVideoCall = L10n.tr("Localizable", "contactPage.startVideoCall", fallback: "Start Video Call")
  }
  internal enum Conversation {
    /// Add to Contacts
    internal static let addToContactsButton = L10n.tr("Localizable", "conversation.addToContactsButton", fallback: "Add to Contacts")
    /// Add to contacts?
    internal static let addToContactsLabel = L10n.tr("Localizable", "conversation.addToContactsLabel", fallback: "Add to contacts?")
    /// deleted a message
    internal static let deletedMessage = L10n.tr("Localizable", "conversation.deletedMessage", fallback: "deleted a message")
    /// edited
    internal static let edited = L10n.tr("Localizable", "conversation.edited", fallback: "edited")
    /// Failed to save image to gallery
    internal static let errorSavingImage = L10n.tr("Localizable", "conversation.errorSavingImage", fallback: "Failed to save image to gallery")
    /// You are currently receiving a live location from 
    internal static let explanationReceivingLocationFrom = L10n.tr("Localizable", "conversation.explanationReceivingLocationFrom", fallback: "You are currently receiving a live location from ")
    /// You are currently sharing your location with 
    internal static let explanationSendingLocationTo = L10n.tr("Localizable", "conversation.explanationSendingLocationTo", fallback: "You are currently sharing your location with ")
    /// Sent you a request for a conversation.
    internal static let incomingRequest = L10n.tr("Localizable", "conversation.incomingRequest", fallback: "Sent you a request for a conversation.")
    /// In reply to
    internal static let inReplyTo = L10n.tr("Localizable", "conversation.inReplyTo", fallback: "In reply to")
    /// Write to
    internal static let messagePlaceholder = L10n.tr("Localizable", "conversation.messagePlaceholder", fallback: "Write to")
    /// is not in your contact list
    internal static let notContactLabel = L10n.tr("Localizable", "conversation.notContactLabel", fallback: "is not in your contact list")
    /// %@ sent you a request for a conversation.
    internal static func receivedRequest(_ p1: Any) -> String {
      return L10n.tr("Localizable", "conversation.receivedRequest", String(describing: p1), fallback: "%@ sent you a request for a conversation.")
    }
    /// replied to
    internal static let repliedTo = L10n.tr("Localizable", "conversation.repliedTo", fallback: "replied to")
    /// Hello,
    /// Would you like to join the conversation?
    internal static let requestMessage = L10n.tr("Localizable", "conversation.requestMessage", fallback: "Hello,\nWould you like to join the conversation?")
    /// Send him/her a contact request to be able to exchange together
    internal static let sendRequest = L10n.tr("Localizable", "conversation.sendRequest", fallback: "Send him/her a contact request to be able to exchange together")
    /// Send Contact Request
    internal static let sendRequestTitle = L10n.tr("Localizable", "conversation.sendRequestTitle", fallback: "Send Contact Request")
    /// We are waiting for %@ connects to synchronize the conversation.
    internal static func synchronizationMessage(_ p1: Any) -> String {
      return L10n.tr("Localizable", "conversation.synchronizationMessage", String(describing: p1), fallback: "We are waiting for %@ connects to synchronize the conversation.")
    }
    /// You have accepted the conversation request.
    internal static let synchronizationTitle = L10n.tr("Localizable", "conversation.synchronizationTitle", fallback: "You have accepted the conversation request.")
    /// yourself
    internal static let yourself = L10n.tr("Localizable", "conversation.yourself", fallback: "yourself")
  }
  internal enum CreateAccount {
    /// Join Jami
    internal static let createAccountFormTitle = L10n.tr("Localizable", "createAccount.createAccountFormTitle", fallback: "Join Jami")
    /// Creating account
    internal static let creatingAccount = L10n.tr("Localizable", "createAccount.creatingAccount", fallback: "Creating account")
    /// Customize
    internal static let customize = L10n.tr("Localizable", "createAccount.customize", fallback: "Customize")
    /// Encrypt
    internal static let encrypt = L10n.tr("Localizable", "createAccount.encrypt", fallback: "Encrypt")
    /// A Jami account is created and stored locally only on this device, as an archive containing your account keys. Access to this archive can optionally be protected by a password.
    internal static let encryptExplanation = L10n.tr("Localizable", "createAccount.encryptExplanation", fallback: "A Jami account is created and stored locally only on this device, as an archive containing your account keys. Access to this archive can optionally be protected by a password.")
    /// Encryption enabled
    internal static let encryptionEnabled = L10n.tr("Localizable", "createAccount.encryptionEnabled", fallback: "Encryption enabled")
    /// Encrypt account with password
    internal static let encryptTitle = L10n.tr("Localizable", "createAccount.encryptTitle", fallback: "Encrypt account with password")
    /// invalid username
    internal static let invalidUsername = L10n.tr("Localizable", "createAccount.invalidUsername", fallback: "invalid username")
    /// Loading
    internal static let loading = L10n.tr("Localizable", "createAccount.loading", fallback: "Loading")
    /// looking for availability…
    internal static let lookingForUsernameAvailability = L10n.tr("Localizable", "createAccount.lookingForUsernameAvailability", fallback: "looking for availability…")
    /// You can choose a username to help others more easily find and reach you on Jami.
    internal static let nameExplanation = L10n.tr("Localizable", "createAccount.nameExplanation", fallback: "You can choose a username to help others more easily find and reach you on Jami.")
    /// New account
    internal static let newAccount = L10n.tr("Localizable", "createAccount.newAccount", fallback: "New account")
    /// Configure an existing SIP account
    internal static let sipConfigure = L10n.tr("Localizable", "createAccount.sipConfigure", fallback: "Configure an existing SIP account")
    /// Username registration in progress... It could take a few moments.
    internal static let timeoutMessage = L10n.tr("Localizable", "createAccount.timeoutMessage", fallback: "Username registration in progress... It could take a few moments.")
    /// Account Created
    internal static let timeoutTitle = L10n.tr("Localizable", "createAccount.timeoutTitle", fallback: "Account Created")
    /// username already taken
    internal static let usernameAlreadyTaken = L10n.tr("Localizable", "createAccount.usernameAlreadyTaken", fallback: "username already taken")
    /// Account was created but username was not registered
    internal static let usernameNotRegisteredMessage = L10n.tr("Localizable", "createAccount.UsernameNotRegisteredMessage", fallback: "Account was created but username was not registered")
    /// Network error
    internal static let usernameNotRegisteredTitle = L10n.tr("Localizable", "createAccount.UsernameNotRegisteredTitle", fallback: "Network error")
    /// username is available
    internal static let usernameValid = L10n.tr("Localizable", "createAccount.usernameValid", fallback: "username is available")
    /// Adding account
    internal static let waitCreateAccountTitle = L10n.tr("Localizable", "createAccount.waitCreateAccountTitle", fallback: "Adding account")
  }
  internal enum CreateProfile {
    /// Create your avatar
    internal static let createYourAvatar = L10n.tr("Localizable", "createProfile.createYourAvatar", fallback: "Create your avatar")
    /// Enter a display name
    internal static let enterNameLabel = L10n.tr("Localizable", "createProfile.enterNameLabel", fallback: "Enter a display name")
    /// Enter name
    internal static let enterNamePlaceholder = L10n.tr("Localizable", "createProfile.enterNamePlaceholder", fallback: "Enter name")
    /// Next
    internal static let profileCreated = L10n.tr("Localizable", "createProfile.profileCreated", fallback: "Next")
    /// Skip
    internal static let skipCreateProfile = L10n.tr("Localizable", "createProfile.skipCreateProfile", fallback: "Skip")
    /// Your profile will be shared with your contacts. You can change it at any time.
    internal static let subtitle = L10n.tr("Localizable", "createProfile.subtitle", fallback: "Your profile will be shared with your contacts. You can change it at any time.")
    /// Personalize your profile
    internal static let title = L10n.tr("Localizable", "createProfile.title", fallback: "Personalize your profile")
  }
  internal enum DataTransfer {
    /// Press to start recording
    internal static let infoMessage = L10n.tr("Localizable", "dataTransfer.infoMessage", fallback: "Press to start recording")
    /// Accept
    internal static let readableStatusAccept = L10n.tr("Localizable", "dataTransfer.readableStatusAccept", fallback: "Accept")
    /// Pending…
    internal static let readableStatusAwaiting = L10n.tr("Localizable", "dataTransfer.readableStatusAwaiting", fallback: "Pending…")
    /// Canceled
    internal static let readableStatusCanceled = L10n.tr("Localizable", "dataTransfer.readableStatusCanceled", fallback: "Canceled")
    /// Initializing…
    internal static let readableStatusCreated = L10n.tr("Localizable", "dataTransfer.readableStatusCreated", fallback: "Initializing…")
    /// Error
    internal static let readableStatusError = L10n.tr("Localizable", "dataTransfer.readableStatusError", fallback: "Error")
    /// Transferring
    internal static let readableStatusOngoing = L10n.tr("Localizable", "dataTransfer.readableStatusOngoing", fallback: "Transferring")
    /// Refuse
    internal static let readableStatusRefuse = L10n.tr("Localizable", "dataTransfer.readableStatusRefuse", fallback: "Refuse")
    /// Complete
    internal static let readableStatusSuccess = L10n.tr("Localizable", "dataTransfer.readableStatusSuccess", fallback: "Complete")
    /// Recording video while multitasking with multiple apps may result in lower quality videos. For best results, record when not multitasking
    internal static let recordInBackgroundWarning = L10n.tr("Localizable", "dataTransfer.recordInBackgroundWarning", fallback: "Recording video while multitasking with multiple apps may result in lower quality videos. For best results, record when not multitasking")
    /// Failed to send
    internal static let sendingFailed = L10n.tr("Localizable", "dataTransfer.sendingFailed", fallback: "Failed to send")
    /// Send
    internal static let sendMessage = L10n.tr("Localizable", "dataTransfer.sendMessage", fallback: "Send")
  }
  internal enum GeneralSettings {
    /// Accept transfer limit
    internal static let acceptTransferLimit = L10n.tr("Localizable", "generalSettings.acceptTransferLimit", fallback: "Accept transfer limit")
    /// (in MB, 0 = unlimited)
    internal static let acceptTransferLimitDescription = L10n.tr("Localizable", "generalSettings.acceptTransferLimitDescription", fallback: "(in MB, 0 = unlimited)")
    /// Automatically accept incoming files
    internal static let automaticAcceptIncomingFiles = L10n.tr("Localizable", "generalSettings.automaticAcceptIncomingFiles", fallback: "Automatically accept incoming files")
    /// Donation campaign
    internal static let donationCampaign = L10n.tr("Localizable", "generalSettings.donationCampaign", fallback: "Donation campaign")
    /// Enable donation campaign
    internal static let enableDonationCampaign = L10n.tr("Localizable", "generalSettings.enableDonationCampaign", fallback: "Enable donation campaign")
    /// File transfer
    internal static let fileTransfer = L10n.tr("Localizable", "generalSettings.fileTransfer", fallback: "File transfer")
    /// Limit the duration of location sharing
    internal static let limitLocationSharingDuration = L10n.tr("Localizable", "generalSettings.limitLocationSharingDuration", fallback: "Limit the duration of location sharing")
    /// Location Sharing
    internal static let locationSharing = L10n.tr("Localizable", "generalSettings.locationSharing", fallback: "Location Sharing")
    /// Position share duration
    internal static let locationSharingDuration = L10n.tr("Localizable", "generalSettings.locationSharingDuration", fallback: "Position share duration")
    /// Enable video acceleration
    internal static let videoAcceleration = L10n.tr("Localizable", "generalSettings.videoAcceleration", fallback: "Enable video acceleration")
    /// Video Settings
    internal static let videoSettings = L10n.tr("Localizable", "generalSettings.videoSettings", fallback: "Video Settings")
  }
  internal enum GeneratedMessage {
    /// You received invitation
    internal static let contactAdded = L10n.tr("Localizable", "generatedMessage.contactAdded", fallback: "You received invitation")
    /// was kicked
    internal static let contactBlocked = L10n.tr("Localizable", "generatedMessage.contactBlocked", fallback: "was kicked")
    /// left
    internal static let contactLeftConversation = L10n.tr("Localizable", "generatedMessage.contactLeftConversation", fallback: "left")
    /// was re-added
    internal static let contactReAdded = L10n.tr("Localizable", "generatedMessage.contactReAdded", fallback: "was re-added")
    /// joined the conversation
    internal static let invitationAccepted = L10n.tr("Localizable", "generatedMessage.invitationAccepted", fallback: "joined the conversation")
    /// was invited to join
    internal static let invitationReceived = L10n.tr("Localizable", "generatedMessage.invitationReceived", fallback: "was invited to join")
    /// Live location sharing
    internal static let liveLocationSharing = L10n.tr("Localizable", "generatedMessage.liveLocationSharing", fallback: "Live location sharing")
    /// Missed incoming call
    internal static let missedIncomingCall = L10n.tr("Localizable", "generatedMessage.missedIncomingCall", fallback: "Missed incoming call")
    /// Missed outgoing call
    internal static let missedOutgoingCall = L10n.tr("Localizable", "generatedMessage.missedOutgoingCall", fallback: "Missed outgoing call")
    /// Outgoing call
    internal static let outgoingCall = L10n.tr("Localizable", "generatedMessage.outgoingCall", fallback: "Outgoing call")
    /// Swarm created
    internal static let swarmCreated = L10n.tr("Localizable", "generatedMessage.swarmCreated", fallback: "Swarm created")
    /// You joined the conversation
    internal static let youJoined = L10n.tr("Localizable", "generatedMessage.youJoined", fallback: "You joined the conversation")
  }
  internal enum Global {
    /// Accept
    internal static let accept = L10n.tr("Localizable", "global.accept", fallback: "Accept")
    /// *  Copyright (C) 2017-2023 Savoir-faire Linux Inc.
    ///  *
    ///  *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
    ///  *
    ///  *  This program is free software; you can redistribute it and/or modify
    ///  *  it under the terms of the GNU General Public License as published by
    ///  *  the Free Software Foundation; either version 3 of the License, or
    ///  *  (at your option) any later version.
    ///  *
    ///  *  This program is distributed in the hope that it will be useful,
    ///  *  but WITHOUT ANY WARRANTY; without even the implied warranty of
    ///  *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    ///  *  GNU General Public License for more details.
    ///  *
    ///  *  You should have received a copy of the GNU General Public License
    ///  *  along with this program; if not, write to the Free Software
    ///  *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
    internal static let accountSettings = L10n.tr("Localizable", "global.accountSettings", fallback: "Account Settings")
    /// Block
    internal static let block = L10n.tr("Localizable", "global.block", fallback: "Block")
    /// Block contact
    internal static let blockContact = L10n.tr("Localizable", "global.blockContact", fallback: "Block contact")
    /// Call
    internal static let call = L10n.tr("Localizable", "global.call", fallback: "Call")
    /// Camera access is disabled. Please enable it in settings.
    internal static let cameraDisabled = L10n.tr("Localizable", "global.cameraDisabled", fallback: "Camera access is disabled. Please enable it in settings.")
    /// Cancel
    internal static let cancel = L10n.tr("Localizable", "global.cancel", fallback: "Cancel")
    /// Close
    internal static let close = L10n.tr("Localizable", "global.close", fallback: "Close")
    /// Confirm password
    internal static let confirmPassword = L10n.tr("Localizable", "global.confirmPassword", fallback: "Confirm password")
    /// Copy
    internal static let copy = L10n.tr("Localizable", "global.copy", fallback: "Copy")
    /// Create
    internal static let create = L10n.tr("Localizable", "global.create", fallback: "Create")
    /// Delete file from device
    internal static let deleteFile = L10n.tr("Localizable", "global.deleteFile", fallback: "Delete file from device")
    /// Delete message
    internal static let deleteMessage = L10n.tr("Localizable", "global.deleteMessage", fallback: "Delete message")
    /// Donate
    internal static let donate = L10n.tr("Localizable", "global.donate", fallback: "Donate")
    /// Edit
    internal static let edit = L10n.tr("Localizable", "global.edit", fallback: "Edit")
    /// Editing
    internal static let editing = L10n.tr("Localizable", "global.editing", fallback: "Editing")
    /// Edit message
    internal static let editMessage = L10n.tr("Localizable", "global.editMessage", fallback: "Edit message")
    /// Edit password
    internal static let editPassword = L10n.tr("Localizable", "global.editPassword", fallback: "Edit password")
    /// Enter password
    internal static let enterPassword = L10n.tr("Localizable", "global.enterPassword", fallback: "Enter password")
    /// Enter username
    internal static let enterUsername = L10n.tr("Localizable", "global.enterUsername", fallback: "Enter username")
    /// Forward
    internal static let forward = L10n.tr("Localizable", "global.forward", fallback: "Forward")
    /// Incoming call
    internal static let incomingCall = L10n.tr("Localizable", "global.incomingCall", fallback: "Incoming call")
    /// Name
    internal static let name = L10n.tr("Localizable", "global.name", fallback: "Name")
    /// OK
    internal static let ok = L10n.tr("Localizable", "global.ok", fallback: "OK")
    /// Password
    internal static let password = L10n.tr("Localizable", "global.password", fallback: "Password")
    /// Preview
    internal static let preview = L10n.tr("Localizable", "global.preview", fallback: "Preview")
    /// Recommended
    internal static let recommended = L10n.tr("Localizable", "global.recommended", fallback: "Recommended")
    /// Refuse
    internal static let refuse = L10n.tr("Localizable", "global.refuse", fallback: "Refuse")
    /// Register username
    internal static let registerAUsername = L10n.tr("Localizable", "global.registerAUsername", fallback: "Register username")
    /// Remove
    internal static let remove = L10n.tr("Localizable", "global.remove", fallback: "Remove")
    /// Remove account
    internal static let removeAccount = L10n.tr("Localizable", "global.removeAccount", fallback: "Remove account")
    /// Reply
    internal static let reply = L10n.tr("Localizable", "global.reply", fallback: "Reply")
    /// Resend
    internal static let resend = L10n.tr("Localizable", "global.resend", fallback: "Resend")
    /// Save
    internal static let save = L10n.tr("Localizable", "global.save", fallback: "Save")
    /// Searching…
    internal static let search = L10n.tr("Localizable", "global.search", fallback: "Searching…")
    /// Share
    internal static let share = L10n.tr("Localizable", "global.share", fallback: "Share")
    /// Time
    internal static let time = L10n.tr("Localizable", "global.time", fallback: "Time")
    /// Username
    internal static let username = L10n.tr("Localizable", "global.username", fallback: "Username")
    /// Video
    internal static let video = L10n.tr("Localizable", "global.video", fallback: "Video")
  }
  internal enum ImportFromArchive {
    /// Import
    internal static let buttonTitle = L10n.tr("Localizable", "importFromArchive.buttonTitle", fallback: "Import")
    /// Import a Jami account from a local archive file.
    internal static let explanation = L10n.tr("Localizable", "importFromArchive.explanation", fallback: "Import a Jami account from a local archive file.")
    /// If the account is encrypted with a password, please enter it below.
    internal static let passwordExplanation = L10n.tr("Localizable", "importFromArchive.passwordExplanation", fallback: "If the account is encrypted with a password, please enter it below.")
    /// Select archive file
    internal static let selectArchiveButton = L10n.tr("Localizable", "importFromArchive.selectArchiveButton", fallback: "Select archive file")
    /// Import from archive
    internal static let title = L10n.tr("Localizable", "importFromArchive.title", fallback: "Import from archive")
  }
  internal enum Invitations {
    /// accepted
    internal static let accepted = L10n.tr("Localizable", "invitations.accepted", fallback: "accepted")
    /// banned
    internal static let banned = L10n.tr("Localizable", "invitations.banned", fallback: "banned")
    /// Invitations received
    internal static let list = L10n.tr("Localizable", "invitations.list", fallback: "Invitations received")
    /// No invitations
    internal static let noInvitations = L10n.tr("Localizable", "invitations.noInvitations", fallback: "No invitations")
    /// pending
    internal static let pending = L10n.tr("Localizable", "invitations.pending", fallback: "pending")
    /// refused
    internal static let refused = L10n.tr("Localizable", "invitations.refused", fallback: "refused")
  }
  internal enum LinkDevice {
    /// An error occurred during the export
    internal static let defaultError = L10n.tr("Localizable", "linkDevice.defaultError", fallback: "An error occurred during the export")
    /// To complete the process, you need to open Jami on the new device and choose the option "Link this device to an account." Your pin is valid for 10 minutes
    internal static let explanationMessage = L10n.tr("Localizable", "linkDevice.explanationMessage", fallback: "To complete the process, you need to open Jami on the new device and choose the option \"Link this device to an account.\" Your pin is valid for 10 minutes")
    /// Verifying
    internal static let hudMessage = L10n.tr("Localizable", "linkDevice.hudMessage", fallback: "Verifying")
    /// A network error occurred during the export
    internal static let networkError = L10n.tr("Localizable", "linkDevice.networkError", fallback: "A network error occurred during the export")
    /// The password you entered does not unlock this account
    internal static let passwordError = L10n.tr("Localizable", "linkDevice.passwordError", fallback: "The password you entered does not unlock this account")
    /// Link a new device
    internal static let title = L10n.tr("Localizable", "linkDevice.title", fallback: "Link a new device")
  }
  internal enum LinkToAccount {
    /// A PIN is required to use an existing Jami account on this device
    internal static let explanationMessage = L10n.tr("Localizable", "linkToAccount.explanationMessage", fallback: "A PIN is required to use an existing Jami account on this device")
    /// To generate the PIN code, go to the account management settings on the device containing the account you want to link to. Select "Link new device". You will receive the necessary PIN to complete this form. The PIN is only valid for 10 minutes.
    internal static let explanationPinMessage = L10n.tr("Localizable", "linkToAccount.explanationPinMessage", fallback: "To generate the PIN code, go to the account management settings on the device containing the account you want to link to. Select \"Link new device\". You will receive the necessary PIN to complete this form. The PIN is only valid for 10 minutes.")
    /// Link
    internal static let linkButtonTitle = L10n.tr("Localizable", "linkToAccount.linkButtonTitle", fallback: "Link")
    /// Choose “Link a new device” from the other Jami app to show the QR code or PIN
    internal static let linkDeviceMessage = L10n.tr("Localizable", "linkToAccount.linkDeviceMessage", fallback: "Choose “Link a new device” from the other Jami app to show the QR code or PIN")
    /// Link Device
    internal static let linkDeviceTitle = L10n.tr("Localizable", "linkToAccount.linkDeviceTitle", fallback: "Link Device")
    /// Enter PIN
    internal static let pinLabel = L10n.tr("Localizable", "linkToAccount.pinLabel", fallback: "Enter PIN")
    /// PIN
    internal static let pinPlaceholder = L10n.tr("Localizable", "linkToAccount.pinPlaceholder", fallback: "PIN")
    /// Scan QR Code
    internal static let scanQRCode = L10n.tr("Localizable", "linkToAccount.scanQRCode", fallback: "Scan QR Code")
    /// Account linking
    internal static let waitLinkToAccountTitle = L10n.tr("Localizable", "linkToAccount.waitLinkToAccountTitle", fallback: "Account linking")
  }
  internal enum LinkToAccountManager {
    /// Enter JAMS URL
    internal static let accountManagerLabel = L10n.tr("Localizable", "linkToAccountManager.accountManagerLabel", fallback: "Enter JAMS URL")
    /// JAMS URL
    internal static let accountManagerPlaceholder = L10n.tr("Localizable", "linkToAccountManager.accountManagerPlaceholder", fallback: "JAMS URL")
    /// Enter JAMS credentials
    internal static let enterCredentials = L10n.tr("Localizable", "linkToAccountManager.enterCredentials", fallback: "Enter JAMS credentials")
    /// Enter the Jami Account Management Server (JAMS) URL
    internal static let jamsExplanation = L10n.tr("Localizable", "linkToAccountManager.jamsExplanation", fallback: "Enter the Jami Account Management Server (JAMS) URL")
    /// Sign In
    internal static let signIn = L10n.tr("Localizable", "linkToAccountManager.signIn", fallback: "Sign In")
    /// JAMS Account
    internal static let title = L10n.tr("Localizable", "linkToAccountManager.title", fallback: "JAMS Account")
  }
  internal enum LogView {
    /// Open diagnostic log settings
    internal static let description = L10n.tr("Localizable", "logView.description", fallback: "Open diagnostic log settings")
    /// Failed to save file
    internal static let saveError = L10n.tr("Localizable", "logView.saveError", fallback: "Failed to save file")
    /// Failed to share file
    internal static let shareError = L10n.tr("Localizable", "logView.shareError", fallback: "Failed to share file")
    /// Start Logging
    internal static let startLogging = L10n.tr("Localizable", "logView.startLogging", fallback: "Start Logging")
    /// Stop Logging
    internal static let stopLogging = L10n.tr("Localizable", "logView.stopLogging", fallback: "Stop Logging")
    /// Diagnostics
    internal static let title = L10n.tr("Localizable", "logView.title", fallback: "Diagnostics")
  }
  internal enum MigrateAccount {
    /// Failed to migrate your account. You can retry or delete your account.
    internal static let error = L10n.tr("Localizable", "migrateAccount.error", fallback: "Failed to migrate your account. You can retry or delete your account.")
    /// This account needs to be migrated
    internal static let explanation = L10n.tr("Localizable", "migrateAccount.explanation", fallback: "This account needs to be migrated")
    /// Migrate Another Account
    internal static let migrateAnother = L10n.tr("Localizable", "migrateAccount.migrateAnother", fallback: "Migrate Another Account")
    /// Migrate Account
    internal static let migrateButton = L10n.tr("Localizable", "migrateAccount.migrateButton", fallback: "Migrate Account")
    /// Migrating...
    internal static let migrating = L10n.tr("Localizable", "migrateAccount.migrating", fallback: "Migrating...")
    /// To proceed with the migration, you need to enter a password that was used for this account
    internal static let passwordExplanation = L10n.tr("Localizable", "migrateAccount.passwordExplanation", fallback: "To proceed with the migration, you need to enter a password that was used for this account")
    /// Account migration
    internal static let title = L10n.tr("Localizable", "migrateAccount.title", fallback: "Account migration")
  }
  internal enum Notifications {
    /// Incoming location sharing started
    internal static let locationSharingStarted = L10n.tr("Localizable", "notifications.locationSharingStarted", fallback: "Incoming location sharing started")
    /// Incoming location sharing stopped
    internal static let locationSharingStopped = L10n.tr("Localizable", "notifications.locationSharingStopped", fallback: "Incoming location sharing stopped")
    /// Missed Call
    internal static let missedCall = L10n.tr("Localizable", "notifications.missedCall", fallback: "Missed Call")
    /// New file
    internal static let newFile = L10n.tr("Localizable", "notifications.newFile", fallback: "New file")
  }
  internal enum Scan {
    /// Bad QR code
    internal static let badQrCode = L10n.tr("Localizable", "scan.badQrCode", fallback: "Bad QR code")
  }
  internal enum Smartlist {
    /// About Jami
    internal static let aboutJami = L10n.tr("Localizable", "smartlist.aboutJami", fallback: "About Jami")
    /// Account list
    internal static let accounts = L10n.tr("Localizable", "smartlist.accounts", fallback: "Account list")
    /// Accounts
    internal static let accountsTitle = L10n.tr("Localizable", "smartlist.accountsTitle", fallback: "Accounts")
    /// + Add Account
    internal static let addAccountButton = L10n.tr("Localizable", "smartlist.addAccountButton", fallback: "+ Add Account")
    /// Be sure cellular access is granted in your settings
    internal static let cellularAccess = L10n.tr("Localizable", "smartlist.cellularAccess", fallback: "Be sure cellular access is granted in your settings")
    /// Conversations
    internal static let conversations = L10n.tr("Localizable", "smartlist.conversations", fallback: "Conversations")
    /// Not now
    internal static let disableDonation = L10n.tr("Localizable", "smartlist.disableDonation", fallback: "Not now")
    /// If you enjoy using Jami and believe in our mission, would you make a donation?
    internal static let donationExplanation = L10n.tr("Localizable", "smartlist.donationExplanation", fallback: "If you enjoy using Jami and believe in our mission, would you make a donation?")
    /// conversation in synchronization
    internal static let inSynchronization = L10n.tr("Localizable", "smartlist.inSynchronization", fallback: "conversation in synchronization")
    /// Invitations received
    internal static let invitationReceived = L10n.tr("Localizable", "smartlist.invitationReceived", fallback: "Invitations received")
    /// Invitations
    internal static let invitations = L10n.tr("Localizable", "smartlist.invitations", fallback: "Invitations")
    /// Invite friends
    internal static let inviteFriends = L10n.tr("Localizable", "smartlist.inviteFriends", fallback: "Invite friends")
    /// Search Result
    internal static let jamsResults = L10n.tr("Localizable", "smartlist.jamsResults", fallback: "Search Result")
    /// New Contact
    internal static let newContact = L10n.tr("Localizable", "smartlist.newContact", fallback: "New Contact")
    /// New Message
    internal static let newMessage = L10n.tr("Localizable", "smartlist.newMessage", fallback: "New Message")
    /// New Swarm
    internal static let newSwarm = L10n.tr("Localizable", "smartlist.newSwarm", fallback: "New Swarm")
    /// No conversations
    internal static let noConversation = L10n.tr("Localizable", "smartlist.noConversation", fallback: "No conversations")
    /// No conversations match your search
    internal static let noConversationsFound = L10n.tr("Localizable", "smartlist.noConversationsFound", fallback: "No conversations match your search")
    /// No network connectivity
    internal static let noNetworkConnectivity = L10n.tr("Localizable", "smartlist.noNetworkConnectivity", fallback: "No network connectivity")
    /// Selected contact does not have any number
    internal static let noNumber = L10n.tr("Localizable", "smartlist.noNumber", fallback: "Selected contact does not have any number")
    /// No results
    internal static let noResults = L10n.tr("Localizable", "smartlist.noResults", fallback: "No results")
    /// Public Directory
    internal static let results = L10n.tr("Localizable", "smartlist.results", fallback: "Public Directory")
    /// Search
    internal static let searchBar = L10n.tr("Localizable", "smartlist.searchBar", fallback: "Search")
    /// Enter name...
    internal static let searchBarPlaceholder = L10n.tr("Localizable", "smartlist.searchBarPlaceholder", fallback: "Enter name...")
    /// Select one of the numbers
    internal static let selectOneNumber = L10n.tr("Localizable", "smartlist.selectOneNumber", fallback: "Select one of the numbers")
    /// Yesterday
    internal static let yesterday = L10n.tr("Localizable", "smartlist.yesterday", fallback: "Yesterday")
  }
  internal enum Swarm {
    /// About
    internal static let about = L10n.tr("Localizable", "swarm.about", fallback: "About")
    /// Add Description
    internal static let addDescription = L10n.tr("Localizable", "swarm.addDescription", fallback: "Add Description")
    /// Add Member
    internal static let addMember = L10n.tr("Localizable", "swarm.addMember", fallback: "Add Member")
    /// Administrator
    internal static let admin = L10n.tr("Localizable", "swarm.admin", fallback: "Administrator")
    /// Admin invites only
    internal static let adminInvitesOnly = L10n.tr("Localizable", "swarm.adminInvitesOnly", fallback: "Admin invites only")
    /// Banned
    internal static let banned = L10n.tr("Localizable", "swarm.banned", fallback: "Banned")
    /// Change swarm picture
    internal static let changePicture = L10n.tr("Localizable", "swarm.changePicture", fallback: "Change swarm picture")
    /// Choose a color
    internal static let chooseColor = L10n.tr("Localizable", "swarm.chooseColor", fallback: "Choose a color")
    /// Are you sure you want to leave this swarm?
    internal static let confirmLeaveSwarm = L10n.tr("Localizable", "swarm.confirmLeaveSwarm", fallback: "Are you sure you want to leave this swarm?")
    /// Customize swarm
    internal static let customize = L10n.tr("Localizable", "swarm.customize", fallback: "Customize swarm")
    /// Customize swarm's profile
    internal static let customizeProfile = L10n.tr("Localizable", "swarm.customizeProfile", fallback: "Customize swarm's profile")
    /// You can add or invite members at any time after the swarm has been created
    internal static let explanationText = L10n.tr("Localizable", "swarm.explanationText", fallback: "You can add or invite members at any time after the swarm has been created")
    /// Identifier
    internal static let identifier = L10n.tr("Localizable", "swarm.identifier", fallback: "Identifier")
    /// Ignore the swarm
    internal static let ignoreSwarm = L10n.tr("Localizable", "swarm.ignoreSwarm", fallback: "Ignore the swarm")
    /// Invited
    internal static let invited = L10n.tr("Localizable", "swarm.invited", fallback: "Invited")
    /// Private swarm
    internal static let invitesOnly = L10n.tr("Localizable", "swarm.invitesOnly", fallback: "Private swarm")
    /// Leave
    internal static let leave = L10n.tr("Localizable", "swarm.Leave", fallback: "Leave")
    /// Leave the conversation
    internal static let leaveConversation = L10n.tr("Localizable", "swarm.leaveConversation", fallback: "Leave the conversation")
    /// Member
    internal static let member = L10n.tr("Localizable", "swarm.member", fallback: "Member")
    /// Members
    internal static let members = L10n.tr("Localizable", "swarm.members", fallback: "Members")
    /// Swarm's name
    internal static let namePlaceholder = L10n.tr("Localizable", "swarm.namePlaceholder", fallback: "Swarm's name")
    /// New swarm
    internal static let newSwarm = L10n.tr("Localizable", "swarm.newSwarm", fallback: "New swarm")
    /// Private swarm
    internal static let oneToOne = L10n.tr("Localizable", "swarm.oneToOne", fallback: "Private swarm")
    /// Others
    internal static let others = L10n.tr("Localizable", "swarm.others", fallback: "Others")
    /// Public swarm
    internal static let publicChat = L10n.tr("Localizable", "swarm.publicChat", fallback: "Public swarm")
    /// Select Contacts
    internal static let selectContacts = L10n.tr("Localizable", "swarm.selectContacts", fallback: "Select Contacts")
    /// Type of swarm
    internal static let typeOfSwarm = L10n.tr("Localizable", "swarm.typeOfSwarm", fallback: "Type of swarm")
    /// Unknown
    internal static let unknown = L10n.tr("Localizable", "swarm.unknown", fallback: "Unknown")
  }
  internal enum Swarmcreation {
    /// Add a description
    internal static let addADescription = L10n.tr("Localizable", "swarmcreation.addADescription", fallback: "Add a description")
    /// Create the swarm
    internal static let createTheSwarm = L10n.tr("Localizable", "swarmcreation.createTheSwarm", fallback: "Create the swarm")
    /// Search for contact...
    internal static let searchBar = L10n.tr("Localizable", "swarmcreation.searchBar", fallback: "Search for contact...")
  }
  internal enum Welcome {
    /// Connect to a Jami Account Manager Server
    internal static let connectToManager = L10n.tr("Localizable", "welcome.connectToManager", fallback: "Connect to a Jami Account Manager Server")
    /// Join
    internal static let createAccount = L10n.tr("Localizable", "welcome.createAccount", fallback: "Join")
    /// I already have an account
    internal static let haveAccount = L10n.tr("Localizable", "welcome.haveAccount", fallback: "I already have an account")
    /// Import from an archive backup
    internal static let linkBackup = L10n.tr("Localizable", "welcome.linkBackup", fallback: "Import from an archive backup")
    /// Import from another device
    internal static let linkDevice = L10n.tr("Localizable", "welcome.linkDevice", fallback: "Import from another device")
    /// Jami is a free and universal communication platform which preserves the users' privacy and freedoms
    internal static let text = L10n.tr("Localizable", "welcome.text", fallback: "Jami is a free and universal communication platform which preserves the users' privacy and freedoms")
    /// Share, freely and privately with Jami
    internal static let title = L10n.tr("Localizable", "welcome.title", fallback: "Share, freely and privately with Jami")
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg..., fallback value: String) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: value, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
