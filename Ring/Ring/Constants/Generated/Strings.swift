// swiftlint:disable all
// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
internal enum L10n {

  internal enum AccountPage {
    /// Block List
    internal static let blockedContacts = L10n.tr("Localizable", "accountPage.blockedContacts")
    /// Account Details
    internal static let credentialsHeader = L10n.tr("Localizable", "accountPage.credentialsHeader")
    /// Devices
    internal static let devicesListHeader = L10n.tr("Localizable", "accountPage.devicesListHeader")
    /// Enable Notifications
    internal static let enableNotifications = L10n.tr("Localizable", "accountPage.enableNotifications")
    /// Enable Proxy
    internal static let enableProxy = L10n.tr("Localizable", "accountPage.enableProxy")
    /// Your device won't receive notifications when proxy is disabled
    internal static let noProxyExplanationLabel = L10n.tr("Localizable", "accountPage.noProxyExplanationLabel")
    /// Provide proxy address
    internal static let proxyAddressAlert = L10n.tr("Localizable", "accountPage.proxyAddressAlert")
    /// In order to receive notifications, please enable proxy
    internal static let proxyDisabledAlertBody = L10n.tr("Localizable", "accountPage.proxyDisabledAlertBody")
    /// Proxy Server Disabled
    internal static let proxyDisabledAlertTitle = L10n.tr("Localizable", "accountPage.proxyDisabledAlertTitle")
    /// Proxy address
    internal static let proxyPaceholder = L10n.tr("Localizable", "accountPage.proxyPaceholder")
    /// Save
    internal static let saveProxyAddress = L10n.tr("Localizable", "accountPage.saveProxyAddress")
    /// Settings
    internal static let settingsHeader = L10n.tr("Localizable", "accountPage.settingsHeader")
    /// UNBLOCK
    internal static let unblockContact = L10n.tr("Localizable", "accountPage.unblockContact")
    /// username:
    internal static let username = L10n.tr("Localizable", "accountPage.username")
    /// username: not registered
    internal static let usernameNotRegistered = L10n.tr("Localizable", "accountPage.usernameNotRegistered")
  }

  internal enum Actions {
    /// Block
    internal static let blockAction = L10n.tr("Localizable", "actions.blockAction")
    /// Cancel
    internal static let cancelAction = L10n.tr("Localizable", "actions.cancelAction")
    /// Delete
    internal static let deleteAction = L10n.tr("Localizable", "actions.deleteAction")
  }

