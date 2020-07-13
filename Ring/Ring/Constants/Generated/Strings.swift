// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
internal enum L10n {

  internal enum Account {
    /// Account Status
    internal static let accountStatus = L10n.tr("Localizable", "account.accountStatus")
    /// Create Sip Account
    internal static let createSipAccount = L10n.tr("Localizable", "account.createSipAccount")
    /// Enable Account
    internal static let enableAccount = L10n.tr("Localizable", "account.enableAccount")
    /// account need to be migrated
    internal static let needMigration = L10n.tr("Localizable", "account.needMigration")
    /// Enter Password
    internal static let passwordLabel = L10n.tr("Localizable", "account.passwordLabel")
    /// Port
    internal static let port = L10n.tr("Localizable", "account.port")
    /// Enter Port Number
    internal static let portLabel = L10n.tr("Localizable", "account.portLabel")
    /// Proxy
    internal static let proxyServer = L10n.tr("Localizable", "account.proxyServer")
    /// Enter Address
    internal static let serverLabel = L10n.tr("Localizable", "account.serverLabel")
    /// Password
    internal static let sipPassword = L10n.tr("Localizable", "account.sipPassword")
    /// SIP Server
    internal static let sipServer = L10n.tr("Localizable", "account.sipServer")
    /// User Name
    internal static let sipUsername = L10n.tr("Localizable", "account.sipUsername")
    /// Connecting
    internal static let statusConnecting = L10n.tr("Localizable", "account.statusConnecting")
    /// Connection Error
    internal static let statusConnectionerror = L10n.tr("Localizable", "account.statusConnectionerror")
    /// Offline
    internal static let statusOffline = L10n.tr("Localizable", "account.statusOffline")
    /// Online
    internal static let statusOnline = L10n.tr("Localizable", "account.statusOnline")
    /// Unknown
    internal static let statusUnknown = L10n.tr("Localizable", "account.statusUnknown")
    /// Enter Username
    internal static let usernameLabel = L10n.tr("Localizable", "account.usernameLabel")
  }

