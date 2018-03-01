// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

#if os(OSX)
  import AppKit.NSImage
  typealias AssetColorTypeAlias = NSColor
  typealias Image = NSImage
#elseif os(iOS) || os(tvOS) || os(watchOS)
  import UIKit.UIImage
  typealias AssetColorTypeAlias = UIColor
  typealias Image = UIImage
#endif

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

@available(*, deprecated, renamed: "ImageAsset")
typealias AssetType = ImageAsset

struct ImageAsset {
  fileprivate var name: String

  var image: Image {
    let bundle = Bundle(for: BundleToken.self)
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(OSX)
    let image = bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else { fatalError("Unable to load image named \(name).") }
    return result
  }
}

struct ColorAsset {
  fileprivate var name: String

  #if swift(>=3.2)
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, OSX 10.13, *)
  var color: AssetColorTypeAlias {
    return AssetColorTypeAlias(asset: self)
  }
  #endif
}

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
enum Asset {
  static let accountIcon = ImageAsset(name: "account_icon")
  static let addPerson = ImageAsset(name: "add_person")
  static let attachmentIcon = ImageAsset(name: "attachment_icon")
  static let audioMuted = ImageAsset(name: "audio_muted")
  static let audioRunning = ImageAsset(name: "audio_running")
  static let backButton = ImageAsset(name: "back_button")
  static let backgroundRing = ImageAsset(name: "background_ring")
  static let blockIcon = ImageAsset(name: "block_icon")
  static let callButton = ImageAsset(name: "call_button")
  static let clearConversation = ImageAsset(name: "clear_conversation")
  static let closeIcon = ImageAsset(name: "close_icon")
  static let contactRequestIcon = ImageAsset(name: "contact_request_icon")
  static let conversationIcon = ImageAsset(name: "conversation_icon")
  static let device = ImageAsset(name: "device")
  static let disableSpeakerphone = ImageAsset(name: "disable_speakerphone")
  static let doneIcon = ImageAsset(name: "done_icon")
  static let downloadIcon = ImageAsset(name: "download_icon")
  static let enableSpeakerphone = ImageAsset(name: "enable_speakerphone")
  static let fallbackAvatar = ImageAsset(name: "fallback_avatar")
  static let icContactPicture = ImageAsset(name: "ic_contact_picture")
  static let moreSettings = ImageAsset(name: "more_settings")
  static let pauseCall = ImageAsset(name: "pause_call")
  static let ringIcon = ImageAsset(name: "ringIcon")
  static let ringLogo = ImageAsset(name: "ring_logo")
  static let sendButton = ImageAsset(name: "send_button")
  static let settingsIcon = ImageAsset(name: "settings_icon")
  static let shareButton = ImageAsset(name: "share_button")
  static let stopCall = ImageAsset(name: "stop_call")
  static let switchCamera = ImageAsset(name: "switch_camera")
  static let unpauseCall = ImageAsset(name: "unpause_call")
  static let videoMuted = ImageAsset(name: "video_muted")
  static let videoRunning = ImageAsset(name: "video_running")

  // swiftlint:disable trailing_comma
  static let allColors: [ColorAsset] = [
  ]
  static let allImages: [ImageAsset] = [
    accountIcon,
    addPerson,
    attachmentIcon,
    audioMuted,
    audioRunning,
    backButton,
    backgroundRing,
    blockIcon,
    callButton,
    clearConversation,
    closeIcon,
    contactRequestIcon,
    conversationIcon,
    device,
    disableSpeakerphone,
    doneIcon,
    downloadIcon,
    enableSpeakerphone,
    fallbackAvatar,
    icContactPicture,
    moreSettings,
    pauseCall,
    ringIcon,
    ringLogo,
    sendButton,
    settingsIcon,
    shareButton,
    stopCall,
    switchCamera,
    unpauseCall,
    videoMuted,
    videoRunning,
  ]
  // swiftlint:enable trailing_comma
  @available(*, deprecated, renamed: "allImages")
  static let allValues: [AssetType] = allImages
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

extension Image {
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

extension AssetColorTypeAlias {
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

private final class BundleToken {}
