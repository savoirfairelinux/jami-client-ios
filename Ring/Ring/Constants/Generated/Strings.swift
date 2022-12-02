// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return prefer_self_in_static_references

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  internal enum Account {
    /// Account Status
    internal static let accountStatus = L10n.tr("Localizable", "account.accountStatus", fallback: "Account Status")
    /// Create a SIP Account
    internal static let createSipAccount = L10n.tr("Localizable", "account.createSipAccount", fallback: "Create a SIP Account")
    /// Enable Account
    internal static let enableAccount = L10n.tr("Localizable", "account.enableAccount", fallback: "Enable Account")
    /// Me
    internal static let me = L10n.tr("Localizable", "account.me", fallback: "Me")
    /// account need to be migrated
    internal static let needMigration = L10n.tr("Localizable", "account.needMigration", fallback: "account need to be migrated")
    /// Enter Password
    internal static let passwordLabel = L10n.tr("Localizable", "account.passwordLabel", fallback: "Enter Password")
    /// Port
    internal static let port = L10n.tr("Localizable", "account.port", fallback: "Port")
    /// Enter Port Number
    internal static let portLabel = L10n.tr("Localizable", "account.portLabel", fallback: "Enter Port Number")
    /// Proxy
    internal static let proxyServer = L10n.tr("Localizable", "account.proxyServer", fallback: "Proxy")
    /// Enter Address
    internal static let serverLabel = L10n.tr("Localizable", "account.serverLabel", fallback: "Enter Address")
    /// Password
    internal static let sipPassword = L10n.tr("Localizable", "account.sipPassword", fallback: "Password")
    /// SIP Server
    internal static let sipServer = L10n.tr("Localizable", "account.sipServer", fallback: "SIP Server")
    /// User Name
    internal static let sipUsername = L10n.tr("Localizable", "account.sipUsername", fallback: "User Name")
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
    /// Enter Username
    internal static let usernameLabel = L10n.tr("Localizable", "account.usernameLabel", fallback: "Enter Username")
  }
  internal enum AccountPage {
    /// Auto register after expiration
    internal static let autoRegistration = L10n.tr("Localizable", "accountPage.autoRegistration", fallback: "Auto register after expiration")
    /// Blocked contacts
    internal static let blockedContacts = L10n.tr("Localizable", "accountPage.blockedContacts", fallback: "Blocked contacts")
    /// After enabling booth mode all your conversations will be removed.
    internal static let boothModeAlertMessage = L10n.tr("Localizable", "accountPage.boothModeAlertMessage", fallback: "After enabling booth mode all your conversations will be removed.")
    /// In booth mode conversation history not saved and jami functionality limited by making outgoing calls. When you enable booth mode all your conversations will be removed.
    internal static let boothModeExplanation = L10n.tr("Localizable", "accountPage.boothModeExplanation", fallback: "In booth mode conversation history not saved and jami functionality limited by making outgoing calls. When you enable booth mode all your conversations will be removed.")
    /// Change password
    internal static let changePassword = L10n.tr("Localizable", "accountPage.changePassword", fallback: "Change password")
    /// Password incorrect
    internal static let changePasswordError = L10n.tr("Localizable", "accountPage.changePasswordError", fallback: "Password incorrect")
    /// Contact me using "%s" on the Jami distributed communication platform: https://jami.net
    internal static func contactMeOnJamiContant(_ p1: UnsafePointer<CChar>) -> String {
      return L10n.tr("Localizable", "accountPage.contactMeOnJamiContant", p1, fallback: "Contact me using \"%s\" on the Jami distributed communication platform: https://jami.net")
    }
    /// Contact me on Jami!
    internal static let contactMeOnJamiTitle = L10n.tr("Localizable", "accountPage.contactMeOnJamiTitle", fallback: "Contact me on Jami!")
    /// Create password
    internal static let createPassword = L10n.tr("Localizable", "accountPage.createPassword", fallback: "Create password")
    /// Account Details
    internal static let credentialsHeader = L10n.tr("Localizable", "accountPage.credentialsHeader", fallback: "Account Details")
    /// Device revocation error
    internal static let deviceRevocationError = L10n.tr("Localizable", "accountPage.deviceRevocationError", fallback: "Device revocation error")
    /// Revoking...
    internal static let deviceRevocationProgress = L10n.tr("Localizable", "accountPage.deviceRevocationProgress", fallback: "Revoking...")
    /// Device was revoked
    internal static let deviceRevocationSuccess = L10n.tr("Localizable", "accountPage.deviceRevocationSuccess", fallback: "Device was revoked")
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
    /// Pleace provide your account password
    internal static let disableBoothModeExplanation = L10n.tr("Localizable", "accountPage.disableBoothModeExplanation", fallback: "Pleace provide your account password")
    /// Enable Booth Mode
    internal static let enableBoothMode = L10n.tr("Localizable", "accountPage.enableBoothMode", fallback: "Enable Booth Mode")
    /// Enable Notifications
    internal static let enableNotifications = L10n.tr("Localizable", "accountPage.enableNotifications", fallback: "Enable Notifications")
    /// Enable Proxy
    internal static let enableProxy = L10n.tr("Localizable", "accountPage.enableProxy", fallback: "Enable Proxy")
    /// Link another device
    internal static let linkDeviceTitle = L10n.tr("Localizable", "accountPage.linkDeviceTitle", fallback: "Link another device")
    /// Confirm new password
    internal static let newPasswordConfirmPlaceholder = L10n.tr("Localizable", "accountPage.newPasswordConfirmPlaceholder", fallback: "Confirm new password")
    /// Enter new password
    internal static let newPasswordPlaceholder = L10n.tr("Localizable", "accountPage.newPasswordPlaceholder", fallback: "Enter new password")
    /// To enable Booth mode you need to create account password first.
    internal static let noBoothMode = L10n.tr("Localizable", "accountPage.noBoothMode", fallback: "To enable Booth mode you need to create account password first.")
    /// Your device won't receive notifications when proxy is disabled
    internal static let noProxyExplanationLabel = L10n.tr("Localizable", "accountPage.noProxyExplanationLabel", fallback: "Your device won't receive notifications when proxy is disabled")
    /// Enter old password
    internal static let oldPasswordPlaceholder = L10n.tr("Localizable", "accountPage.oldPasswordPlaceholder", fallback: "Enter old password")
    /// Other
    internal static let other = L10n.tr("Localizable", "accountPage.other", fallback: "Other")
    /// Enter account password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "accountPage.passwordPlaceholder", fallback: "Enter account password")
    /// Auto connect on local network
    internal static let peerDiscovery = L10n.tr("Localizable", "accountPage.peerDiscovery", fallback: "Auto connect on local network")
    /// Provide proxy address
    internal static let proxyAddressAlert = L10n.tr("Localizable", "accountPage.proxyAddressAlert", fallback: "Provide proxy address")
    /// In order to receive notifications, please enable proxy
    internal static let proxyDisabledAlertBody = L10n.tr("Localizable", "accountPage.proxyDisabledAlertBody", fallback: "In order to receive notifications, please enable proxy")
    /// Proxy Server Disabled
    internal static let proxyDisabledAlertTitle = L10n.tr("Localizable", "accountPage.proxyDisabledAlertTitle", fallback: "Proxy Server Disabled")
    /// Proxy address
    internal static let proxyPaceholder = L10n.tr("Localizable", "accountPage.proxyPaceholder", fallback: "Proxy address")
    /// Choosen username is not available
    internal static let registerNameErrorMessage = L10n.tr("Localizable", "accountPage.registerNameErrorMessage", fallback: "Choosen username is not available")
    /// Register a username
    internal static let registerNameTitle = L10n.tr("Localizable", "accountPage.registerNameTitle", fallback: "Register a username")
    /// Remove
    internal static let removeAccountButton = L10n.tr("Localizable", "accountPage.removeAccountButton", fallback: "Remove")
    /// By clicking "Remove" you will remove this account on this device! This action can not be undone. Also, your registered name can be lost.
    internal static let removeAccountMessage = L10n.tr("Localizable", "accountPage.removeAccountMessage", fallback: "By clicking \"Remove\" you will remove this account on this device! This action can not be undone. Also, your registered name can be lost.")
    /// Remove account
    internal static let removeAccountTitle = L10n.tr("Localizable", "accountPage.removeAccountTitle", fallback: "Remove account")
    /// Revoke
    internal static let revokeDeviceButton = L10n.tr("Localizable", "accountPage.revokeDeviceButton", fallback: "Revoke")
    /// Are you sure you want to revoke this device? This action could not be undone.
    internal static let revokeDeviceMessage = L10n.tr("Localizable", "accountPage.revokeDeviceMessage", fallback: "Are you sure you want to revoke this device? This action could not be undone.")
    /// Enter your passord
    internal static let revokeDevicePlaceholder = L10n.tr("Localizable", "accountPage.revokeDevicePlaceholder", fallback: "Enter your passord")
    /// Revoke device
    internal static let revokeDeviceTitle = L10n.tr("Localizable", "accountPage.revokeDeviceTitle", fallback: "Revoke device")
    /// Save
    internal static let saveProxyAddress = L10n.tr("Localizable", "accountPage.saveProxyAddress", fallback: "Save")
    /// Settings
    internal static let settingsHeader = L10n.tr("Localizable", "accountPage.settingsHeader", fallback: "Settings")
    /// Share Account Details
    internal static let shareAccountDetails = L10n.tr("Localizable", "accountPage.shareAccountDetails", fallback: "Share Account Details")
    /// UNBLOCK
    internal static let unblockContact = L10n.tr("Localizable", "accountPage.unblockContact", fallback: "UNBLOCK")
    /// Username
    internal static let username = L10n.tr("Localizable", "accountPage.username", fallback: "Username")
    /// username: not registered
    internal static let usernameNotRegistered = L10n.tr("Localizable", "accountPage.usernameNotRegistered", fallback: "username: not registered")
    /// Enter desired username
    internal static let usernamePlaceholder = L10n.tr("Localizable", "accountPage.usernamePlaceholder", fallback: "Enter desired username")
    /// Register
    internal static let usernameRegisterAction = L10n.tr("Localizable", "accountPage.usernameRegisterAction", fallback: "Register")
    /// Registering
    internal static let usernameRegistering = L10n.tr("Localizable", "accountPage.usernameRegistering", fallback: "Registering")
    /// Registration failed. Please check password.
    internal static let usernameRegistrationFailed = L10n.tr("Localizable", "accountPage.usernameRegistrationFailed", fallback: "Registration failed. Please check password.")
  }
  internal enum Actions {
    /// Back
    internal static let backAction = L10n.tr("Localizable", "actions.backAction", fallback: "Back")
    /// Cancel
    internal static let cancelAction = L10n.tr("Localizable", "actions.cancelAction", fallback: "Cancel")
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
    /// Block Contact
    internal static let confirmBlockContactTitle = L10n.tr("Localizable", "alerts.confirmBlockContactTitle", fallback: "Block Contact")
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
    /// An error happned when launching Jami
    internal static let dbFailedTitle = L10n.tr("Localizable", "alerts.dbFailedTitle", fallback: "An error happned when launching Jami")
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
    /// Cancel
    internal static let profileCancelPhoto = L10n.tr("Localizable", "alerts.profileCancelPhoto", fallback: "Cancel")
    /// Take photo
    internal static let profileTakePhoto = L10n.tr("Localizable", "alerts.profileTakePhoto", fallback: "Take photo")
    /// Upload photo
    internal static let profileUploadPhoto = L10n.tr("Localizable", "alerts.profileUploadPhoto", fallback: "Upload photo")
    /// Record an audio message
    internal static let recordAudioMessage = L10n.tr("Localizable", "alerts.recordAudioMessage", fallback: "Record an audio message")
    /// Record a video message
    internal static let recordVideoMessage = L10n.tr("Localizable", "alerts.recordVideoMessage", fallback: "Record a video message")
    /// Upload file
    internal static let uploadFile = L10n.tr("Localizable", "alerts.uploadFile", fallback: "Upload file")
    /// Upload photo or movie
    internal static let uploadPhoto = L10n.tr("Localizable", "alerts.uploadPhoto", fallback: "Upload photo or movie")
  }
  internal enum BlockListPage {
    /// No blocked contacts
    internal static let noBlockedContacts = L10n.tr("Localizable", "blockListPage.noBlockedContacts", fallback: "No blocked contacts")
  }
  internal enum Calls {
    /// Call finished
    internal static let callFinished = L10n.tr("Localizable", "calls.callFinished", fallback: "Call finished")
    /// Call
    internal static let callItemTitle = L10n.tr("Localizable", "calls.callItemTitle", fallback: "Call")
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
    /// Searching…
    internal static let searching = L10n.tr("Localizable", "calls.searching", fallback: "Searching…")
    /// set moderator
    internal static let setModerator = L10n.tr("Localizable", "calls.setModerator", fallback: "set moderator")
    /// Unknown
    internal static let unknown = L10n.tr("Localizable", "calls.unknown", fallback: "Unknown")
    /// unmute audio
    internal static let unmuteAudio = L10n.tr("Localizable", "calls.unmuteAudio", fallback: "unmute audio")
  }
  internal enum ContactPage {
    /// Block Contact
    internal static let blockContact = L10n.tr("Localizable", "contactPage.blockContact", fallback: "Block Contact")
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
    /// Failed to save image to galery
    internal static let errorSavingImage = L10n.tr("Localizable", "conversation.errorSavingImage", fallback: "Failed to save image to galery")
    /// You are currently receiving a live location from 
    internal static let explanationReceivingLocationFrom = L10n.tr("Localizable", "conversation.explanationReceivingLocationFrom", fallback: "You are currently receiving a live location from ")
    /// You are currently sharing your location with 
    internal static let explanationSendingLocationTo = L10n.tr("Localizable", "conversation.explanationSendingLocationTo", fallback: "You are currently sharing your location with ")
    /// Write message to 
    internal static let messagePlaceholder = L10n.tr("Localizable", "conversation.messagePlaceholder", fallback: "Write message to ")
    /// %s is not in your contact list.
    internal static func notContact(_ p1: UnsafePointer<CChar>) -> String {
      return L10n.tr("Localizable", "conversation.notContact", p1, fallback: "%s is not in your contact list.")
    }
    /// %s sent you a request for a conversation.
    internal static func receivedRequest(_ p1: UnsafePointer<CChar>) -> String {
      return L10n.tr("Localizable", "conversation.receivedRequest", p1, fallback: "%s sent you a request for a conversation.")
    }
    /// Hello,
    /// Would you like to join the conversation?
    internal static let requestMessage = L10n.tr("Localizable", "conversation.requestMessage", fallback: "Hello,\nWould you like to join the conversation?")
    /// Send him/her a contact request to be able to exchange together
    internal static let sendRequest = L10n.tr("Localizable", "conversation.sendRequest", fallback: "Send him/her a contact request to be able to exchange together")
    /// Send Contact Request
    internal static let sendRequestTitle = L10n.tr("Localizable", "conversation.sendRequestTitle", fallback: "Send Contact Request")
    /// We are waiting for %s connects to synchronize the conversation.
    internal static func synchronizationMessage(_ p1: UnsafePointer<CChar>) -> String {
      return L10n.tr("Localizable", "conversation.synchronizationMessage", p1, fallback: "We are waiting for %s connects to synchronize the conversation.")
    }
    /// You have accepted the conversation request.
    internal static let synchronizationTitle = L10n.tr("Localizable", "conversation.synchronizationTitle", fallback: "You have accepted the conversation request.")
  }
  internal enum CreateAccount {
    /// Encrypt my account
    internal static let chooseAPassword = L10n.tr("Localizable", "createAccount.ChooseAPassword", fallback: "Encrypt my account")
    /// Choose strong password you will remember to protect your Jami account.
    internal static let chooseStrongPassword = L10n.tr("Localizable", "createAccount.chooseStrongPassword", fallback: "Choose strong password you will remember to protect your Jami account.")
    /// Create your account
    internal static let createAccountFormTitle = L10n.tr("Localizable", "createAccount.createAccountFormTitle", fallback: "Create your account")
    /// Notifications
    internal static let enableNotifications = L10n.tr("Localizable", "createAccount.EnableNotifications", fallback: "Notifications")
    /// Username
    internal static let enterNewUsernamePlaceholder = L10n.tr("Localizable", "createAccount.enterNewUsernamePlaceholder", fallback: "Username")
    /// invalid username
    internal static let invalidUsername = L10n.tr("Localizable", "createAccount.invalidUsername", fallback: "invalid username")
    /// Loading
    internal static let loading = L10n.tr("Localizable", "createAccount.loading", fallback: "Loading")
    /// looking for availability…
    internal static let lookingForUsernameAvailability = L10n.tr("Localizable", "createAccount.lookingForUsernameAvailability", fallback: "looking for availability…")
    /// Password
    internal static let newPasswordPlaceholder = L10n.tr("Localizable", "createAccount.newPasswordPlaceholder", fallback: "Password")
    /// 6 characters minimum
    internal static let passwordCharactersNumberError = L10n.tr("Localizable", "createAccount.passwordCharactersNumberError", fallback: "6 characters minimum")
    /// Choose a password to encrypt your local account. Don’t forget it or you will not be able to recover your account
    internal static let passwordInformation = L10n.tr("Localizable", "createAccount.PasswordInformation", fallback: "Choose a password to encrypt your local account. Don’t forget it or you will not be able to recover your account")
    /// passwords do not match
    internal static let passwordNotMatchingError = L10n.tr("Localizable", "createAccount.passwordNotMatchingError", fallback: "passwords do not match")
    /// (Recommended)
    internal static let recommended = L10n.tr("Localizable", "createAccount.Recommended", fallback: "(Recommended)")
    /// Register a username
    internal static let registerAUsername = L10n.tr("Localizable", "createAccount.RegisterAUsername", fallback: "Register a username")
    /// Confirm password
    internal static let repeatPasswordPlaceholder = L10n.tr("Localizable", "createAccount.repeatPasswordPlaceholder", fallback: "Confirm password")
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
    /// Personalise your profile
    internal static let title = L10n.tr("Localizable", "createProfile.title", fallback: "Personalise your profile")
  }
  internal enum DataTransfer {
    /// Press to start recording
    internal static let infoMessage = L10n.tr("Localizable", "dataTransfer.infoMessage", fallback: "Press to start recording")
    /// Pending…
    internal static let readableStatusAwaiting = L10n.tr("Localizable", "dataTransfer.readableStatusAwaiting", fallback: "Pending…")
    /// Cancel
    internal static let readableStatusCancel = L10n.tr("Localizable", "dataTransfer.readableStatusCancel", fallback: "Cancel")
    /// Canceled
    internal static let readableStatusCanceled = L10n.tr("Localizable", "dataTransfer.readableStatusCanceled", fallback: "Canceled")
    /// Initializing…
    internal static let readableStatusCreated = L10n.tr("Localizable", "dataTransfer.readableStatusCreated", fallback: "Initializing…")
    /// Error
    internal static let readableStatusError = L10n.tr("Localizable", "dataTransfer.readableStatusError", fallback: "Error")
    /// Transferring
    internal static let readableStatusOngoing = L10n.tr("Localizable", "dataTransfer.readableStatusOngoing", fallback: "Transferring")
    /// Complete
    internal static let readableStatusSuccess = L10n.tr("Localizable", "dataTransfer.readableStatusSuccess", fallback: "Complete")
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
    /// File transfer
    internal static let fileTransfer = L10n.tr("Localizable", "generalSettings.fileTransfer", fallback: "File transfer")
    /// Advanced settings
    internal static let title = L10n.tr("Localizable", "generalSettings.title", fallback: "Advanced settings")
    /// Enable video acceleration
    internal static let videoAcceleration = L10n.tr("Localizable", "generalSettings.videoAcceleration", fallback: "Enable video acceleration")
    /// Video Settings
    internal static let videoSettings = L10n.tr("Localizable", "generalSettings.videoSettings", fallback: "Video Settings")
  }
  internal enum GeneratedMessage {
    /// You received inviation
    internal static let contactAdded = L10n.tr("Localizable", "generatedMessage.contactAdded", fallback: "You received inviation")
    /// was kicked
    internal static let contactBanned = L10n.tr("Localizable", "generatedMessage.contactBanned", fallback: "was kicked")
    /// left
    internal static let contactLeftConversation = L10n.tr("Localizable", "generatedMessage.contactLeftConversation", fallback: "left")
    /// was re-added
    internal static let contactReAdded = L10n.tr("Localizable", "generatedMessage.contactReAdded", fallback: "was re-added")
    /// Incoming call
    internal static let incomingCall = L10n.tr("Localizable", "generatedMessage.incomingCall", fallback: "Incoming call")
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
    /// Block
    internal static let block = L10n.tr("Localizable", "global.block", fallback: "Block")
    /// Close
    internal static let close = L10n.tr("Localizable", "global.close", fallback: "Close")
    /// Forward
    internal static let forward = L10n.tr("Localizable", "global.forward", fallback: "Forward")
    /// *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
    internal static let homeTabBarTitle = L10n.tr("Localizable", "global.homeTabBarTitle", fallback: "Conversations")
    /// Account Settings
    internal static let meTabBarTitle = L10n.tr("Localizable", "global.meTabBarTitle", fallback: "Account Settings")
    /// Name
    internal static let name = L10n.tr("Localizable", "global.name", fallback: "Name")
    /// Ok
    internal static let ok = L10n.tr("Localizable", "global.ok", fallback: "Ok")
    /// Preview
    internal static let preview = L10n.tr("Localizable", "global.preview", fallback: "Preview")
    /// Refuse
    internal static let refuse = L10n.tr("Localizable", "global.refuse", fallback: "Refuse")
    /// Resend
    internal static let resend = L10n.tr("Localizable", "global.resend", fallback: "Resend")
    /// Save
    internal static let save = L10n.tr("Localizable", "global.save", fallback: "Save")
    /// Share
    internal static let share = L10n.tr("Localizable", "global.share", fallback: "Share")
  }
  internal enum Invitations {
    /// No invitations
    internal static let noInvitations = L10n.tr("Localizable", "invitations.noInvitations", fallback: "No invitations")
  }
  internal enum LinkDevice {
    /// An error occured during the export
    internal static let defaultError = L10n.tr("Localizable", "linkDevice.defaultError", fallback: "An error occured during the export")
    /// To complete the process, you need to open Jami on the new device and choose the option "Link this device to an account." Your pin is valid for 10 minutes
    internal static let explanationMessage = L10n.tr("Localizable", "linkDevice.explanationMessage", fallback: "To complete the process, you need to open Jami on the new device and choose the option \"Link this device to an account.\" Your pin is valid for 10 minutes")
    /// Verifying
    internal static let hudMessage = L10n.tr("Localizable", "linkDevice.hudMessage", fallback: "Verifying")
    /// A network error occured during the export
    internal static let networkError = L10n.tr("Localizable", "linkDevice.networkError", fallback: "A network error occured during the export")
    /// The password you entered does not unlock this account
    internal static let passwordError = L10n.tr("Localizable", "linkDevice.passwordError", fallback: "The password you entered does not unlock this account")
    /// Link a new device
    internal static let title = L10n.tr("Localizable", "linkDevice.title", fallback: "Link a new device")
  }
  internal enum LinkToAccount {
    /// To generate the PIN code, go to the account managment settings on device that contain account you want to use. In devices settings Select "Link another device to this account". You will get the necessary PIN to complete this form. The PIN is only valid for 10 minutes.
    internal static let explanationPinMessage = L10n.tr("Localizable", "linkToAccount.explanationPinMessage", fallback: "To generate the PIN code, go to the account managment settings on device that contain account you want to use. In devices settings Select \"Link another device to this account\". You will get the necessary PIN to complete this form. The PIN is only valid for 10 minutes.")
    /// Link device
    internal static let linkButtonTitle = L10n.tr("Localizable", "linkToAccount.linkButtonTitle", fallback: "Link device")
    /// Enter Password
    internal static let passwordLabel = L10n.tr("Localizable", "linkToAccount.passwordLabel", fallback: "Enter Password")
    /// Password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "linkToAccount.passwordPlaceholder", fallback: "Password")
    /// Enter PIN
    internal static let pinLabel = L10n.tr("Localizable", "linkToAccount.pinLabel", fallback: "Enter PIN")
    /// PIN
    internal static let pinPlaceholder = L10n.tr("Localizable", "linkToAccount.pinPlaceholder", fallback: "PIN")
    /// Account linking
    internal static let waitLinkToAccountTitle = L10n.tr("Localizable", "linkToAccount.waitLinkToAccountTitle", fallback: "Account linking")
  }
  internal enum LinkToAccountManager {
    /// Enter JAMS URL
    internal static let accountManagerLabel = L10n.tr("Localizable", "linkToAccountManager.accountManagerLabel", fallback: "Enter JAMS URL")
    /// JAMS URL
    internal static let accountManagerPlaceholder = L10n.tr("Localizable", "linkToAccountManager.accountManagerPlaceholder", fallback: "JAMS URL")
    /// Enter Password
    internal static let passwordLabel = L10n.tr("Localizable", "linkToAccountManager.passwordLabel", fallback: "Enter Password")
    /// Password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "linkToAccountManager.passwordPlaceholder", fallback: "Password")
    /// Sign In
    internal static let signIn = L10n.tr("Localizable", "linkToAccountManager.signIn", fallback: "Sign In")
    /// Enter Username
    internal static let usernameLabel = L10n.tr("Localizable", "linkToAccountManager.usernameLabel", fallback: "Enter Username")
    /// Username
    internal static let usernamePlaceholder = L10n.tr("Localizable", "linkToAccountManager.usernamePlaceholder", fallback: "Username")
  }
  internal enum MigrateAccount {
    /// Cancel
    internal static let cancel = L10n.tr("Localizable", "migrateAccount.cancel", fallback: "Cancel")
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
    /// Enter password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "migrateAccount.passwordPlaceholder", fallback: "Enter password")
    /// Remove account
    internal static let removeAccount = L10n.tr("Localizable", "migrateAccount.removeAccount", fallback: "Remove account")
    /// Account migration
    internal static let title = L10n.tr("Localizable", "migrateAccount.title", fallback: "Account migration")
  }
  internal enum Notifications {
    /// Incoming Call
    internal static let incomingCall = L10n.tr("Localizable", "notifications.incomingCall", fallback: "Incoming Call")
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
    /// Searching…
    internal static let search = L10n.tr("Localizable", "scan.search", fallback: "Searching…")
  }
  internal enum Smartlist {
    /// About Jami
    internal static let aboutJami = L10n.tr("Localizable", "smartlist.aboutJami", fallback: "About Jami")
    /// Account Settings
    internal static let accountSettings = L10n.tr("Localizable", "smartlist.accountSettings", fallback: "Account Settings")
    /// Accounts
    internal static let accountsTitle = L10n.tr("Localizable", "smartlist.accountsTitle", fallback: "Accounts")
    /// + Add Account
    internal static let addAccountButton = L10n.tr("Localizable", "smartlist.addAccountButton", fallback: "+ Add Account")
    /// Advanced Settings
    internal static let advancedSettings = L10n.tr("Localizable", "smartlist.advancedSettings", fallback: "Advanced Settings")
    /// Be sure cellular access is granted in your settings
    internal static let cellularAccess = L10n.tr("Localizable", "smartlist.cellularAccess", fallback: "Be sure cellular access is granted in your settings")
    /// Conversations
    internal static let conversations = L10n.tr("Localizable", "smartlist.conversations", fallback: "Conversations")
    /// Invitations
    internal static let invitations = L10n.tr("Localizable", "smartlist.invitations", fallback: "Invitations")
    /// No conversations
    internal static let noConversation = L10n.tr("Localizable", "smartlist.noConversation", fallback: "No conversations")
    /// No network connectivity
    internal static let noNetworkConnectivity = L10n.tr("Localizable", "smartlist.noNetworkConnectivity", fallback: "No network connectivity")
    /// Selected contact does not have any number
    internal static let noNumber = L10n.tr("Localizable", "smartlist.noNumber", fallback: "Selected contact does not have any number")
    /// No results
    internal static let noResults = L10n.tr("Localizable", "smartlist.noResults", fallback: "No results")
    /// Public Directory
    internal static let results = L10n.tr("Localizable", "smartlist.results", fallback: "Public Directory")
    /// Search for new or existing contact...
    internal static let searchBar = L10n.tr("Localizable", "smartlist.searchBar", fallback: "Search for new or existing contact...")
    /// Enter name...
    internal static let searchBarPlaceholder = L10n.tr("Localizable", "smartlist.searchBarPlaceholder", fallback: "Enter name...")
    /// Searching...
    internal static let searching = L10n.tr("Localizable", "smartlist.searching", fallback: "Searching...")
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
    /// Administrator
    internal static let admin = L10n.tr("Localizable", "swarm.admin", fallback: "Administrator")
    /// Admin invites only
    internal static let adminInvitesOnly = L10n.tr("Localizable", "swarm.adminInvitesOnly", fallback: "Admin invites only")
    /// Banned
    internal static let banned = L10n.tr("Localizable", "swarm.banned", fallback: "Banned")
    /// Choose a color
    internal static let chooseColor = L10n.tr("Localizable", "swarm.chooseColor", fallback: "Choose a color")
    /// Identifier
    internal static let identifier = L10n.tr("Localizable", "swarm.identifier", fallback: "Identifier")
    /// Ignore the swarm
    internal static let ignoreSwarm = L10n.tr("Localizable", "swarm.ignoreSwarm", fallback: "Ignore the swarm")
    /// Others
    internal static let invited = L10n.tr("Localizable", "swarm.invited", fallback: "Others")
    /// Private group swarm
    internal static let invitesOnly = L10n.tr("Localizable", "swarm.invitesOnly", fallback: "Private group swarm")
    /// Leave the conversation
    internal static let leaveConversation = L10n.tr("Localizable", "swarm.leaveConversation", fallback: "Leave the conversation")
    /// Member
    internal static let member = L10n.tr("Localizable", "swarm.member", fallback: "Member")
    /// Members
    internal static let members = L10n.tr("Localizable", "swarm.members", fallback: "Members")
    /// Private swarm
    internal static let oneToOne = L10n.tr("Localizable", "swarm.oneToOne", fallback: "Private swarm")
    /// Others
    internal static let others = L10n.tr("Localizable", "swarm.others", fallback: "Others")
    /// Public group swarm
    internal static let publicChat = L10n.tr("Localizable", "swarm.publicChat", fallback: "Public group swarm")
    /// Type of swarm
    internal static let typeOfSwarm = L10n.tr("Localizable", "swarm.typeOfSwarm", fallback: "Type of swarm")
    /// Unkown
    internal static let unknown = L10n.tr("Localizable", "swarm.unknown", fallback: "Unkown")
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
    /// Connect to a JAMS server
    internal static let connectToManager = L10n.tr("Localizable", "welcome.connectToManager", fallback: "Connect to a JAMS server")
    /// Create a Jami account
    internal static let createAccount = L10n.tr("Localizable", "welcome.createAccount", fallback: "Create a Jami account")
    /// Link this device to an account
    internal static let linkDevice = L10n.tr("Localizable", "welcome.linkDevice", fallback: "Link this device to an account")
    /// Jami is a free and universal communication platform which preserves the users' privacy and freedoms
    internal static let text = L10n.tr("Localizable", "welcome.text", fallback: "Jami is a free and universal communication platform which preserves the users' privacy and freedoms")
    /// Welcome to Jami !
    internal static let title = L10n.tr("Localizable", "welcome.title", fallback: "Welcome to Jami !")
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