  internal enum AccountPage {
    /// Blocked contacts
    internal static let blockedContacts = L10n.tr("Localizable", "accountPage.blockedContacts")
    /// After enabling booth mode all your conversations will be removed.
    internal static let boothModeAlertMessage = L10n.tr("Localizable", "accountPage.boothModeAlertMessage")
    /// In booth mode conversation history not saved and jami functionality limited by making outgoing calls. When you enable booth mode all your conversations will be removed.
    internal static let boothModeExplanation = L10n.tr("Localizable", "accountPage.boothModeExplanation")
    /// Change password
    internal static let changePassword = L10n.tr("Localizable", "accountPage.changePassword")
    /// Password incorrect
    internal static let changePasswordError = L10n.tr("Localizable", "accountPage.changePasswordError")
    /// Contact me using "%s" on the Jami distributed communication platform: https://jami.net
    internal static func contactMeOnJamiContant(_ p1: UnsafePointer<CChar>) -> String {
      return L10n.tr("Localizable", "accountPage.contactMeOnJamiContant", p1)
    }
    /// Contact me on Jami!
    internal static let contactMeOnJamiTitle = L10n.tr("Localizable", "accountPage.contactMeOnJamiTitle")
    /// Create password
    internal static let createPassword = L10n.tr("Localizable", "accountPage.createPassword")
    /// Account Details
    internal static let credentialsHeader = L10n.tr("Localizable", "accountPage.credentialsHeader")
    /// Device revocation error
    internal static let deviceRevocationError = L10n.tr("Localizable", "accountPage.deviceRevocationError")
    /// Revoking...
    internal static let deviceRevocationProgress = L10n.tr("Localizable", "accountPage.deviceRevocationProgress")
    /// Device was revoked
    internal static let deviceRevocationSuccess = L10n.tr("Localizable", "accountPage.deviceRevocationSuccess")
    /// Try again
    internal static let deviceRevocationTryAgain = L10n.tr("Localizable", "accountPage.deviceRevocationTryAgain")
    /// Unknown device
    internal static let deviceRevocationUnknownDevice = L10n.tr("Localizable", "accountPage.deviceRevocationUnknownDevice")
    /// Incorrect password
    internal static let deviceRevocationWrongPassword = L10n.tr("Localizable", "accountPage.deviceRevocationWrongPassword")
    /// Device revocation completed
    internal static let deviceRevoked = L10n.tr("Localizable", "accountPage.deviceRevoked")
    /// Devices
    internal static let devicesListHeader = L10n.tr("Localizable", "accountPage.devicesListHeader")
    /// Disable Booth Mode
    internal static let disableBoothMode = L10n.tr("Localizable", "accountPage.disableBoothMode")
    /// Pleace provide your account password
    internal static let disableBoothModeExplanation = L10n.tr("Localizable", "accountPage.disableBoothModeExplanation")
    /// Enable Booth Mode
    internal static let enableBoothMode = L10n.tr("Localizable", "accountPage.enableBoothMode")
    /// Enable Notifications
    internal static let enableNotifications = L10n.tr("Localizable", "accountPage.enableNotifications")
    /// Enable Proxy
    internal static let enableProxy = L10n.tr("Localizable", "accountPage.enableProxy")
    /// Link another device
    internal static let linkDeviceTitle = L10n.tr("Localizable", "accountPage.linkDeviceTitle")
    /// Name
    internal static let namePlaceholder = L10n.tr("Localizable", "accountPage.namePlaceholder")
    /// Confirm new password
    internal static let newPasswordConfirmPlaceholder = L10n.tr("Localizable", "accountPage.newPasswordConfirmPlaceholder")
    /// Enter new password
    internal static let newPasswordPlaceholder = L10n.tr("Localizable", "accountPage.newPasswordPlaceholder")
    /// To enable Booth mode you need to create account password first.
    internal static let noBoothMode = L10n.tr("Localizable", "accountPage.noBoothMode")
    /// Your device won't receive notifications when proxy is disabled
    internal static let noProxyExplanationLabel = L10n.tr("Localizable", "accountPage.noProxyExplanationLabel")
    /// Enter old password
    internal static let oldPasswordPlaceholder = L10n.tr("Localizable", "accountPage.oldPasswordPlaceholder")
    /// Other
    internal static let other = L10n.tr("Localizable", "accountPage.other")
    /// Enter account password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "accountPage.passwordPlaceholder")
    /// Auto connect on local network
    internal static let peerDiscovery = L10n.tr("Localizable", "accountPage.peerDiscovery")
    /// Provide proxy address
    internal static let proxyAddressAlert = L10n.tr("Localizable", "accountPage.proxyAddressAlert")
    /// In order to receive notifications, please enable proxy
    internal static let proxyDisabledAlertBody = L10n.tr("Localizable", "accountPage.proxyDisabledAlertBody")
    /// Proxy Server Disabled
    internal static let proxyDisabledAlertTitle = L10n.tr("Localizable", "accountPage.proxyDisabledAlertTitle")
    /// Proxy address
    internal static let proxyPaceholder = L10n.tr("Localizable", "accountPage.proxyPaceholder")
    /// Choosen username is not available
    internal static let registerNameErrorMessage = L10n.tr("Localizable", "accountPage.registerNameErrorMessage")
    /// Register a username
    internal static let registerNameTitle = L10n.tr("Localizable", "accountPage.registerNameTitle")
    /// Remove
    internal static let removeAccountButton = L10n.tr("Localizable", "accountPage.removeAccountButton")
    /// By clicking "Remove" you will remove this account on this device! This action can not be undone. Also, your registered name can be lost.
    internal static let removeAccountMessage = L10n.tr("Localizable", "accountPage.removeAccountMessage")
    /// Remove account
    internal static let removeAccountTitle = L10n.tr("Localizable", "accountPage.removeAccountTitle")
    /// Revoke
    internal static let revokeDeviceButton = L10n.tr("Localizable", "accountPage.revokeDeviceButton")
    /// Are you sure you want to revoke this device? This action could not be undone.
    internal static let revokeDeviceMessage = L10n.tr("Localizable", "accountPage.revokeDeviceMessage")
    /// Enter your passord
    internal static let revokeDevicePlaceholder = L10n.tr("Localizable", "accountPage.revokeDevicePlaceholder")
    /// Revoke device
    internal static let revokeDeviceTitle = L10n.tr("Localizable", "accountPage.revokeDeviceTitle")
    /// Save
    internal static let saveProxyAddress = L10n.tr("Localizable", "accountPage.saveProxyAddress")
    /// Settings
    internal static let settingsHeader = L10n.tr("Localizable", "accountPage.settingsHeader")
    /// Share Account Details
    internal static let shareAccountDetails = L10n.tr("Localizable", "accountPage.shareAccountDetails")
    /// UNBLOCK
    internal static let unblockContact = L10n.tr("Localizable", "accountPage.unblockContact")
    /// Username
    internal static let username = L10n.tr("Localizable", "accountPage.username")
    /// username: not registered
    internal static let usernameNotRegistered = L10n.tr("Localizable", "accountPage.usernameNotRegistered")
    /// Enter desired username
    internal static let usernamePlaceholder = L10n.tr("Localizable", "accountPage.usernamePlaceholder")
    /// Register
    internal static let usernameRegisterAction = L10n.tr("Localizable", "accountPage.usernameRegisterAction")
    /// Registering
    internal static let usernameRegistering = L10n.tr("Localizable", "accountPage.usernameRegistering")
    /// Registration failed. Please check password.
    internal static let usernameRegistrationFailed = L10n.tr("Localizable", "accountPage.usernameRegistrationFailed")
  }

