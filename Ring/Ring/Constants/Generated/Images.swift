// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ColorAsset.Color", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetColorTypeAlias = ColorAsset.Color
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal static let localisationsReceiveBlack = ImageAsset(name: "Localisations_Receive_Black")
  internal static let localisationsSendBlack = ImageAsset(name: "Localisations_Send_Black")
  internal static let accountIcon = ImageAsset(name: "account_icon")
  internal static let addPeopleInSwarm = ImageAsset(name: "addPeopleInSwarm")
  internal static let addAvatar = ImageAsset(name: "add_avatar")
  internal static let addPerson = ImageAsset(name: "add_person")
  internal static let attachmentIcon = ImageAsset(name: "attachment_icon")
  internal static let audioMuted = ImageAsset(name: "audio_muted")
  internal static let audioOff = ImageAsset(name: "audio_off")
  internal static let audioOn = ImageAsset(name: "audio_on")
  internal static let audioRunning = ImageAsset(name: "audio_running")
  internal static let backButton = ImageAsset(name: "back_button")
  internal static let backgroundInputText = ColorAsset(name: "background_input_text")
  internal static let backgroundLogin = ImageAsset(name: "background_login")
  internal static let backgroundMsgReceived = ColorAsset(name: "background_msg_received")
  internal static let blockIcon = ImageAsset(name: "block_icon")
  internal static let blockSymbol = SymbolAsset(name: "block_symbol")
  internal static let callButton = ImageAsset(name: "call_button")
  internal static let camera = ImageAsset(name: "camera")
  internal static let clearConversation = ImageAsset(name: "clear_conversation")
  internal static let closeIcon = ImageAsset(name: "close_icon")
  internal static let contactRequestIcon = ImageAsset(name: "contact_request_icon")
  internal static let conversationIcon = ImageAsset(name: "conversation_icon")
  internal static let createSwarm = ImageAsset(name: "createSwarm")
  internal static let cross = ImageAsset(name: "cross")
  internal static let device = ImageAsset(name: "device")
  internal static let dialpad = ImageAsset(name: "dialpad")
  internal static let disableSpeakerphone = ImageAsset(name: "disable_speakerphone")
  internal static let donation = ImageAsset(name: "donation")
  internal static let doneIcon = ImageAsset(name: "done_icon")
  internal static let downloadIcon = ImageAsset(name: "download_icon")
  internal static let editSwarmImage = ImageAsset(name: "editSwarmImage")
  internal static let enableSpeakerphone = ImageAsset(name: "enable_speakerphone")
  internal static let fallbackAvatar = ImageAsset(name: "fallback_avatar")
  internal static let icBack = ImageAsset(name: "ic_back")
  internal static let icContactPicture = ImageAsset(name: "ic_contact_picture")
  internal static let icConversationRemove = ImageAsset(name: "ic_conversation_remove")
  internal static let icForward = ImageAsset(name: "ic_forward")
  internal static let icHideInput = ImageAsset(name: "ic_hide_input")
  internal static let icSave = ImageAsset(name: "ic_save")
  internal static let icShare = ImageAsset(name: "ic_share")
  internal static let icShowInput = ImageAsset(name: "ic_show_input")
  internal static let infoArrow = ImageAsset(name: "info_arrow")
  internal static let jamiIcon = ImageAsset(name: "jamiIcon")
  internal static let jamiLogo = ImageAsset(name: "jamiLogo")
  internal static let jamiGnupackage = ImageAsset(name: "jami_gnupackage")
  internal static let leftArrow = ImageAsset(name: "left_arrow")
  internal static let messageBackgroundColor = ColorAsset(name: "message_background_color")
  internal static let messageSentIndicator = ImageAsset(name: "message_sent_indicator")
  internal static let moderator = ImageAsset(name: "moderator")
  internal static let moreSettings = ImageAsset(name: "more_settings")
  internal static let myLocation = ImageAsset(name: "my_location")
  internal static let pauseCall = ImageAsset(name: "pause_call")
  internal static let phoneBook = ImageAsset(name: "phone_book")
  internal static let qrCode = ImageAsset(name: "qr_code")
  internal static let qrCodeScan = ImageAsset(name: "qr_code_scan")
  internal static let raiseHand = ImageAsset(name: "raise_hand")
  internal static let revokeDevice = ImageAsset(name: "revoke_device")
  internal static let rowSelected = ColorAsset(name: "row_selected")
  internal static let scan = ImageAsset(name: "scan")
  internal static let sendButton = ImageAsset(name: "send_button")
  internal static let settings = ImageAsset(name: "settings")
  internal static let settingsIcon = ImageAsset(name: "settings_icon")
  internal static let shadowColor = ColorAsset(name: "shadow_color")
  internal static let shareButton = ImageAsset(name: "share_button")
  internal static let stopCall = ImageAsset(name: "stop_call")
  internal static let switchCamera = ImageAsset(name: "switch_camera")
  internal static let textBlueColor = ColorAsset(name: "text_blue_color")
  internal static let textFieldBackgroundColor = ColorAsset(name: "text_field_background_color")
  internal static let textSecondaryColor = ColorAsset(name: "text_secondary_color")
  internal static let unpauseCall = ImageAsset(name: "unpause_call")
  internal static let videoMuted = ImageAsset(name: "video_muted")
  internal static let videoRunning = ImageAsset(name: "video_running")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal final class ColorAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  internal private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  #if os(iOS) || os(tvOS)
  @available(iOS 11.0, tvOS 11.0, *)
  internal func color(compatibleWith traitCollection: UITraitCollection) -> Color {
    let bundle = BundleToken.bundle
    guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal private(set) lazy var swiftUIColor: SwiftUI.Color = {
    SwiftUI.Color(asset: self)
  }()
  #endif

  fileprivate init(name: String) {
    self.name = name
  }
}

internal extension ColorAsset.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  convenience init?(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Color {
  init(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }
}
#endif

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  internal func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

internal extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: ImageAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

internal struct SymbolAsset {
  internal fileprivate(set) var name: String

  #if os(iOS) || os(tvOS) || os(watchOS)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  internal typealias Configuration = UIImage.SymbolConfiguration
  internal typealias Image = UIImage

  @available(iOS 12.0, tvOS 12.0, watchOS 5.0, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load symbol asset named \(name).")
    }
    return result
  }

  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  internal func image(with configuration: Configuration) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, with: configuration) else {
      fatalError("Unable to load symbol asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: SymbolAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: SymbolAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: SymbolAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
