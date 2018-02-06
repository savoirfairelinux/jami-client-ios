// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// swiftlint:disable explicit_type_interface identifier_name line_length nesting type_body_length type_name
enum L10n {

  enum Accountpage {
    /// Devices
    static let devicesListHeader = L10n.tr("Localizable", "accountPage.devicesListHeader")
    /// Enable DHT Proxy
    static let enableProxy = L10n.tr("Localizable", "accountPage.enableProxy")
    /// Settings
    static let settingsHeader = L10n.tr("Localizable", "accountPage.settingsHeader")
  }

  enum Actions {
    /// Block
    static let blockAction = L10n.tr("Localizable", "actions.blockAction")
    /// Cancel
    static let cancelAction = L10n.tr("Localizable", "actions.cancelAction")
    /// Delete
    static let deleteAction = L10n.tr("Localizable", "actions.deleteAction")
  }

  enum Alerts {
    /// Account Added
    static let accountAddedTitle = L10n.tr("Localizable", "alerts.accountAddedTitle")
    /// Account couldn't be found on the Ring network. Make sure it was exported on Ring from an existing device, and that provided credentials are correct.
    static let accountCannotBeFoundMessage = L10n.tr("Localizable", "alerts.accountCannotBeFoundMessage")
    /// Can't find account
    static let accountCannotBeFoundTitle = L10n.tr("Localizable", "alerts.accountCannotBeFoundTitle")
    /// The account couldn't be created.
    static let accountDefaultErrorMessage = L10n.tr("Localizable", "alerts.accountDefaultErrorMessage")
    /// Unknown error
    static let accountDefaultErrorTitle = L10n.tr("Localizable", "alerts.accountDefaultErrorTitle")
    /// Linking account
    static let accountLinkedTitle = L10n.tr("Localizable", "alerts.accountLinkedTitle")
    /// Could not add account because Ring couldn't connect to the distributed network. Check your device connectivity.
    static let accountNoNetworkMessage = L10n.tr("Localizable", "alerts.accountNoNetworkMessage")
    /// Can't connect to the network
    static let accountNoNetworkTitle = L10n.tr("Localizable", "alerts.accountNoNetworkTitle")
    /// Are you sure you want to block this contact? The conversation history with this contact will also be deleted permanently.
    static let confirmBlockContact = L10n.tr("Localizable", "alerts.confirmBlockContact")
    /// Block Contact
    static let confirmBlockContactTitle = L10n.tr("Localizable", "alerts.confirmBlockContactTitle")
    /// Are you sure you want to delete this conversation permanently?
    static let confirmDeleteConversation = L10n.tr("Localizable", "alerts.confirmDeleteConversation")
    /// Delete Conversation
    static let confirmDeleteConversationTitle = L10n.tr("Localizable", "alerts.confirmDeleteConversationTitle")
    /// Please close application and try to open it again
    static let dbFailedMessage = L10n.tr("Localizable", "alerts.dbFailedMessage")
    /// An error happned when launching Ring
    static let dbFailedTitle = L10n.tr("Localizable", "alerts.dbFailedTitle")
    /// Incoming call from 
    static let incomingCallAllertTitle = L10n.tr("Localizable", "alerts.incomingCallAllertTitle")
    /// Accept
    static let incomingCallButtonAccept = L10n.tr("Localizable", "alerts.incomingCallButtonAccept")
    /// Ignore
    static let incomingCallButtonIgnore = L10n.tr("Localizable", "alerts.incomingCallButtonIgnore")
    /// Cancel
    static let profileCancelPhoto = L10n.tr("Localizable", "alerts.profileCancelPhoto")
    /// Take photo
    static let profileTakePhoto = L10n.tr("Localizable", "alerts.profileTakePhoto")
    /// Upload photo
    static let profileUploadPhoto = L10n.tr("Localizable", "alerts.profileUploadPhoto")
  }

  enum Calls {
    /// Call finished
    static let callFinished = L10n.tr("Localizable", "calls.callFinished")
    /// Calling...
    static let calling = L10n.tr("Localizable", "calls.calling")
    /// Call
    static let callItemTitle = L10n.tr("Localizable", "calls.callItemTitle")
    /// wants to talk to you
    static let incomingCallInfo = L10n.tr("Localizable", "calls.incomingCallInfo")
    /// Unknown
    static let unknown = L10n.tr("Localizable", "calls.unknown")
  }

