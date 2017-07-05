// Generated using SwiftGen, by O.Halligon — https://github.com/AliSoftware/SwiftGen

#if os(iOS) || os(tvOS) || os(watchOS)
  import UIKit.UIImage
  public typealias Image = UIImage
#elseif os(OSX)
  import AppKit.NSImage
  public typealias Image = NSImage
#endif

private class RingImagesBundleToken {}

// swiftlint:disable file_length
// swiftlint:disable line_length

// swiftlint:disable type_body_length
public enum RingAsset: String {
  case icContactPicture = "ic_contact_picture"
  case logoRingBeta2Blanc = "logo-ring-beta2-blanc"

  /** 
    Loads from application's Bundle if image exists, then loads from current bundle, fatalError if image does not exist
  */
  public var smartImage: Image {
    if let appimage = Image(named: self.rawValue, in: nil, compatibleWith: nil) {
      return appimage
    } else if let fmkImage = Image(named: self.rawValue, in: Bundle(for: RingImagesBundleToken.self), compatibleWith: nil) {
      return fmkImage
    } else {
      fatalError("Impossible to load image \(self.rawValue)")
    }
  }

  var image: Image {
	if let img = Image(named: self.rawValue, in: Bundle(for: RingImagesBundleToken.self), compatibleWith: nil) {
        return img
    }
    fatalError("Impossible to load image \(self.rawValue)")
  }
}
// swiftlint:enable type_body_length

public extension Image {
  convenience init!(asset: RingAsset) {
    self.init(named: asset.rawValue)
  }
}