  internal enum Actions {
    /// Back
    internal static let backAction = L10n.tr("Localizable", "actions.backAction")
    /// Block
    internal static let blockAction = L10n.tr("Localizable", "actions.blockAction")
    /// Cancel
    internal static let cancelAction = L10n.tr("Localizable", "actions.cancelAction")
    /// Clear
    internal static let clearAction = L10n.tr("Localizable", "actions.clearAction")
    /// Delete
    internal static let deleteAction = L10n.tr("Localizable", "actions.deleteAction")
    /// Done
    internal static let doneAction = L10n.tr("Localizable", "actions.doneAction")
    /// Go to Settings
    internal static let goToSettings = L10n.tr("Localizable", "actions.goToSettings")
    ///   Audio Call
    internal static let startAudioCall = L10n.tr("Localizable", "actions.startAudioCall")
    ///   Video Call
    internal static let startVideoCall = L10n.tr("Localizable", "actions.startVideoCall")
    /// Stop sharing
    internal static let stopLocationSharing = L10n.tr("Localizable", "actions.stopLocationSharing")
  }

  internal enum Alerts {
    /// Account Added
    internal static let accountAddedTitle = L10n.tr("Localizable", "alerts.accountAddedTitle")
    /// Account couldn't be found on the Jami network. Make sure it was exported on Jami from an existing device, and that provided credentials are correct.
    internal static let accountCannotBeFoundMessage = L10n.tr("Localizable", "alerts.accountCannotBeFoundMessage")
    /// Can't find account
    internal static let accountCannotBeFoundTitle = L10n.tr("Localizable", "alerts.accountCannotBeFoundTitle")
    /// The account couldn't be created.
    internal static let accountDefaultErrorMessage = L10n.tr("Localizable", "alerts.accountDefaultErrorMessage")
    /// Unknown error
    internal static let accountDefaultErrorTitle = L10n.tr("Localizable", "alerts.accountDefaultErrorTitle")
    /// Linking account
    internal static let accountLinkedTitle = L10n.tr("Localizable", "alerts.accountLinkedTitle")
    /// Could not add account because Jami couldn't connect to the distributed network. Check your device connectivity.
    internal static let accountNoNetworkMessage = L10n.tr("Localizable", "alerts.accountNoNetworkMessage")
    /// Can't connect to the network
    internal static let accountNoNetworkTitle = L10n.tr("Localizable", "alerts.accountNoNetworkTitle")
    /// Are you sure you want to block this contact? The conversation history with this contact will also be deleted permanently.
    internal static let confirmBlockContact = L10n.tr("Localizable", "alerts.confirmBlockContact")
    /// Block Contact
    internal static let confirmBlockContactTitle = L10n.tr("Localizable", "alerts.confirmBlockContactTitle")
    /// Are you sure you want to clear the conversation with this contact?
    internal static let confirmClearConversation = L10n.tr("Localizable", "alerts.confirmClearConversation")
    /// Clear Conversation
    internal static let confirmClearConversationTitle = L10n.tr("Localizable", "alerts.confirmClearConversationTitle")
    /// Are you sure you want to delete this conversation permanently?
    internal static let confirmDeleteConversation = L10n.tr("Localizable", "alerts.confirmDeleteConversation")
    /// Are you sure you want to delete the conversation with this contact?
    internal static let confirmDeleteConversationFromContact = L10n.tr("Localizable", "alerts.confirmDeleteConversationFromContact")
    /// Delete Conversation
    internal static let confirmDeleteConversationTitle = L10n.tr("Localizable", "alerts.confirmDeleteConversationTitle")
    /// Please close application and try to open it again
    internal static let dbFailedMessage = L10n.tr("Localizable", "alerts.dbFailedMessage")
    /// An error happned when launching Jami
    internal static let dbFailedTitle = L10n.tr("Localizable", "alerts.dbFailedTitle")
    /// Cannot connect to provided account manager. Please check your credentials
    internal static let errorWrongCredentials = L10n.tr("Localizable", "alerts.errorWrongCredentials")
    /// Incoming call from 
    internal static let incomingCallAllertTitle = L10n.tr("Localizable", "alerts.incomingCallAllertTitle")
    /// Accept
    internal static let incomingCallButtonAccept = L10n.tr("Localizable", "alerts.incomingCallButtonAccept")
    /// Ignore
    internal static let incomingCallButtonIgnore = L10n.tr("Localizable", "alerts.incomingCallButtonIgnore")
    /// Turn on "Location Services" to allow "Jami" to determine your location.
    internal static let locationServiceIsDisabled = L10n.tr("Localizable", "alerts.locationServiceIsDisabled")
    /// Share my location
    internal static let locationSharing = L10n.tr("Localizable", "alerts.locationSharing")
    /// 10 min
    internal static let locationSharingDuration10min = L10n.tr("Localizable", "alerts.locationSharingDuration10min")
    /// 1 hour
    internal static let locationSharingDuration1hour = L10n.tr("Localizable", "alerts.locationSharingDuration1hour")
    /// How long should the location sharing be?
    internal static let locationSharingDurationTitle = L10n.tr("Localizable", "alerts.locationSharingDurationTitle")
    /// Map information
    internal static let mapInformation = L10n.tr("Localizable", "alerts.mapInformation")
    /// Access to photo library not granted
    internal static let noLibraryPermissionsTitle = L10n.tr("Localizable", "alerts.noLibraryPermissionsTitle")
    /// Access to location not granted
    internal static let noLocationPermissionsTitle = L10n.tr("Localizable", "alerts.noLocationPermissionsTitle")
    /// Media permission not granted
    internal static let noMediaPermissionsTitle = L10n.tr("Localizable", "alerts.noMediaPermissionsTitle")
    /// © OpenStreetMap contributors
    internal static let openStreetMapCopyright = L10n.tr("Localizable", "alerts.openStreetMapCopyright")
    /// Learn more
    internal static let openStreetMapCopyrightMoreInfo = L10n.tr("Localizable", "alerts.openStreetMapCopyrightMoreInfo")
    /// Cancel
    internal static let profileCancelPhoto = L10n.tr("Localizable", "alerts.profileCancelPhoto")
    /// Take photo
    internal static let profileTakePhoto = L10n.tr("Localizable", "alerts.profileTakePhoto")
    /// Upload photo
    internal static let profileUploadPhoto = L10n.tr("Localizable", "alerts.profileUploadPhoto")
    /// Record an audio message
    internal static let recordAudioMessage = L10n.tr("Localizable", "alerts.recordAudioMessage")
    /// Record a video message
    internal static let recordVideoMessage = L10n.tr("Localizable", "alerts.recordVideoMessage")
    /// Upload file
    internal static let uploadFile = L10n.tr("Localizable", "alerts.uploadFile")
    /// Upload photo or movie
    internal static let uploadPhoto = L10n.tr("Localizable", "alerts.uploadPhoto")
  }