  enum Createaccount {
    /// Choose strong password you will remember to protect your Ring account.
    static let chooseStrongPassword = L10n.tr("Localizable", "createAccount.chooseStrongPassword")
    /// Create your Ring account
    static let createAccountFormTitle = L10n.tr("Localizable", "createAccount.createAccountFormTitle")
    /// username
    static let enterNewUsernamePlaceholder = L10n.tr("Localizable", "createAccount.enterNewUsernamePlaceholder")
    /// invalid username
    static let invalidUsername = L10n.tr("Localizable", "createAccount.invalidUsername")
    /// Loading
    static let loading = L10n.tr("Localizable", "createAccount.loading")
    /// looking for username availability
    static let lookingForUsernameAvailability = L10n.tr("Localizable", "createAccount.lookingForUsernameAvailability")
    /// password
    static let newPasswordPlaceholder = L10n.tr("Localizable", "createAccount.newPasswordPlaceholder")
    /// 6 characters minimum
    static let passwordCharactersNumberError = L10n.tr("Localizable", "createAccount.passwordCharactersNumberError")
    /// passwords do not match
    static let passwordNotMatchingError = L10n.tr("Localizable", "createAccount.passwordNotMatchingError")
    /// confirm password
    static let repeatPasswordPlaceholder = L10n.tr("Localizable", "createAccount.repeatPasswordPlaceholder")
    /// username already taken
    static let usernameAlreadyTaken = L10n.tr("Localizable", "createAccount.usernameAlreadyTaken")
    /// Adding account
    static let waitCreateAccountTitle = L10n.tr("Localizable", "createAccount.waitCreateAccountTitle")
  }

  enum Createprofile {
    /// Skip to Create Account
    static let createAccount = L10n.tr("Localizable", "createProfile.createAccount")
    /// Next
    static let createAccountWithProfile = L10n.tr("Localizable", "createProfile.createAccountWithProfile")
    /// Skip to Link Device
    static let linkDevice = L10n.tr("Localizable", "createProfile.linkDevice")
  }

  enum Global {
    /// Invitations
    static let contactRequestsTabBarTitle = L10n.tr("Localizable", "global.contactRequestsTabBarTitle")
    /// Home
    static let homeTabBarTitle = L10n.tr("Localizable", "global.homeTabBarTitle")
    /// Account
    static let meTabBarTitle = L10n.tr("Localizable", "global.meTabBarTitle")
    /// Ok
    static let ok = L10n.tr("Localizable", "global.ok")
  }

  enum Linkdevice {
    /// An error occured during the export
    static let defaultError = L10n.tr("Localizable", "linkDevice.defaultError")
    /// To complete the process, you need to open Ring on the new device and choose the option "Link this device to an account." Your pin is valid for 10 minutes
    static let explanationMessage = L10n.tr("Localizable", "linkDevice.explanationMessage")
    /// Verifying
    static let hudMessage = L10n.tr("Localizable", "linkDevice.hudMessage")
    /// A network error occured during the export
    static let networkError = L10n.tr("Localizable", "linkDevice.networkError")
    /// The password you entered does not unlock this account
    static let passwordError = L10n.tr("Localizable", "linkDevice.passwordError")
    /// Link a new device
    static let title = L10n.tr("Localizable", "linkDevice.title")
  }

  enum Linktoaccount {
    /// To generate the PIN code, go to the account managment settings on device that contain account you want to use. In devices settings Select "Link another device to this account". You will get the necessary PIN to complete this form. The PIN is only valid for 10 minutes.
    static let explanationPinMessage = L10n.tr("Localizable", "linkToAccount.explanationPinMessage")
    /// Link device
    static let linkButtonTitle = L10n.tr("Localizable", "linkToAccount.linkButtonTitle")
    /// Enter Password
    static let passwordLabel = L10n.tr("Localizable", "linkToAccount.passwordLabel")
    /// password
    static let passwordPlaceholder = L10n.tr("Localizable", "linkToAccount.passwordPlaceholder")
    /// Enter PIN
    static let pinLabel = L10n.tr("Localizable", "linkToAccount.pinLabel")
    /// PIN
    static let pinPlaceholder = L10n.tr("Localizable", "linkToAccount.pinPlaceholder")
    /// Account linking
    static let waitLinkToAccountTitle = L10n.tr("Localizable", "linkToAccount.waitLinkToAccountTitle")
  }

  enum Smartlist {
    /// Be sure cellular access is granted in your settings
    static let cellularAccess = L10n.tr("Localizable", "smartlist.cellularAccess")
    /// Conversations
    static let conversations = L10n.tr("Localizable", "smartlist.conversations")
    /// No network connectivity
    static let noNetworkConnectivity = L10n.tr("Localizable", "smartlist.noNetworkConnectivity")
    /// No results
    static let noResults = L10n.tr("Localizable", "smartlist.noResults")
    /// Searching...
    static let searching = L10n.tr("Localizable", "smartlist.searching")
    /// User found
    static let userFound = L10n.tr("Localizable", "smartlist.userFound")
    /// Yesterday
    static let yesterday = L10n.tr("Localizable", "smartlist.yesterday")
  }

  enum Welcome {
    /// Create a Ring account
    static let createAccount = L10n.tr("Localizable", "welcome.createAccount")
    /// Link this device to an account
    static let linkDevice = L10n.tr("Localizable", "welcome.linkDevice")
    /// Ring is a free and universal communication platform which preserves the users' privacy and freedoms
    static let text = L10n.tr("Localizable", "welcome.text")
    /// Welcome to Ring
    static let title = L10n.tr("Localizable", "welcome.title")
  }
}
// swiftlint:enable explicit_type_interface identifier_name line_length nesting type_body_length type_name

extension L10n {
  fileprivate static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, tableName: table, bundle: Bundle(for: BundleToken.self), comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

private final class BundleToken {}
