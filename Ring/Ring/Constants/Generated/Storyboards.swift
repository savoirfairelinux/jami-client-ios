// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

// swiftlint:disable sorted_imports
import Foundation
import UIKit

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

internal protocol StoryboardType {
  static var storyboardName: String { get }
}

internal extension StoryboardType {
  static var storyboard: UIStoryboard {
    return UIStoryboard(name: self.storyboardName, bundle: Bundle(for: BundleToken.self))
  }
}

internal struct SceneType<T: Any> {
  internal let storyboard: StoryboardType.Type
  internal let identifier: String

  internal func instantiate() -> T {
    guard let controller = storyboard.storyboard.instantiateViewController(withIdentifier: identifier) as? T else {
      fatalError("ViewController '\(identifier)' is not of the expected class \(T.self).")
    }
    return controller
  }
}

internal struct InitialSceneType<T: Any> {
  internal let storyboard: StoryboardType.Type

  internal func instantiate() -> T {
    guard let controller = storyboard.storyboard.instantiateInitialViewController() as? T else {
      fatalError("ViewController is not of the expected class \(T.self).")
    }
    return controller
  }
}

internal protocol SegueType: RawRepresentable { }

internal extension UIViewController {
  func perform<S: SegueType>(segue: S, sender: Any? = nil) where S.RawValue == String {
    performSegue(withIdentifier: segue.rawValue, sender: sender)
  }
}

// swiftlint:disable explicit_type_interface identifier_name line_length type_body_length type_name
internal enum StoryboardScene {
  internal enum BlockListViewController: StoryboardType {
    internal static let storyboardName = "BlockListViewController"

    internal static let initialScene = InitialSceneType<Ring.BlockListViewController>(storyboard: BlockListViewController.self)
  }
  internal enum CallViewController: StoryboardType {
    internal static let storyboardName = "CallViewController"

    internal static let initialScene = InitialSceneType<Ring.CallViewController>(storyboard: CallViewController.self)
  }
  internal enum ContactRequestsViewController: StoryboardType {
    internal static let storyboardName = "ContactRequestsViewController"

    internal static let initialScene = InitialSceneType<Ring.ContactRequestsViewController>(storyboard: ContactRequestsViewController.self)
  }
  internal enum ContactViewController: StoryboardType {
    internal static let storyboardName = "ContactViewController"

    internal static let initialScene = InitialSceneType<Ring.ContactViewController>(storyboard: ContactViewController.self)
  }
  internal enum ConversationViewController: StoryboardType {
    internal static let storyboardName = "ConversationViewController"

    internal static let initialScene = InitialSceneType<Ring.ConversationViewController>(storyboard: ConversationViewController.self)
  }
  internal enum CreateAccountViewController: StoryboardType {
    internal static let storyboardName = "CreateAccountViewController"

    internal static let initialScene = InitialSceneType<Ring.CreateAccountViewController>(storyboard: CreateAccountViewController.self)
  }
  internal enum CreateProfileViewController: StoryboardType {
    internal static let storyboardName = "CreateProfileViewController"

    internal static let initialScene = InitialSceneType<Ring.CreateProfileViewController>(storyboard: CreateProfileViewController.self)
  }
  internal enum InitialLoadingViewController: StoryboardType {
    internal static let storyboardName = "InitialLoadingViewController"

    internal static let initialScene = InitialSceneType<Ring.InitialLoadingViewController>(storyboard: InitialLoadingViewController.self)

    internal static let initialLoadingViewController = SceneType<Ring.InitialLoadingViewController>(storyboard: InitialLoadingViewController.self, identifier: "InitialLoadingViewController")
  }
  internal enum LaunchScreen: StoryboardType {
    internal static let storyboardName = "LaunchScreen"

    internal static let initialScene = InitialSceneType<UIViewController>(storyboard: LaunchScreen.self)
  }
  internal enum LinkDeviceViewController: StoryboardType {
    internal static let storyboardName = "LinkDeviceViewController"

    internal static let initialScene = InitialSceneType<Ring.LinkDeviceViewController>(storyboard: LinkDeviceViewController.self)
  }
  internal enum LinkNewDeviceViewController: StoryboardType {
    internal static let storyboardName = "LinkNewDeviceViewController"

    internal static let initialScene = InitialSceneType<Ring.LinkNewDeviceViewController>(storyboard: LinkNewDeviceViewController.self)
  }
  internal enum MeViewController: StoryboardType {
    internal static let storyboardName = "MeViewController"

    internal static let initialScene = InitialSceneType<Ring.MeViewController>(storyboard: MeViewController.self)
  }
  internal enum ScanViewController: StoryboardType {
    internal static let storyboardName = "ScanViewController"

    internal static let initialScene = InitialSceneType<Ring.ScanViewController>(storyboard: ScanViewController.self)
  }
  internal enum SmartlistViewController: StoryboardType {
    internal static let storyboardName = "SmartlistViewController"

    internal static let initialScene = InitialSceneType<Ring.SmartlistViewController>(storyboard: SmartlistViewController.self)
  }
  internal enum WelcomeViewController: StoryboardType {
    internal static let storyboardName = "WelcomeViewController"

    internal static let initialScene = InitialSceneType<Ring.WelcomeViewController>(storyboard: WelcomeViewController.self)
  }
}

internal enum StoryboardSegue {
}
// swiftlint:enable explicit_type_interface identifier_name line_length type_body_length type_name

private final class BundleToken {}