  internal enum BlockListPage {
    /// No blocked contacts
    internal static let noBlockedContacts = L10n.tr("Localizable", "blockListPage.noBlockedContacts")
  }

  internal enum Calls {
    /// Call finished
    internal static let callFinished = L10n.tr("Localizable", "calls.callFinished")
    /// Call
    internal static let callItemTitle = L10n.tr("Localizable", "calls.callItemTitle")
    /// Connecting…
    internal static let connecting = L10n.tr("Localizable", "calls.connecting")
    /// Call with 
    internal static let currentCallWith = L10n.tr("Localizable", "calls.currentCallWith")
    /// hang up
    internal static let haghUp = L10n.tr("Localizable", "calls.haghUp")
    /// wants to talk to you
    internal static let incomingCallInfo = L10n.tr("Localizable", "calls.incomingCallInfo")
    /// Ringing…
    internal static let ringing = L10n.tr("Localizable", "calls.ringing")
    /// Searching…
    internal static let searching = L10n.tr("Localizable", "calls.searching")
    /// Unknown
    internal static let unknown = L10n.tr("Localizable", "calls.unknown")
  }

  internal enum ContactPage {
    /// Block Contact
    internal static let blockContact = L10n.tr("Localizable", "contactPage.blockContact")
    /// Clear Chat
    internal static let clearConversation = L10n.tr("Localizable", "contactPage.clearConversation")
    /// Remove Conversation
    internal static let removeConversation = L10n.tr("Localizable", "contactPage.removeConversation")
    /// Send Message
    internal static let sendMessage = L10n.tr("Localizable", "contactPage.sendMessage")
    /// Start Audio Call
    internal static let startAudioCall = L10n.tr("Localizable", "contactPage.startAudioCall")
    /// Start Video Call
    internal static let startVideoCall = L10n.tr("Localizable", "contactPage.startVideoCall")
  }

