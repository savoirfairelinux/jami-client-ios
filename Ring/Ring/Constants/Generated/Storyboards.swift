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
  enum ConversationViewController: StoryboardSceneType {
    static let storyboardName = "ConversationViewController"

    static func initialViewController() -> Ring.ConversationViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.ConversationViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
  enum CreateAccountViewController: StoryboardSceneType {
    static let storyboardName = "CreateAccountViewController"

    static func initialViewController() -> Ring.CreateAccountViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.CreateAccountViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
  enum CreateProfileViewController: StoryboardSceneType {
    static let storyboardName = "CreateProfileViewController"

    static func initialViewController() -> Ring.CreateProfileViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.CreateProfileViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
  enum LaunchScreen: StoryboardSceneType {
    static let storyboardName = "LaunchScreen"
  }
  enum LinkDeviceViewController: StoryboardSceneType {
    static let storyboardName = "LinkDeviceViewController"

    static func initialViewController() -> Ring.LinkDeviceViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.LinkDeviceViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
  enum MeDetailViewController: StoryboardSceneType {
    static let storyboardName = "MeDetailViewController"

    static func initialViewController() -> Ring.MeDetailViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.MeDetailViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
  enum MeViewController: StoryboardSceneType {
    static let storyboardName = "MeViewController"

    static func initialViewController() -> Ring.MeViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.MeViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
  enum SmartlistViewController: StoryboardSceneType {
    static let storyboardName = "SmartlistViewController"

    static func initialViewController() -> Ring.SmartlistViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.SmartlistViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
  enum WelcomeViewController: StoryboardSceneType {
    static let storyboardName = "WelcomeViewController"

    static func initialViewController() -> Ring.WelcomeViewController {
      guard let vc = storyboard().instantiateInitialViewController() as? Ring.WelcomeViewController else {
        fatalError("Failed to instantiate initialViewController for \(self.storyboardName)")
      }
      return vc
    }
  }
}

enum StoryboardSegue {
}

private final class BundleToken {}
