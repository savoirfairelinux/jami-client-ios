// Generated using SwiftGen, by O.Halligon — https://github.com/AliSoftware/SwiftGen

import Foundation

private class RingStringsBundleToken {}

// swiftlint:disable file_length
// swiftlint:disable line_length

// swiftlint:disable type_body_length
// swiftlint:disable nesting
// swiftlint:disable variable_name
// swiftlint:disable valid_docs

// swiftlint:disable explicit_type_interface identifier_name line_length nesting type_body_length type_name
enum L10n {

  enum Alerts {
    /// Account Added
    static let accountAddedTitle = L10n.tr("alerts.accountAddedTitle")
    /// Can't find account
    static let accountCannotBeFoundTitle = L10n.tr("alerts.accountCannotBeFoundTitle")
    /// The account couldn't be created.
    static let accountDefaultErrorMessage = L10n.tr("alerts.accountDefaultErrorMessage")
    /// Unknown error
    static let accountDefaultErrorTitle = L10n.tr("alerts.accountDefaultErrorTitle")
    /// Could not add account because Ring couldn't connect to the distributed network. Check your device connectivity.
    static let accountNoNetworkMessage = L10n.tr("alerts.accountNoNetworkMessage")
    /// Can't connect to the network
    static let accountNoNetworkTitle = L10n.tr("alerts.accountNoNetworkTitle")
    /// Account couldn't be found on the Ring network. Make sure it was exported on Ring from an existing device, and that provided credentials are correct.
    static let acountCannotBeFoundMessage = L10n.tr("alerts.acountCannotBeFoundMessage")
  }

  enum Calls {
    /// Call finished
    static let callFinished = L10n.tr("calls.callFinished")
    /// Calling...
    static let calling = L10n.tr("calls.calling")
    /// Call
    static let callItemTitle = L10n.tr("calls.callItemTitle")
    /// wants to talk to you
    static let incomingCallInfo = L10n.tr("calls.incomingCallInfo")
    /// Unknown
    static let unknown = L10n.tr("calls.unknown")
  }

  enum Createaccount {
    /// Choose strong password you will remember to protect your Ring account.
    static let chooseStrongPassword = L10n.tr("createAccount.chooseStrongPassword")
    /// Create your Ring account
    static let createAccountFormTitle = L10n.tr("createAccount.createAccountFormTitle")
    /// username
    static let enterNewUsernamePlaceholder = L10n.tr("createAccount.enterNewUsernamePlaceholder")
    /// invalid username
    static let invalidUsername = L10n.tr("createAccount.invalidUsername")
    /// Loading
    static let loading = L10n.tr("createAccount.loading")
    /// looking for username availability
    static let lookingForUsernameAvailability = L10n.tr("createAccount.lookingForUsernameAvailability")
    /// password
    static let newPasswordPlaceholder = L10n.tr("createAccount.newPasswordPlaceholder")
    /// 6 characters minimum
    static let passwordCharactersNumberError = L10n.tr("createAccount.passwordCharactersNumberError")
    /// passwords do not match
    static let passwordNotMatchingError = L10n.tr("createAccount.passwordNotMatchingError")
    /// confirm password
    static let repeatPasswordPlaceholder = L10n.tr("createAccount.repeatPasswordPlaceholder")
    /// username already taken
    static let usernameAlreadyTaken = L10n.tr("createAccount.usernameAlreadyTaken")
    /// Adding account
    static let waitCreateAccountTitle = L10n.tr("createAccount.waitCreateAccountTitle")
  }

  enum Createprofile {
    /// Skip to Create Account
    static let createAccount = L10n.tr("createProfile.createAccount")
    /// Skip to Link Device
    static let linkDevice = L10n.tr("createProfile.linkDevice")
  }

  enum Global {
    /// Invitations
    static let contactRequestsTabBarTitle = L10n.tr("global.contactRequestsTabBarTitle")
    /// Home
    static let homeTabBarTitle = L10n.tr("global.homeTabBarTitle")
    /// Me
    static let meTabBarTitle = L10n.tr("global.meTabBarTitle")
    /// Ok
    static let ok = L10n.tr("global.ok")
  }

  enum Smartlist {
    /// Conversations
    static let conversations = L10n.tr("smartlist.conversations")
    /// No results
    static let noResults = L10n.tr("smartlist.noResults")
    /// Searching...
    static let searching = L10n.tr("smartlist.searching")
    /// User found
    static let userFound = L10n.tr("smartlist.userFound")
    /// Yesterday
    static let yesterday = L10n.tr("smartlist.yesterday")
  }

  enum Welcome {
    /// Create a Ring account
    static let createAccount = L10n.tr("welcome.createAccount")
    /// Link this device to an account
    static let linkDevice = L10n.tr("welcome.linkDevice")
    /// Ring is a free and universal communication platform which preserves the users' privacy and freedoms
    static let text = L10n.tr("welcome.text")
    /// Welcome to Ring
    static let title = L10n.tr("welcome.title")
  }
}

	struct LocalizableString {
        let key: String
        let args: [CVarArg]

        /**
         Returns String from Current Bundle
         */
        public var string: String {
            let format: String = NSLocalizedString(key, tableName: nil, bundle: Bundle(for: RingStringsBundleToken.self), value: "", comment: "")
            return String(format: format, locale: Locale.current, arguments: args)
        }

        /**
         Returns String translated from App's Bundle is found, otherwise from Current Bundle
         */
        public var smartString: String {
            // Load from App's Bundle first
            var format: String = NSLocalizedString(key, tableName: nil, bundle: Bundle.main, value: "", comment: "")
            if format != "" && format != key {
                return String(format: format, locale: Locale.current, arguments: args)
            }
            // Load from Current Bundle
            format = NSLocalizedString(key, tableName: nil, bundle: Bundle(for: RingStringsBundleToken.self), value: "", comment: "")

            return String(format: format, locale: Locale.current, arguments: args)
        }
    }

extension L10n {
  fileprivate static func tr(_ key: String, _ args: CVarArg...) -> LocalizableString {
    return LocalizableString(key: key, args: args)
  }
}

// swiftlint:enable type_body_length
// swiftlint:enable nesting
// swiftlint:enable variable_name
// swiftlint:enable valid_docs