  internal enum Conversation {
    /// Type your message...
    internal static let messagePlaceholder = L10n.tr("Localizable", "conversation.messagePlaceholder")
  }

  internal enum CreateAccount {
    /// Encrypt my account
    internal static let chooseAPassword = L10n.tr("Localizable", "createAccount.ChooseAPassword")
    /// Choose strong password you will remember to protect your Jami account.
    internal static let chooseStrongPassword = L10n.tr("Localizable", "createAccount.chooseStrongPassword")
    /// Create your account
    internal static let createAccountFormTitle = L10n.tr("Localizable", "createAccount.createAccountFormTitle")
    /// Notifications
    internal static let enableNotifications = L10n.tr("Localizable", "createAccount.EnableNotifications")
    /// Username
    internal static let enterNewUsernamePlaceholder = L10n.tr("Localizable", "createAccount.enterNewUsernamePlaceholder")
    /// invalid username
    internal static let invalidUsername = L10n.tr("Localizable", "createAccount.invalidUsername")
    /// Loading
    internal static let loading = L10n.tr("Localizable", "createAccount.loading")
    /// looking for availability…
    internal static let lookingForUsernameAvailability = L10n.tr("Localizable", "createAccount.lookingForUsernameAvailability")
    /// Password
    internal static let newPasswordPlaceholder = L10n.tr("Localizable", "createAccount.newPasswordPlaceholder")
    /// 6 characters minimum
    internal static let passwordCharactersNumberError = L10n.tr("Localizable", "createAccount.passwordCharactersNumberError")
    /// Choose a password to encrypt your local account. Don’t forget it or you will not be able to recover your account
    internal static let passwordInformation = L10n.tr("Localizable", "createAccount.PasswordInformation")
    /// passwords do not match
    internal static let passwordNotMatchingError = L10n.tr("Localizable", "createAccount.passwordNotMatchingError")
    /// (Recommended)
    internal static let recommended = L10n.tr("Localizable", "createAccount.Recommended")
    /// Register a username
    internal static let registerAUsername = L10n.tr("Localizable", "createAccount.RegisterAUsername")
    /// Confirm password
    internal static let repeatPasswordPlaceholder = L10n.tr("Localizable", "createAccount.repeatPasswordPlaceholder")
    /// Username registration in progress... It could take a few moments.
    internal static let timeoutMessage = L10n.tr("Localizable", "createAccount.timeoutMessage")
    /// Account Created
    internal static let timeoutTitle = L10n.tr("Localizable", "createAccount.timeoutTitle")
    /// username already taken
    internal static let usernameAlreadyTaken = L10n.tr("Localizable", "createAccount.usernameAlreadyTaken")
    /// Account was created but username was not registered
    internal static let usernameNotRegisteredMessage = L10n.tr("Localizable", "createAccount.UsernameNotRegisteredMessage")
    /// Network error
    internal static let usernameNotRegisteredTitle = L10n.tr("Localizable", "createAccount.UsernameNotRegisteredTitle")
    /// Adding account
    internal static let waitCreateAccountTitle = L10n.tr("Localizable", "createAccount.waitCreateAccountTitle")
  }

