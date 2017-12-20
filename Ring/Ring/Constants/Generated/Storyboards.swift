// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

// swiftlint:disable sorted_imports
import Foundation
import UIKit

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

protocol StoryboardType {
  static var storyboardName: String { get }
}

extension StoryboardType {
  static var storyboard: UIStoryboard {
    return UIStoryboard(name: self.storyboardName, bundle: Bundle(for: BundleToken.self))
  }
}

struct SceneType<T: Any> {
  let storyboard: StoryboardType.Type
  let identifier: String

  func instantiate() -> T {
    guard let controller = storyboard.storyboard.instantiateViewController(withIdentifier: identifier) as? T else {
      fatalError("ViewController '\(identifier)' is not of the expected class \(T.self).")
    }
    return controller
  }
}

struct InitialSceneType<T: Any> {
  let storyboard: StoryboardType.Type

  func instantiate() -> T {
    guard let controller = storyboard.storyboard.instantiateInitialViewController() as? T else {
      fatalError("ViewController is not of the expected class \(T.self).")
    }
    return controller
  }
}

protocol SegueType: RawRepresentable { }

extension UIViewController {
  func perform<S: SegueType>(segue: S, sender: Any? = nil) where S.RawValue == String {
    performSegue(withIdentifier: segue.rawValue, sender: sender)
  }
}

// swiftlint:disable explicit_type_interface identifier_name line_length type_body_length type_name
enum StoryboardScene {
  enum CallViewController: StoryboardType {
    static let storyboardName = "CallViewController"

    static let initialScene = InitialSceneType<Ring.CallViewController>(storyboard: CallViewController.self)
  }
  enum ContactRequestsViewController: StoryboardType {
    static let storyboardName = "ContactRequestsViewController"

    static let initialScene = InitialSceneType<Ring.ContactRequestsViewController>(storyboard: ContactRequestsViewController.self)
  }
  enum ConversationViewController: StoryboardType {
    static let storyboardName = "ConversationViewController"

    static let initialScene = InitialSceneType<Ring.ConversationViewController>(storyboard: ConversationViewController.self)
  }
  enum CreateAccountViewController: StoryboardType {
    static let storyboardName = "CreateAccountViewController"

    static let initialScene = InitialSceneType<Ring.CreateAccountViewController>(storyboard: CreateAccountViewController.self)
  }
  enum CreateProfileViewController: StoryboardType {
    static let storyboardName = "CreateProfileViewController"

    static let initialScene = InitialSceneType<Ring.CreateProfileViewController>(storyboard: CreateProfileViewController.self)
  }
  enum LaunchScreen: StoryboardType {
    static let storyboardName = "LaunchScreen"

    static let initialScene = InitialSceneType<UIViewController>(storyboard: LaunchScreen.self)
  }
  enum LinkDeviceViewController: StoryboardType {
    static let storyboardName = "LinkDeviceViewController"

    static let initialScene = InitialSceneType<Ring.LinkDeviceViewController>(storyboard: LinkDeviceViewController.self)
  }
  enum LinkNewDeviceViewController: StoryboardType {
    static let storyboardName = "LinkNewDeviceViewController"

    static let initialScene = InitialSceneType<Ring.LinkNewDeviceViewController>(storyboard: LinkNewDeviceViewController.self)
  }
  enum MeDetailViewController: StoryboardType {
    static let storyboardName = "MeDetailViewController"

    static let initialScene = InitialSceneType<Ring.MeDetailViewController>(storyboard: MeDetailViewController.self)
  }
  enum MeViewController: StoryboardType {
    static let storyboardName = "MeViewController"

    static let initialScene = InitialSceneType<Ring.MeViewController>(storyboard: MeViewController.self)
  }
  enum SmartlistViewController: StoryboardType {
    static let storyboardName = "SmartlistViewController"

    static let initialScene = InitialSceneType<Ring.SmartlistViewController>(storyboard: SmartlistViewController.self)
  }
  enum WelcomeViewController: StoryboardType {
    static let storyboardName = "WelcomeViewController"

    static let initialScene = InitialSceneType<Ring.WelcomeViewController>(storyboard: WelcomeViewController.self)
  }
}

enum StoryboardSegue {
}
// swiftlint:enable explicit_type_interface identifier_name line_length type_body_length type_name

private final class BundleToken {}
