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
    guard var ciImage = loadOrientedImage(url: url) else { return false }
    if mirrorFront {
      ciImage = mirrorHorizontally(ciImage)
    }
    return writeCIImage(ciImage, to: url, quality: quality)
  }

  /// 非 3:4 裁切（与 Android PhotoCropHelper.cropFileInPlace 一致，避免 Dart image 包色彩异常）
  static func cropFileInPlace(url: URL, params: CropParams, quality: CGFloat = 0.82) -> Bool {
    if params.directOutput || params.nativeSensor { return true }
    guard var ciImage = loadOrientedImage(url: url) else { return false }

    let extent = ciImage.extent.integral
    let orientedW = Int(extent.width.rounded())
    let orientedH = Int(extent.height.rounded())
    guard orientedW > 0, orientedH > 0 else { return false }

    let pixelRect: PixelRect
    if params.fullScreenPreview {
      let screenRatio: Double
      if params.screenHeight > 0 {
        screenRatio = params.screenWidth / params.screenHeight
      } else if params.previewAspect > 0 {
        screenRatio = params.previewAspect
      } else {
        screenRatio = params.ratio
      }
      let orientedAspect = Double(orientedW) / Double(orientedH)
      if abs(orientedAspect - screenRatio) < 0.03 {
        if params.mirrorFront {
          ciImage = mirrorHorizontally(ciImage)
        }
        return writeCIImage(ciImage, to: url, quality: quality)
      }
      pixelRect = computeCropRect(
        imageW: orientedW,
        imageH: orientedH,
        params: params,
        ratioOverride: screenRatio
      )
    } else {
      pixelRect = computeCropRect(
        imageW: orientedW,
        imageH: orientedH,
        params: params,
        ratioOverride: nil
      )
    }

    let cropCI = ciCropRect(from: pixelRect, in: extent)
    ciImage = ciImage.cropped(to: cropCI)
    if params.mirrorFront {
      ciImage = mirrorHorizontally(ciImage)
    }
    return writeCIImage(ciImage, to: url, quality: quality)
  }

  private static func loadOrientedImage(url: URL) -> CIImage? {
    guard var ciImage = CIImage(contentsOf: url) else { return nil }
    let orientation = readExifOrientation(url: url)
    if orientation != 1 {
      ciImage = ciImage.oriented(forExifOrientation: Int32(orientation))
    }
    return ciImage
  }

  private static func mirrorHorizontally(_ image: CIImage) -> CIImage {
    let extent = image.extent
    return image.transformed(
      by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0)
    )
  }

  private static func writeCIImage(_ image: CIImage, to url: URL, quality: CGFloat) -> Bool {
    let outputRect = image.extent.integral
    guard outputRect.width > 0, outputRect.height > 0,
          let cgImage = ciContext.createCGImage(image, from: outputRect) else {
      return false
    }
    return writeJPEG(cgImage: cgImage, to: url, quality: quality)
  }

  private struct PixelRect {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
  }

  private struct FrameBox {
    let boxLeft: Double
    let boxTop: Double
    let boxWidth: Double
    let boxHeight: Double
  }

  private struct Layout {
    let offsetX: Double
    let offsetY: Double
    let scaledW: Double
    let scaledH: Double
  }

  private static func computeCropRect(
    imageW: Int,
    imageH: Int,
    params: CropParams,
    ratioOverride: Double?
  ) -> PixelRect {
    let ratio = ratioOverride ?? params.ratio
    let frame = computeFrame(params: params, ratio: ratio)
    let layout = computePreviewLayout(
      screenW: params.screenWidth,
      screenH: params.screenHeight,
      previewAspect: params.previewAspect,
      fitContain: params.fitContain,
      fullScreenPreview: params.fullScreenPreview,
      verticalAlignY: params.frameAlignY
    )
    let captureAspect = Double(imageW) / Double(imageH)

    func screenToNormX(_ x: Double) -> Double {
      min(1, max(0, (x - layout.offsetX) / layout.scaledW))
    }
    func screenToNormY(_ y: Double) -> Double {
      min(1, max(0, (y - layout.offsetY) / layout.scaledH))
    }

    let px0 = screenToNormX(frame.boxLeft)
    let py0 = screenToNormY(frame.boxTop)
    let px1 = screenToNormX(frame.boxLeft + frame.boxWidth)
    let py1 = screenToNormY(frame.boxTop + frame.boxHeight)

    var nx0 = previewToCaptureNorm(px0, previewAspect: params.previewAspect, captureAspect: captureAspect)
    var ny0 = previewToCaptureNorm(py0, previewAspect: params.previewAspect, captureAspect: captureAspect)
    var nx1 = previewToCaptureNorm(px1, previewAspect: params.previewAspect, captureAspect: captureAspect)
    var ny1 = previewToCaptureNorm(py1, previewAspect: params.previewAspect, captureAspect: captureAspect)

    if nx0 > nx1 { swap(&nx0, &nx1) }
    if ny0 > ny1 { swap(&ny0, &ny1) }

    nx0 = min(1, max(0, nx0))
    ny0 = min(1, max(0, ny0))
    nx1 = min(1, max(0, nx1))
    ny1 = min(1, max(0, ny1))

    if nx1 <= nx0 || ny1 <= ny0 {
      return centerCropRect(w: imageW, h: imageH, ratio: ratio)
    }

    var x = Int((nx0 * Double(imageW)).rounded())
    var y = Int((ny0 * Double(imageH)).rounded())
    var w = Int(((nx1 - nx0) * Double(imageW)).rounded())
    var h = Int(((ny1 - ny0) * Double(imageH)).rounded())
    if w <= 0 || h <= 0 {
      return centerCropRect(w: imageW, h: imageH, ratio: ratio)
    }
    if x + w > imageW { w = imageW - x }
    if y + h > imageH { h = imageH - y }
    x = min(imageW - 1, max(0, x))
    y = min(imageH - 1, max(0, y))

    let outAspect = Double(w) / Double(h)
    if abs(outAspect - ratio) > 0.02 {
      return centerCropRectOnRegion(x: x, y: y, w: w, h: h, ratio: ratio)
    }
    return PixelRect(x: x, y: y, width: max(1, w), height: max(1, h))
  }

  private static func computeFrame(params: CropParams, ratio: Double) -> FrameBox {
    if params.fullScreen || params.screenWidth <= 0 || params.screenHeight <= 0 {
      return FrameBox(
        boxLeft: 0,
        boxTop: 0,
        boxWidth: params.screenWidth,
        boxHeight: params.screenHeight
      )
    }
    let areaTop = params.topInset
    let areaH = min(
      params.screenHeight,
      max(0, params.screenHeight - params.topInset - params.bottomInset)
    )
    if areaH <= 0 {
      return FrameBox(
        boxLeft: 0,
        boxTop: 0,
        boxWidth: params.screenWidth,
        boxHeight: params.screenHeight
      )
    }
    let boxW: Double
    let boxH: Double
    if params.screenWidth / areaH > ratio {
      boxH = areaH
      boxW = areaH * ratio
    } else {
      boxW = params.screenWidth
      boxH = params.screenWidth / ratio
    }
    let alignY = min(1, max(0, params.frameAlignY))
    let boxTop = min(
      params.screenHeight - boxH,
      max(0, areaTop + (areaH - boxH) * alignY)
    )
    return FrameBox(
      boxLeft: (params.screenWidth - boxW) / 2,
      boxTop: boxTop,
      boxWidth: boxW,
      boxHeight: boxH
    )
  }

  private static func computePreviewLayout(
    screenW: Double,
    screenH: Double,
    previewAspect: Double,
    fitContain: Bool,
    fullScreenPreview: Bool,
    verticalAlignY: Double
  ) -> Layout {
    let childW: Double
    let childH: Double
    if screenW / screenH > previewAspect {
      childH = screenH
      childW = screenH * previewAspect
    } else {
      childW = screenW
      childH = screenW / previewAspect
    }
    let scaleW = screenW / childW
    let scaleH = screenH / childH
    let scale = fitContain ? min(scaleW, scaleH) : max(scaleW, scaleH)
    let scaledW = childW * scale
    let scaledH = childH * scale
    let alignY = fullScreenPreview ? 0.5 : min(1, max(0, verticalAlignY))
    return Layout(
      offsetX: (screenW - scaledW) / 2,
      offsetY: (screenH - scaledH) * alignY,
      scaledW: scaledW,
      scaledH: scaledH
    )
  }

  private static func previewToCaptureNorm(
    _ previewNorm: Double,
    previewAspect: Double,
    captureAspect: Double
  ) -> Double {
    if previewAspect <= 0 || captureAspect <= 0 { return previewNorm }
    return 0.5 + (previewNorm - 0.5) * (previewAspect / captureAspect)
  }

  private static func centerCropRect(w: Int, h: Int, ratio: Double) -> PixelRect {
    let cropW: Double
    let cropH: Double
    if Double(w) / Double(h) > ratio {
      cropH = Double(h)
      cropW = Double(h) * ratio
    } else {
      cropW = Double(w)
      cropH = Double(w) / ratio
    }
    return PixelRect(
      x: Int(((Double(w) - cropW) / 2).rounded()),
      y: Int(((Double(h) - cropH) / 2).rounded()),
      width: max(1, min(w, Int(cropW.rounded()))),
      height: max(1, min(h, Int(cropH.rounded())))
    )
  }

  private static func centerCropRectOnRegion(
    x: Int, y: Int, w: Int, h: Int, ratio: Double
  ) -> PixelRect {
    let cropW: Double
    let cropH: Double
    if Double(w) / Double(h) > ratio {
      cropH = Double(h)
      cropW = Double(h) * ratio
    } else {
      cropW = Double(w)
      cropH = Double(w) / ratio
    }
    return PixelRect(
      x: x + Int(((Double(w) - cropW) / 2).rounded()),
      y: y + Int(((Double(h) - cropH) / 2).rounded()),
      width: max(1, min(w, Int(cropW.rounded()))),
      height: max(1, min(h, Int(cropH.rounded())))
    )
  }

  /// 像素坐标（顶左原点）→ CoreImage 裁切区域
  private static func ciCropRect(from pixel: PixelRect, in extent: CGRect) -> CGRect {
    CGRect(
      x: extent.minX + CGFloat(pixel.x),
      y: extent.maxY - CGFloat(pixel.y + pixel.height),
      width: CGFloat(pixel.width),
      height: CGFloat(pixel.height)
    )
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

enum PhotoExifHelper {
  static func writeGps(to url: URL, latitude: Double, longitude: Double) -> Bool {
    guard latitude.isFinite, longitude.isFinite else { return false }
    guard !(latitude == 0 && longitude == 0) else { return false }
    guard FileManager.default.fileExists(atPath: url.path) else { return false }

    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let imageType = CGImageSourceGetType(source),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      return false
    }

    var properties =
      (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]

    let latRef = latitude >= 0 ? "N" : "S"
    let lngRef = longitude >= 0 ? "E" : "W"
    properties[kCGImagePropertyGPSDictionary as String] = [
      kCGImagePropertyGPSLatitude as String: abs(latitude),
      kCGImagePropertyGPSLatitudeRef as String: latRef,
      kCGImagePropertyGPSLongitude as String: abs(longitude),
      kCGImagePropertyGPSLongitudeRef as String: lngRef,
    ]

    let tempUrl = url.deletingPathExtension().appendingPathExtension("gps.tmp.jpg")
    defer { try? FileManager.default.removeItem(at: tempUrl) }

    guard let dest = CGImageDestinationCreateWithURL(tempUrl as CFURL, imageType, 1, nil) else {
      return false
    }
    CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return false }

    do {
      _ = try FileManager.default.replaceItemAt(url, withItemAt: tempUrl)
      return true
    } catch {
      return false
    }
  }

  static func writeDeviceInfo(to url: URL, make: String?, model: String?) -> Bool {
    let makeValue = make?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let modelValue = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if makeValue.isEmpty && modelValue.isEmpty { return false }
    guard FileManager.default.fileExists(atPath: url.path) else { return false }

    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let imageType = CGImageSourceGetType(source),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      return false
    }

    var properties =
      (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]

    var tiff =
      (properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
    if !makeValue.isEmpty {
      tiff[kCGImagePropertyTIFFMake as String] = makeValue
    }
    if !modelValue.isEmpty {
      tiff[kCGImagePropertyTIFFModel as String] = modelValue
    }
    properties[kCGImagePropertyTIFFDictionary as String] = tiff

    let tempUrl = url.deletingPathExtension().appendingPathExtension("device.tmp.jpg")
    defer { try? FileManager.default.removeItem(at: tempUrl) }

    guard let dest = CGImageDestinationCreateWithURL(tempUrl as CFURL, imageType, 1, nil) else {
      return false
    }
    CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return false }

    do {
      _ = try FileManager.default.replaceItemAt(url, withItemAt: tempUrl)
      return true
    } catch {
      return false
    }
  }
}