  internal enum CreateProfile {
    /// Create your avatar
    internal static let createYourAvatar = L10n.tr("Localizable", "createProfile.createYourAvatar")
    /// Enter a display name
    internal static let enterNameLabel = L10n.tr("Localizable", "createProfile.enterNameLabel")
    /// Enter name
    internal static let enterNamePlaceholder = L10n.tr("Localizable", "createProfile.enterNamePlaceholder")
    /// Next
    internal static let profileCreated = L10n.tr("Localizable", "createProfile.profileCreated")
    /// Skip
    internal static let skipCreateProfile = L10n.tr("Localizable", "createProfile.skipCreateProfile")
    /// Your profile will be shared with your contacts. You can change it at any time.
    internal static let subtitle = L10n.tr("Localizable", "createProfile.subtitle")
    /// Personalise your profile
    internal static let title = L10n.tr("Localizable", "createProfile.title")
  }

  internal enum DataTransfer {
    /// Press to start recording
    internal static let infoMessage = L10n.tr("Localizable", "dataTransfer.infoMessage")
    /// Accept
    internal static let readableStatusAccept = L10n.tr("Localizable", "dataTransfer.readableStatusAccept")
    /// Pending…
    internal static let readableStatusAwaiting = L10n.tr("Localizable", "dataTransfer.readableStatusAwaiting")
    /// Cancel
    internal static let readableStatusCancel = L10n.tr("Localizable", "dataTransfer.readableStatusCancel")
    /// Canceled
    internal static let readableStatusCanceled = L10n.tr("Localizable", "dataTransfer.readableStatusCanceled")
    /// Initializing…
    internal static let readableStatusCreated = L10n.tr("Localizable", "dataTransfer.readableStatusCreated")
    /// Error
    internal static let readableStatusError = L10n.tr("Localizable", "dataTransfer.readableStatusError")
    /// Transferring
    internal static let readableStatusOngoing = L10n.tr("Localizable", "dataTransfer.readableStatusOngoing")
    /// Refuse
    internal static let readableStatusRefuse = L10n.tr("Localizable", "dataTransfer.readableStatusRefuse")
    /// Complete
    internal static let readableStatusSuccess = L10n.tr("Localizable", "dataTransfer.readableStatusSuccess")
    /// Failed to send
    internal static let sendingFailed = L10n.tr("Localizable", "dataTransfer.sendingFailed")
    /// Send
    internal static let sendMessage = L10n.tr("Localizable", "dataTransfer.sendMessage")
  }

  internal enum GeneralSettings {
    /// General settings
    internal static let title = L10n.tr("Localizable", "generalSettings.title")
    /// Enable video acceleration
    internal static let videoAcceleration = L10n.tr("Localizable", "generalSettings.videoAcceleration")
  }

  internal enum GeneratedMessage {
    /// Contact added
    internal static let contactAdded = L10n.tr("Localizable", "generatedMessage.contactAdded")
    /// Incoming call
    internal static let incomingCall = L10n.tr("Localizable", "generatedMessage.incomingCall")
    /// Invitation accepted
    internal static let invitationAccepted = L10n.tr("Localizable", "generatedMessage.invitationAccepted")
    /// Invitation received
    internal static let invitationReceived = L10n.tr("Localizable", "generatedMessage.invitationReceived")
    /// Live location sharing
    internal static let liveLocationSharing = L10n.tr("Localizable", "generatedMessage.liveLocationSharing")
    /// Missed incoming call
    internal static let missedIncomingCall = L10n.tr("Localizable", "generatedMessage.missedIncomingCall")
    /// Missed outgoing call
    internal static let missedOutgoingCall = L10n.tr("Localizable", "generatedMessage.missedOutgoingCall")
    /// Outgoing call
    internal static let outgoingCall = L10n.tr("Localizable", "generatedMessage.outgoingCall")
  }

