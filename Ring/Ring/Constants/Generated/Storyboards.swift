// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

import Foundation
import UIKit

// swiftlint:disable file_length
// swiftlint:disable line_length
// swiftlint:disable type_body_length

protocol StoryboardSceneType {
  static var storyboardName: String { get }
}

extension StoryboardSceneType {
  static func storyboard() -> UIStoryboard {
    return UIStoryboard(name: self.storyboardName, bundle: Bundle(for: BundleToken.self))
  }

  static func initialViewController() -> UIViewController {
    guard let vc = storyboard().instantiateInitialViewController() else {
      fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
    }
    return vc
  }
}

extension StoryboardSceneType where Self: RawRepresentable, Self.RawValue == String {
  func viewController() -> UIViewController {
    return Self.storyboard().instantiateViewController(withIdentifier: self.rawValue)
  }
  static func viewController(identifier: Self) -> UIViewController {
    return identifier.viewController()
  }
}

protocol StoryboardSegueType: RawRepresentable { }

extension UIViewController {
  func perform<S: StoryboardSegueType>(segue: S, sender: Any? = nil) where S.RawValue == String {
    performSegue(withIdentifier: segue.rawValue, sender: sender)
  }
}

enum StoryboardScene {
  enum LaunchScreen: StoryboardSceneType {
    static let storyboardName = "LaunchScreen"
  }
  enum Main: StoryboardSceneType {
    static let storyboardName = "Main"

    static func initialViewController() -> Ring.MainTabBarViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.MainTabBarViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
  enum WalkthroughStoryboard: StoryboardSceneType {
    static let storyboardName = "WalkthroughStoryboard"

    static func initialViewController() -> UINavigationController {
      guard let vc = storyboard().instantiateInitialViewController() as? UINavigationController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
}

enum StoryboardSegue {
  enum Main: String, StoryboardSegueType {
    case showMessages = "ShowMessages"
    case accountDetails
  }
  enum WalkthroughStoryboard: String, StoryboardSegueType {
    case accountToPermissionsSegue = "AccountToPermissionsSegue"
    case createProfileSegue = "CreateProfileSegue"
    case linkDeviceToAccountSegue = "LinkDeviceToAccountSegue"
    case profileToAccountSegue = "ProfileToAccountSegue"
    case profileToLinkSegue = "ProfileToLinkSegue"
  }
}

private final class BundleToken {}
