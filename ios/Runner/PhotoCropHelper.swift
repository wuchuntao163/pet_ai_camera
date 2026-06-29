import Foundation
import CoreImage
import ImageIO
import MobileCoreServices

struct CropParams {
  let ratio: Double
  let screenWidth: Double
  let screenHeight: Double
  let topInset: Double
  let bottomInset: Double
  let frameAlignY: Double
  let previewAspect: Double
  let fitContain: Bool
  let fullScreenPreview: Bool
  let fullScreen: Bool
  let nativeSensor: Bool
  let directOutput: Bool
  let mirrorFront: Bool

  static func from(_ map: [String: Any]?) -> CropParams? {
    guard let map else { return nil }
    return CropParams(
      ratio: (map["ratio"] as? NSNumber)?.doubleValue ?? 0,
      screenWidth: (map["screenWidth"] as? NSNumber)?.doubleValue ?? 0,
      screenHeight: (map["screenHeight"] as? NSNumber)?.doubleValue ?? 0,
      topInset: (map["topInset"] as? NSNumber)?.doubleValue ?? 0,
      bottomInset: (map["bottomInset"] as? NSNumber)?.doubleValue ?? 0,
      frameAlignY: (map["frameAlignY"] as? NSNumber)?.doubleValue ?? 0,
      previewAspect: (map["previewAspect"] as? NSNumber)?.doubleValue ?? 0,
      fitContain: map["fitContain"] as? Bool ?? false,
      fullScreenPreview: map["fullScreenPreview"] as? Bool ?? false,
      fullScreen: map["fullScreen"] as? Bool ?? false,
      nativeSensor: map["nativeSensor"] as? Bool ?? false,
      directOutput: map["directOutput"] as? Bool ?? false,
      mirrorFront: map["mirrorFront"] as? Bool ?? false
    )
  }
}

enum PhotoCropHelper {
  private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

  /// 3:4 直出：校正 EXIF 方向，按需前置镜像，保持色彩正确
  static func normalizeDirectOutput(url: URL, mirrorFront: Bool, quality: CGFloat = 0.92) -> Bool {
    guard var ciImage = CIImage(contentsOf: url) else { return false }

    let orientation = readExifOrientation(url: url)
    if orientation != 1 {
      ciImage = ciImage.oriented(forExifOrientation: Int32(orientation))
    }

    if mirrorFront {
      let extent = ciImage.extent
      ciImage = ciImage.transformed(
        by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0)
      )
    }

    let outputRect = ciImage.extent.integral
    guard outputRect.width > 0, outputRect.height > 0,
          let cgImage = ciContext.createCGImage(ciImage, from: outputRect) else {
      return false
    }
    return writeJPEG(cgImage: cgImage, to: url, quality: quality)
  }

  static func makeThumbnailJPEG(url: URL, maxPixelSize: Int = 160) -> Data? {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      return nil
    }
    let mutable = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(mutable, kUTTypeJPEG, 1, nil) else {
      return nil
    }
    CGImageDestinationAddImage(
      dest,
      cgImage,
      [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary
    )
    guard CGImageDestinationFinalize(dest) else { return nil }
    return mutable as Data
  }

  private static func readExifOrientation(url: URL) -> Int {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
      return 1
    }
    let value = properties[kCGImagePropertyOrientation] as? NSNumber
    return value?.intValue ?? 1
  }

  private static func writeJPEG(cgImage: CGImage, to url: URL, quality: CGFloat) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) else {
      return false
    }
    CGImageDestinationAddImage(
      dest,
      cgImage,
      [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
    )
    return CGImageDestinationFinalize(dest)
  }
}