  internal enum Global {
    /// Invitations
    internal static let contactRequestsTabBarTitle = L10n.tr("Localizable", "global.contactRequestsTabBarTitle")
    /// Conversations
    internal static let homeTabBarTitle = L10n.tr("Localizable", "global.homeTabBarTitle")
    /// Account
    internal static let meTabBarTitle = L10n.tr("Localizable", "global.meTabBarTitle")
    /// Ok
    internal static let ok = L10n.tr("Localizable", "global.ok")
    /// Free as in Freedom
    internal static let versionName = L10n.tr("Localizable", "global.versionName")
  }

  internal enum Invitations {
    /// No invitations
    internal static let noInvitations = L10n.tr("Localizable", "invitations.noInvitations")
  }

  internal enum LinkDevice {
    /// An error occured during the export
    internal static let defaultError = L10n.tr("Localizable", "linkDevice.defaultError")
    /// To complete the process, you need to open Jami on the new device and choose the option "Link this device to an account." Your pin is valid for 10 minutes
    internal static let explanationMessage = L10n.tr("Localizable", "linkDevice.explanationMessage")
    /// Verifying
    internal static let hudMessage = L10n.tr("Localizable", "linkDevice.hudMessage")
    /// A network error occured during the export
    internal static let networkError = L10n.tr("Localizable", "linkDevice.networkError")
    /// The password you entered does not unlock this account
    internal static let passwordError = L10n.tr("Localizable", "linkDevice.passwordError")
    /// Link a new device
    internal static let title = L10n.tr("Localizable", "linkDevice.title")
  }

  internal enum LinkToAccount {
    /// To generate the PIN code, go to the account managment settings on device that contain account you want to use. In devices settings Select "Link another device to this account". You will get the necessary PIN to complete this form. The PIN is only valid for 10 minutes.
    internal static let explanationPinMessage = L10n.tr("Localizable", "linkToAccount.explanationPinMessage")
    /// Link device
    internal static let linkButtonTitle = L10n.tr("Localizable", "linkToAccount.linkButtonTitle")
    /// Enter Password
    internal static let passwordLabel = L10n.tr("Localizable", "linkToAccount.passwordLabel")
    /// Password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "linkToAccount.passwordPlaceholder")
    /// Enter PIN
    internal static let pinLabel = L10n.tr("Localizable", "linkToAccount.pinLabel")
    /// PIN
    internal static let pinPlaceholder = L10n.tr("Localizable", "linkToAccount.pinPlaceholder")
    /// Account linking
    internal static let waitLinkToAccountTitle = L10n.tr("Localizable", "linkToAccount.waitLinkToAccountTitle")
  }

  internal enum LinkToAccountManager {
    /// Enter account manager URI
    internal static let accountManagerLabel = L10n.tr("Localizable", "linkToAccountManager.accountManagerLabel")
    /// Account manager
    internal static let accountManagerPlaceholder = L10n.tr("Localizable", "linkToAccountManager.accountManagerPlaceholder")
    /// Enter Password
    internal static let passwordLabel = L10n.tr("Localizable", "linkToAccountManager.passwordLabel")
    /// Password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "linkToAccountManager.passwordPlaceholder")
    /// Sign In
    internal static let signIn = L10n.tr("Localizable", "linkToAccountManager.signIn")
    /// Enter Username
    internal static let usernameLabel = L10n.tr("Localizable", "linkToAccountManager.usernameLabel")
    /// Username
    internal static let usernamePlaceholder = L10n.tr("Localizable", "linkToAccountManager.usernamePlaceholder")
  }