  internal enum Alerts {
    /// Account Added
    internal static let accountAddedTitle = L10n.tr("Localizable", "alerts.accountAddedTitle")
    /// Account couldn't be found on the Ring network. Make sure it was exported on Ring from an existing device, and that provided credentials are correct.
    internal static let accountCannotBeFoundMessage = L10n.tr("Localizable", "alerts.accountCannotBeFoundMessage")
    /// Can't find account
    internal static let accountCannotBeFoundTitle = L10n.tr("Localizable", "alerts.accountCannotBeFoundTitle")
    /// The account couldn't be created.
    internal static let accountDefaultErrorMessage = L10n.tr("Localizable", "alerts.accountDefaultErrorMessage")
    /// Unknown error
    internal static let accountDefaultErrorTitle = L10n.tr("Localizable", "alerts.accountDefaultErrorTitle")
    /// Linking account
    internal static let accountLinkedTitle = L10n.tr("Localizable", "alerts.accountLinkedTitle")
    /// Could not add account because Ring couldn't connect to the distributed network. Check your device connectivity.
    internal static let accountNoNetworkMessage = L10n.tr("Localizable", "alerts.accountNoNetworkMessage")
    /// Can't connect to the network
    internal static let accountNoNetworkTitle = L10n.tr("Localizable", "alerts.accountNoNetworkTitle")
    /// Are you sure you want to block this contact? The conversation history with this contact will also be deleted permanently.
    internal static let confirmBlockContact = L10n.tr("Localizable", "alerts.confirmBlockContact")
    /// Block Contact
    internal static let confirmBlockContactTitle = L10n.tr("Localizable", "alerts.confirmBlockContactTitle")
    /// Are you sure you want to delete this conversation permanently?
    internal static let confirmDeleteConversation = L10n.tr("Localizable", "alerts.confirmDeleteConversation")
    /// Are you sure you want to delete the conversation with this contact?
    internal static let confirmDeleteConversationFromContact = L10n.tr("Localizable", "alerts.confirmDeleteConversationFromContact")
    /// Delete Conversation
    internal static let confirmDeleteConversationTitle = L10n.tr("Localizable", "alerts.confirmDeleteConversationTitle")
    /// Please close application and try to open it again
    internal static let dbFailedMessage = L10n.tr("Localizable", "alerts.dbFailedMessage")
    /// An error happned when launching Ring
    internal static let dbFailedTitle = L10n.tr("Localizable", "alerts.dbFailedTitle")
    /// Incoming call from 
    internal static let incomingCallAllertTitle = L10n.tr("Localizable", "alerts.incomingCallAllertTitle")
    /// Accept
    internal static let incomingCallButtonAccept = L10n.tr("Localizable", "alerts.incomingCallButtonAccept")
    /// Ignore
    internal static let incomingCallButtonIgnore = L10n.tr("Localizable", "alerts.incomingCallButtonIgnore")
    /// Cancel
    internal static let profileCancelPhoto = L10n.tr("Localizable", "alerts.profileCancelPhoto")
    /// Take photo
    internal static let profileTakePhoto = L10n.tr("Localizable", "alerts.profileTakePhoto")
    /// Upload photo
    internal static let profileUploadPhoto = L10n.tr("Localizable", "alerts.profileUploadPhoto")
  }

  internal enum Calls {
    /// Call finished
    internal static let callFinished = L10n.tr("Localizable", "calls.callFinished")
    /// Call
    internal static let callItemTitle = L10n.tr("Localizable", "calls.callItemTitle")
    /// Connecting…
    internal static let connecting = L10n.tr("Localizable", "calls.connecting")
    /// wants to talk to you
    internal static let incomingCallInfo = L10n.tr("Localizable", "calls.incomingCallInfo")
    /// Ringing…
    internal static let ringing = L10n.tr("Localizable", "calls.ringing")
    /// Unknown
    internal static let unknown = L10n.tr("Localizable", "calls.unknown")
  }

  internal enum ContactPage {
    /// Block Contact
    internal static let blockContact = L10n.tr("Localizable", "contactPage.blockContact")
    /// Clear Chat
    internal static let clearConversation = L10n.tr("Localizable", "contactPage.clearConversation")
    /// Send Message
    internal static let sendMessage = L10n.tr("Localizable", "contactPage.sendMessage")
    /// Start Audio Call
    internal static let startAudioCall = L10n.tr("Localizable", "contactPage.startAudioCall")
    /// Start Video Call
    internal static let startVideoCall = L10n.tr("Localizable", "contactPage.startVideoCall")
  }

  internal enum CreateAccount {
    /// Choose strong password you will remember to protect your Ring account.
    internal static let chooseStrongPassword = L10n.tr("Localizable", "createAccount.chooseStrongPassword")
    /// Create your Ring account
    internal static let createAccountFormTitle = L10n.tr("Localizable", "createAccount.createAccountFormTitle")
    /// username
    internal static let enterNewUsernamePlaceholder = L10n.tr("Localizable", "createAccount.enterNewUsernamePlaceholder")
    /// invalid username
    internal static let invalidUsername = L10n.tr("Localizable", "createAccount.invalidUsername")
    /// Loading
    internal static let loading = L10n.tr("Localizable", "createAccount.loading")
    /// looking for username availability
    internal static let lookingForUsernameAvailability = L10n.tr("Localizable", "createAccount.lookingForUsernameAvailability")
    /// password
    internal static let newPasswordPlaceholder = L10n.tr("Localizable", "createAccount.newPasswordPlaceholder")
    /// 6 characters minimum
    internal static let passwordCharactersNumberError = L10n.tr("Localizable", "createAccount.passwordCharactersNumberError")
    /// passwords do not match
    internal static let passwordNotMatchingError = L10n.tr("Localizable", "createAccount.passwordNotMatchingError")
    /// confirm password
    internal static let repeatPasswordPlaceholder = L10n.tr("Localizable", "createAccount.repeatPasswordPlaceholder")
    /// username already taken
    internal static let usernameAlreadyTaken = L10n.tr("Localizable", "createAccount.usernameAlreadyTaken")
    /// Adding account
    internal static let waitCreateAccountTitle = L10n.tr("Localizable", "createAccount.waitCreateAccountTitle")
  }

