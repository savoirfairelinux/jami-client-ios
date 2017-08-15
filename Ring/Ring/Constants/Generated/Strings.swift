// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable file_length

// swiftlint:disable explicit_type_interface identifier_name line_length nesting type_body_length type_name
enum L10n {

  enum Alerts {
    /// Account Added
    static let accountAddedTitle = L10n.tr("Localizable", "alerts.accountAddedTitle")
    /// Can't find account
    static let accountCannotBeFoundTitle = L10n.tr("Localizable", "alerts.accountCannotBeFoundTitle")
    /// The account couldn't be created.
    static let accountDefaultErrorMessage = L10n.tr("Localizable", "alerts.accountDefaultErrorMessage")
    /// Unknown error
    static let accountDefaultErrorTitle = L10n.tr("Localizable", "alerts.accountDefaultErrorTitle")
    /// Could not add account because Ring couldn't connect to the distributed network. Check your device connectivity.
    static let accountNoNetworkMessage = L10n.tr("Localizable", "alerts.accountNoNetworkMessage")
    /// Can't connect to the network
    static let accountNoNetworkTitle = L10n.tr("Localizable", "alerts.accountNoNetworkTitle")
    /// Account couldn't be found on the Ring network. Make sure it was exported on Ring from an existing device, and that provided credentials are correct.
    static let acountCannotBeFoundMessage = L10n.tr("Localizable", "alerts.acountCannotBeFoundMessage")
  }

  enum Createaccount {
    /// Choose strong password you will remember to protect your Ring account.
    static let chooseStrongPassword = L10n.tr("Localizable", "createAccount.chooseStrongPassword")
    /// Create your Ring account
    static let createAccountFormTitle = L10n.tr("Localizable", "createAccount.createAccountFormTitle")
    /// Enter new username
    static let enterNewUsernamePlaceholder = L10n.tr("Localizable", "createAccount.enterNewUsernamePlaceholder")
    /// Invalid username
    static let invalidUsername = L10n.tr("Localizable", "createAccount.invalidUsername")
    /// Loading...
    static let loading = L10n.tr("Localizable", "createAccount.loading")
    /// Looking for username availability...
    static let lookingForUsernameAvailability = L10n.tr("Localizable", "createAccount.lookingForUsernameAvailability")
    /// New Password
    static let newPasswordPlaceholder = L10n.tr("Localizable", "createAccount.newPasswordPlaceholder")
    /// 6 characters minimum
    static let passwordCharactersNumberError = L10n.tr("Localizable", "createAccount.passwordCharactersNumberError")
    /// Passwords do not match
    static let passwordNotMatchingError = L10n.tr("Localizable", "createAccount.passwordNotMatchingError")
    /// Register public username (experimental)
    static let registerPublicUsername = L10n.tr("Localizable", "createAccount.registerPublicUsername")
    /// Repeat new password
    static let repeatPasswordPlaceholder = L10n.tr("Localizable", "createAccount.repeatPasswordPlaceholder")
    /// Username already taken
    static let usernameAlreadyTaken = L10n.tr("Localizable", "createAccount.usernameAlreadyTaken")
    /// Adding account
    static let waitCreateAccountTitle = L10n.tr("Localizable", "createAccount.waitCreateAccountTitle")
  }

  enum Global {
    /// Home
    static let homeTabBarTitle = L10n.tr("Localizable", "global.homeTabBarTitle")
    /// Me
    static let meTabBarTitle = L10n.tr("Localizable", "global.meTabBarTitle")
    /// Ok
    static let ok = L10n.tr("Localizable", "global.ok")
  }

  enum Smartlist {
    /// Conversations
    static let conversations = L10n.tr("Localizable", "smartlist.conversations")
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
    static let linkDeviceButton = L10n.tr("Localizable", "welcome.linkDeviceButton")
    /// A Ring account allows you to reach people securely in peer to peer through fully distributed network
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
