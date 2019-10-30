// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(OSX)
  import AppKit.NSImage
  internal typealias AssetColorTypeAlias = NSColor
  internal typealias AssetImageTypeAlias = NSImage
#elseif os(iOS) || os(tvOS) || os(watchOS)
  import UIKit.UIImage
  internal typealias AssetColorTypeAlias = UIColor
  internal typealias AssetImageTypeAlias = UIImage
#endif

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal static let accountIcon = ImageAsset(name: "account_icon")
  internal static let addAvatar = ImageAsset(name: "add_avatar")
  internal static let addPerson = ImageAsset(name: "add_person")
  internal static let attachmentIcon = ImageAsset(name: "attachment_icon")
  internal static let audioMuted = ImageAsset(name: "audio_muted")
  internal static let audioRunning = ImageAsset(name: "audio_running")
  internal static let backButton = ImageAsset(name: "back_button")
  internal static let backgroundRing = ImageAsset(name: "background_ring")
  internal static let blockIcon = ImageAsset(name: "block_icon")
  internal static let callButton = ImageAsset(name: "call_button")
  internal static let camera = ImageAsset(name: "camera")
  internal static let clearConversation = ImageAsset(name: "clear_conversation")
  internal static let closeIcon = ImageAsset(name: "close_icon")
  internal static let contactRequestIcon = ImageAsset(name: "contact_request_icon")
  internal static let conversationIcon = ImageAsset(name: "conversation_icon")
  internal static let cross = ImageAsset(name: "cross")
  internal static let device = ImageAsset(name: "device")
  internal static let dialpad = ImageAsset(name: "dialpad")
  internal static let disableSpeakerphone = ImageAsset(name: "disable_speakerphone")
  internal static let doneIcon = ImageAsset(name: "done_icon")
  internal static let downloadIcon = ImageAsset(name: "download_icon")
  internal static let enableSpeakerphone = ImageAsset(name: "enable_speakerphone")
  internal static let fallbackAvatar = ImageAsset(name: "fallback_avatar")
  internal static let icContactPicture = ImageAsset(name: "ic_contact_picture")
  internal static let icConversationRemove = ImageAsset(name: "ic_conversation_remove")
  internal static let icHideInput = ImageAsset(name: "ic_hide_input")
  internal static let icShowInput = ImageAsset(name: "ic_show_input")
  internal static let infoArrow = ImageAsset(name: "info_arrow")
  internal static let jamiIcon = ImageAsset(name: "jamiIcon")
  internal static let jamiLogo = ImageAsset(name: "jamiLogo")
  internal static let leftArrow = ImageAsset(name: "left_arrow")
  internal static let moreSettings = ImageAsset(name: "more_settings")
  internal static let pauseCall = ImageAsset(name: "pause_call")
  internal static let phoneBook = ImageAsset(name: "phone_book")
  internal static let qrCode = ImageAsset(name: "qr_code")
  internal static let qrCodeScan = ImageAsset(name: "qr_code_scan")
  internal static let revokeDevice = ImageAsset(name: "revoke_device")
  internal static let ringLogo = ImageAsset(name: "ring_logo")
  internal static let scan = ImageAsset(name: "scan")
  internal static let sendButton = ImageAsset(name: "send_button")
  internal static let settings = ImageAsset(name: "settings")
  internal static let settingsIcon = ImageAsset(name: "settings_icon")
  internal static let shareButton = ImageAsset(name: "share_button")
  internal static let stopCall = ImageAsset(name: "stop_call")
  internal static let switchCamera = ImageAsset(name: "switch_camera")
  internal static let unpauseCall = ImageAsset(name: "unpause_call")
  internal static let videoMuted = ImageAsset(name: "video_muted")
  internal static let videoRunning = ImageAsset(name: "video_running")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal struct ColorAsset {
  internal fileprivate(set) var name: String

  #if swift(>=3.2)
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, OSX 10.13, *)
  internal var color: AssetColorTypeAlias {
    return AssetColorTypeAlias(asset: self)
  }
  #endif
}

internal extension AssetColorTypeAlias {
  #if swift(>=3.2)
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, OSX 10.13, *)
  convenience init!(asset: ColorAsset) {
    let bundle = Bundle(for: BundleToken.self)
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(OSX)
    self.init(named: asset.name, bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
  #endif
}

internal struct DataAsset {
  internal fileprivate(set) var name: String

  #if (os(iOS) || os(tvOS) || os(OSX)) && swift(>=3.2)
  @available(iOS 9.0, tvOS 9.0, OSX 10.11, *)
  internal var data: NSDataAsset {
    return NSDataAsset(asset: self)
  }
  #endif
}

#if (os(iOS) || os(tvOS) || os(OSX)) && swift(>=3.2)
@available(iOS 9.0, tvOS 9.0, OSX 10.11, *)
internal extension NSDataAsset {
  convenience init!(asset: DataAsset) {
    let bundle = Bundle(for: BundleToken.self)
    self.init(name: asset.name, bundle: bundle)
  }
}
#endif

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  internal var image: AssetImageTypeAlias {
    let bundle = Bundle(for: BundleToken.self)
    #if os(iOS) || os(tvOS)
    let image = AssetImageTypeAlias(named: name, in: bundle, compatibleWith: nil)
    #elseif os(OSX)
    let image = bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = AssetImageTypeAlias(named: name)
    #endif
    guard let result = image else { fatalError("Unable to load image named \(name).") }
    return result
  }
}

internal extension AssetImageTypeAlias {
  @available(iOS 1.0, tvOS 1.0, watchOS 1.0, *)
  @available(OSX, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init!(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = Bundle(for: BundleToken.self)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(OSX) || os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

private final class BundleToken {}
