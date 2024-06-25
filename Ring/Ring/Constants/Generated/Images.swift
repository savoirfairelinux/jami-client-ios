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
@available(
    *,
    deprecated,
    renamed: "ColorAsset.Color",
    message: "This typealias will be removed in SwiftGen 7.0"
)
typealias AssetColorTypeAlias = ColorAsset.Color
@available(
    *,
    deprecated,
    renamed: "ImageAsset.Image",
    message: "This typealias will be removed in SwiftGen 7.0"
)
typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
enum Asset {
    static let localisationsReceiveBlack = ImageAsset(name: "Localisations_Receive_Black")
    static let localisationsSendBlack = ImageAsset(name: "Localisations_Send_Black")
    static let accountIcon = ImageAsset(name: "account_icon")
    static let addPeopleInSwarm = ImageAsset(name: "addPeopleInSwarm")
    static let addAvatar = ImageAsset(name: "add_avatar")
    static let addPerson = ImageAsset(name: "add_person")
    static let attachmentIcon = ImageAsset(name: "attachment_icon")
    static let audioMuted = ImageAsset(name: "audio_muted")
    static let audioOff = ImageAsset(name: "audio_off")
    static let audioOn = ImageAsset(name: "audio_on")
    static let audioRunning = ImageAsset(name: "audio_running")
    static let backButton = ImageAsset(name: "back_button")
    static let backgroundInputText = ColorAsset(name: "background_input_text")
    static let backgroundLogin = ImageAsset(name: "background_login")
    static let backgroundMsgReceived = ColorAsset(name: "background_msg_received")
    static let blockIcon = ImageAsset(name: "block_icon")
    static let blockSymbol = SymbolAsset(name: "block_symbol")
    static let callButton = ImageAsset(name: "call_button")
    static let camera = ImageAsset(name: "camera")
    static let clearConversation = ImageAsset(name: "clear_conversation")
    static let closeIcon = ImageAsset(name: "close_icon")
    static let contactRequestIcon = ImageAsset(name: "contact_request_icon")
    static let conversationIcon = ImageAsset(name: "conversation_icon")
    static let createSwarm = ImageAsset(name: "createSwarm")
    static let cross = ImageAsset(name: "cross")
    static let device = ImageAsset(name: "device")
    static let dialpad = ImageAsset(name: "dialpad")
    static let disableSpeakerphone = ImageAsset(name: "disable_speakerphone")
    static let donation = ImageAsset(name: "donation")
    static let doneIcon = ImageAsset(name: "done_icon")
    static let downloadIcon = ImageAsset(name: "download_icon")
    static let editSwarmImage = ImageAsset(name: "editSwarmImage")
    static let enableSpeakerphone = ImageAsset(name: "enable_speakerphone")
    static let fallbackAvatar = ImageAsset(name: "fallback_avatar")
    static let icBack = ImageAsset(name: "ic_back")
    static let icContactPicture = ImageAsset(name: "ic_contact_picture")
    static let icConversationRemove = ImageAsset(name: "ic_conversation_remove")
    static let icForward = ImageAsset(name: "ic_forward")
    static let icHideInput = ImageAsset(name: "ic_hide_input")
    static let icSave = ImageAsset(name: "ic_save")
    static let icShare = ImageAsset(name: "ic_share")
    static let icShowInput = ImageAsset(name: "ic_show_input")
    static let infoArrow = ImageAsset(name: "info_arrow")
    static let jamiIcon = ImageAsset(name: "jamiIcon")
    static let jamiLogo = ImageAsset(name: "jamiLogo")
    static let jamiGnupackage = ImageAsset(name: "jami_gnupackage")
    static let leftArrow = ImageAsset(name: "left_arrow")
    static let messageBackgroundColor = ColorAsset(name: "message_background_color")
    static let messageSentIndicator = ImageAsset(name: "message_sent_indicator")
    static let moderator = ImageAsset(name: "moderator")
    static let moreSettings = ImageAsset(name: "more_settings")
    static let myLocation = ImageAsset(name: "my_location")
    static let pauseCall = ImageAsset(name: "pause_call")
    static let phoneBook = ImageAsset(name: "phone_book")
    static let qrCode = ImageAsset(name: "qr_code")
    static let qrCodeScan = ImageAsset(name: "qr_code_scan")
    static let raiseHand = ImageAsset(name: "raise_hand")
    static let revokeDevice = ImageAsset(name: "revoke_device")
    static let rowSelected = ColorAsset(name: "row_selected")
    static let scan = ImageAsset(name: "scan")
    static let sendButton = ImageAsset(name: "send_button")
    static let settings = ImageAsset(name: "settings")
    static let settingsIcon = ImageAsset(name: "settings_icon")
    static let shadowColor = ColorAsset(name: "shadow_color")
    static let shareButton = ImageAsset(name: "share_button")
    static let stopCall = ImageAsset(name: "stop_call")
    static let switchCamera = ImageAsset(name: "switch_camera")
    static let textBlueColor = ColorAsset(name: "text_blue_color")
    static let textFieldBackgroundColor = ColorAsset(name: "text_field_background_color")
    static let textSecondaryColor = ColorAsset(name: "text_secondary_color")
    static let unpauseCall = ImageAsset(name: "unpause_call")
    static let videoMuted = ImageAsset(name: "video_muted")
    static let videoRunning = ImageAsset(name: "video_running")
}

// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

final class ColorAsset {
    fileprivate(set) var name: String

    #if os(macOS)
        typealias Color = NSColor
    #elseif os(iOS) || os(tvOS) || os(watchOS)
        typealias Color = UIColor
    #endif

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
    private(set) lazy var color: Color = {
        guard let color = Color(asset: self) else {
            fatalError("Unable to load color asset named \(name).")
        }
        return color
    }()

    #if os(iOS) || os(tvOS)
        @available(iOS 11.0, tvOS 11.0, *)
        func color(compatibleWith traitCollection: UITraitCollection) -> Color {
            let bundle = BundleToken.bundle
            guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
                fatalError("Unable to load color asset named \(name).")
            }
            return color
        }
    #endif

    #if canImport(SwiftUI)
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
        private(set) lazy var swiftUIColor: SwiftUI.Color = .init(asset: self)
    #endif

    fileprivate init(name: String) {
        self.name = name
    }
}

extension ColorAsset.Color {
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
    extension SwiftUI.Color {
        init(asset: ColorAsset) {
            let bundle = BundleToken.bundle
            self.init(asset.name, bundle: bundle)
        }
    }
#endif

struct ImageAsset {
    fileprivate(set) var name: String

    #if os(macOS)
        typealias Image = NSImage
    #elseif os(iOS) || os(tvOS) || os(watchOS)
        typealias Image = UIImage
    #endif

    @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
    var image: Image {
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
        func image(compatibleWith traitCollection: UITraitCollection) -> Image {
            let bundle = BundleToken.bundle
            guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection)
            else {
                fatalError("Unable to load image asset named \(name).")
            }
            return result
        }
    #endif

    #if canImport(SwiftUI)
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
        var swiftUIImage: SwiftUI.Image {
            SwiftUI.Image(asset: self)
        }
    #endif
}

extension ImageAsset.Image {
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
    extension SwiftUI.Image {
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

struct SymbolAsset {
    fileprivate(set) var name: String

    #if os(iOS) || os(tvOS) || os(watchOS)
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
        typealias Configuration = UIImage.SymbolConfiguration
        typealias Image = UIImage

        @available(iOS 12.0, tvOS 12.0, watchOS 5.0, *)
        var image: Image {
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
        func image(with configuration: Configuration) -> Image {
            let bundle = BundleToken.bundle
            guard let result = Image(named: name, in: bundle, with: configuration) else {
                fatalError("Unable to load symbol asset named \(name).")
            }
            return result
        }
    #endif

    #if canImport(SwiftUI)
        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
        var swiftUIImage: SwiftUI.Image {
            SwiftUI.Image(asset: self)
        }
    #endif
}

#if canImport(SwiftUI)
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    extension SwiftUI.Image {
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
