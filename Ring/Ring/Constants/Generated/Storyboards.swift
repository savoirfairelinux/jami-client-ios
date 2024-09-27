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
  internal enum CallViewController: StoryboardType {
    internal static let storyboardName = "CallViewController"

    internal static let initialScene = InitialSceneType<Ring.CallViewController>(storyboard: CallViewController.self)
  }

    internal enum SwarmCreationViewController: StoryboardType {
      internal static let storyboardName = "SwarmCreationViewController"

      internal static let initialScene = InitialSceneType<Ring.SwarmCreationViewController>(storyboard: SwarmCreationViewController.self)
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
  internal enum InitialLoadingViewController: StoryboardType {
    internal static let storyboardName = "InitialLoadingViewController"

    internal static let initialScene = InitialSceneType<Ring.InitialLoadingViewController>(storyboard: InitialLoadingViewController.self)

    internal static let initialLoadingViewController = SceneType<Ring.InitialLoadingViewController>(storyboard: InitialLoadingViewController.self, identifier: "InitialLoadingViewController")
  }
  internal enum LaunchScreen: StoryboardType {
    internal static let storyboardName = "LaunchScreen"

    internal static let initialScene = InitialSceneType<UIViewController>(storyboard: LaunchScreen.self)
  }

  internal enum ScanViewController: StoryboardType {
    internal static let storyboardName = "ScanViewController"

    internal static let initialScene = InitialSceneType<Ring.ScanViewController>(storyboard: ScanViewController.self)
  }
}

internal enum StoryboardSegue {
}
// swiftlint:enable explicit_type_interface identifier_name line_length type_body_length type_name

private final class BundleToken {}
