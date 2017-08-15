// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

// swiftlint:disable sorted_imports
import Foundation
import UIKit

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
  enum LaunchScreen: StoryboardType {
    static let storyboardName = "LaunchScreen"

    static let initialScene = InitialSceneType<UIViewController>(storyboard: LaunchScreen.self)
  }
  enum Main: StoryboardType {
    static let storyboardName = "Main"

    static let initialScene = InitialSceneType<Ring.MainTabBarViewController>(storyboard: Main.self)

    static let mainStoryboard = SceneType<Ring.MainTabBarViewController>(storyboard: Main.self, identifier: "MainStoryboard")
  }
  enum WalkthroughStoryboard: StoryboardType {
    static let storyboardName = "WalkthroughStoryboard"

    static let initialScene = InitialSceneType<UINavigationController>(storyboard: WalkthroughStoryboard.self)
  }
}

enum StoryboardSegue {
  enum Main: String, SegueType {
    case showMessages = "ShowMessages"
    case accountDetails
  }
  enum WalkthroughStoryboard: String, SegueType {
    case accountToPermissionsSegue = "AccountToPermissionsSegue"
    case createProfileSegue = "CreateProfileSegue"
    case linkDeviceToAccountSegue = "LinkDeviceToAccountSegue"
    case profileToAccountSegue = "ProfileToAccountSegue"
    case profileToLinkSegue = "ProfileToLinkSegue"
  }
}
// swiftlint:enable explicit_type_interface identifier_name line_length type_body_length type_name

private final class BundleToken {}