  internal enum MigrateAccount {
    /// Cancel
    internal static let cancel = L10n.tr("Localizable", "migrateAccount.cancel")
    /// Failed to migrate your account. You can retry or delete your account.
    internal static let error = L10n.tr("Localizable", "migrateAccount.error")
    /// This account needs to be migrated
    internal static let explanation = L10n.tr("Localizable", "migrateAccount.explanation")
    /// Migrate Another Account
    internal static let migrateAnother = L10n.tr("Localizable", "migrateAccount.migrateAnother")
    /// Migrate Account
    internal static let migrateButton = L10n.tr("Localizable", "migrateAccount.migrateButton")
    /// Migrating...
    internal static let migrating = L10n.tr("Localizable", "migrateAccount.migrating")
    /// To proceed with the migration, you need to enter a password that was used for this account
    internal static let passwordExplanation = L10n.tr("Localizable", "migrateAccount.passwordExplanation")
    /// Enter password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "migrateAccount.passwordPlaceholder")
    /// Remove account
    internal static let removeAccount = L10n.tr("Localizable", "migrateAccount.removeAccount")
    /// Account migration
    internal static let title = L10n.tr("Localizable", "migrateAccount.title")
  }

  internal enum Notifications {
    /// ACCEPT
    internal static let acceptCall = L10n.tr("Localizable", "notifications.acceptCall")
    /// Incoming Call
    internal static let incomingCall = L10n.tr("Localizable", "notifications.incomingCall")
    /// Incoming location sharing started
    internal static let locationSharingStarted = L10n.tr("Localizable", "notifications.locationSharingStarted")
    /// Incoming location sharing stopped
    internal static let locationSharingStopped = L10n.tr("Localizable", "notifications.locationSharingStopped")
    /// Missed Call
    internal static let missedCall = L10n.tr("Localizable", "notifications.missedCall")
    /// New file
    internal static let newFile = L10n.tr("Localizable", "notifications.newFile")
    /// REFUSE
    internal static let refuseCall = L10n.tr("Localizable", "notifications.refuseCall")
  }

  internal enum Scan {
    /// Bad QR code
    internal static let badQrCode = L10n.tr("Localizable", "scan.badQrCode")
    /// Searching…
    internal static let search = L10n.tr("Localizable", "scan.search")
  }

  internal enum Smartlist {
    /// Accounts
    internal static let accountsTitle = L10n.tr("Localizable", "smartlist.accountsTitle")
    /// + Add Account
    internal static let addAccountButton = L10n.tr("Localizable", "smartlist.addAccountButton")
    /// Be sure cellular access is granted in your settings
    internal static let cellularAccess = L10n.tr("Localizable", "smartlist.cellularAccess")
    /// Conversations
    internal static let conversations = L10n.tr("Localizable", "smartlist.conversations")
    /// No conversations
    internal static let noConversation = L10n.tr("Localizable", "smartlist.noConversation")
    /// No network connectivity
    internal static let noNetworkConnectivity = L10n.tr("Localizable", "smartlist.noNetworkConnectivity")
    /// Selected contact does not have any number
    internal static let noNumber = L10n.tr("Localizable", "smartlist.noNumber")
    /// No results
    internal static let noResults = L10n.tr("Localizable", "smartlist.noResults")
    /// Search Result
    internal static let results = L10n.tr("Localizable", "smartlist.results")
    /// Enter name...
    internal static let searchBarPlaceholder = L10n.tr("Localizable", "smartlist.searchBarPlaceholder")
    /// Searching...
    internal static let searching = L10n.tr("Localizable", "smartlist.searching")
    /// Select one of the numbers
    internal static let selectOneNumber = L10n.tr("Localizable", "smartlist.selectOneNumber")
    /// Yesterday
    internal static let yesterday = L10n.tr("Localizable", "smartlist.yesterday")
  }

  internal enum Welcome {
    /// Connect to account manager
    internal static let connectToManager = L10n.tr("Localizable", "welcome.connectToManager")
    /// Create a Jami account
    internal static let createAccount = L10n.tr("Localizable", "welcome.createAccount")
    /// Link this device to an account
    internal static let linkDevice = L10n.tr("Localizable", "welcome.linkDevice")
    /// Jami is a free and universal communication platform which preserves the users' privacy and freedoms
    internal static let text = L10n.tr("Localizable", "welcome.text")
    /// Welcome to Jami !
    internal static let title = L10n.tr("Localizable", "welcome.title")
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    Bundle(for: BundleToken.self)
  }()
}
// swiftlint:enable convenience_type