  internal enum CreateProfile {
    /// Next
    internal static let profileCreated = L10n.tr("Localizable", "createProfile.profileCreated")
    /// Skip
    internal static let skipCreateProfile = L10n.tr("Localizable", "createProfile.skipCreateProfile")
  }

  internal enum DataTransfer {
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
  }

  internal enum Global {
    /// Invitations
    internal static let contactRequestsTabBarTitle = L10n.tr("Localizable", "global.contactRequestsTabBarTitle")
    /// Home
    internal static let homeTabBarTitle = L10n.tr("Localizable", "global.homeTabBarTitle")
    /// Account
    internal static let meTabBarTitle = L10n.tr("Localizable", "global.meTabBarTitle")
    /// Ok
    internal static let ok = L10n.tr("Localizable", "global.ok")
  }

  internal enum LinkDevice {
    /// An error occured during the export
    internal static let defaultError = L10n.tr("Localizable", "linkDevice.defaultError")
    /// To complete the process, you need to open Ring on the new device and choose the option "Link this device to an account." Your pin is valid for 10 minutes
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
    /// password
    internal static let passwordPlaceholder = L10n.tr("Localizable", "linkToAccount.passwordPlaceholder")
    /// Enter PIN
    internal static let pinLabel = L10n.tr("Localizable", "linkToAccount.pinLabel")
    /// PIN
    internal static let pinPlaceholder = L10n.tr("Localizable", "linkToAccount.pinPlaceholder")
    /// Account linking
    internal static let waitLinkToAccountTitle = L10n.tr("Localizable", "linkToAccount.waitLinkToAccountTitle")
  }

  internal enum Scan {
    /// Bad QR code
    internal static let badQrCode = L10n.tr("Localizable", "scan.badQrCode")
    /// Searching…
    internal static let search = L10n.tr("Localizable", "scan.search")
  }

  internal enum Smartlist {
    /// Be sure cellular access is granted in your settings
    internal static let cellularAccess = L10n.tr("Localizable", "smartlist.cellularAccess")
    /// Conversations
    internal static let conversations = L10n.tr("Localizable", "smartlist.conversations")
    /// No network connectivity
    internal static let noNetworkConnectivity = L10n.tr("Localizable", "smartlist.noNetworkConnectivity")
    /// No results
    internal static let noResults = L10n.tr("Localizable", "smartlist.noResults")
    /// Search Result
    internal static let results = L10n.tr("Localizable", "smartlist.results")
    /// Searching...
    internal static let searching = L10n.tr("Localizable", "smartlist.searching")
    /// Yesterday
    internal static let yesterday = L10n.tr("Localizable", "smartlist.yesterday")
  }

  internal enum Welcome {
    /// Create a Ring account
    internal static let createAccount = L10n.tr("Localizable", "welcome.createAccount")
    /// Link this device to an account
    internal static let linkDevice = L10n.tr("Localizable", "welcome.linkDevice")
    /// Ring is a free and universal communication platform which preserves the users' privacy and freedoms
    internal static let text = L10n.tr("Localizable", "welcome.text")
    /// Welcome to Ring
    internal static let title = L10n.tr("Localizable", "welcome.title")
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension L10n {
  fileprivate static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, tableName: table, bundle: Bundle(for: BundleToken.self), comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

private final class BundleToken {}
