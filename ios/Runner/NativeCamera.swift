import AVFoundation
import AudioToolbox
import Flutter
import UIKit

final class NativeCameraController: NSObject {
  static let shared = NativeCameraController()

  private let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "native.camera.session")
  private let photoOutput = AVCapturePhotoOutput()

  private var videoInput: AVCaptureDeviceInput?
  private var previewView: NativeCameraPreviewView?
  private var currentPosition: AVCaptureDevice.Position = .back

  private var flashMode: AVCaptureDevice.FlashMode = .off
  private var torchEnabled = false
  private var currentZoom: CGFloat = 1.0

  private(set) var baselineOneX: Double = 1.0
  private(set) var minZoom: Double = 1.0
  private(set) var maxZoom: Double = 1.0
  private(set) var previewAspectRatio: Double = 3.0 / 4.0
  private var previewFitContain = true

  private var captureCompletion: ((Result<[String: Any], Error>) -> Void)?

  func attachPreview(_ view: NativeCameraPreviewView) {
    previewView = view
    view.videoPreviewLayer.session = session
    applyPreviewVideoGravity(to: view)
  }

  func setPreviewFitContain(_ contain: Bool) {
    previewFitContain = contain
    DispatchQueue.main.async {
      if let view = self.previewView {
        self.applyPreviewVideoGravity(to: view)
      }
    }
  }

  func playShutterSound() {
    AudioServicesPlaySystemSound(1108)
  }

  private func applyPreviewVideoGravity(to view: NativeCameraPreviewView) {
    view.videoPreviewLayer.videoGravity =
      previewFitContain ? .resizeAspect : .resizeAspectFill
  }

  func initialize(completion: @escaping (Result<[String: Any], Error>) -> Void) {
    sessionQueue.async {
      do {
        try self.configureSession()
        self.session.startRunning()
        DispatchQueue.main.async {
          completion(.success(self.stateMap()))
        }
      } catch {
        DispatchQueue.main.async {
          completion(.failure(error))
        }
      }
    }
  }

  func dispose() {
    sessionQueue.async {
      self.session.stopRunning()
      self.session.beginConfiguration()
      for input in self.session.inputs {
        self.session.removeInput(input)
      }
      for output in self.session.outputs {
        self.session.removeOutput(output)
      }
      self.session.commitConfiguration()
    }
  }

  func pause() {
    sessionQueue.async {
      if self.session.isRunning {
        self.session.stopRunning()
      }
    }
  }

  func resume(completion: @escaping (Result<[String: Any], Error>) -> Void) {
    sessionQueue.async {
      if !self.session.isRunning {
        self.session.startRunning()
      }
      DispatchQueue.main.async {
        completion(.success(self.stateMap()))
      }
    }
  }

  func switchCamera(completion: @escaping (Result<[String: Any], Error>) -> Void) {
    sessionQueue.async {
      do {
        self.currentPosition = self.currentPosition == .back ? .front : .back
        try self.configureSession()
        if !self.session.isRunning {
          self.session.startRunning()
        }
        DispatchQueue.main.async {
          completion(.success(self.stateMap()))
        }
      } catch {
        DispatchQueue.main.async {
          completion(.failure(error))
        }
      }
    }
  }

  func setZoom(_ zoom: Double) {
    sessionQueue.async {
      guard let device = self.videoInput?.device else { return }
      let clamped = max(self.minZoom, min(self.maxZoom, zoom))
      do {
        try device.lockForConfiguration()
        device.videoZoomFactor = CGFloat(clamped)
        device.unlockForConfiguration()
        self.currentZoom = CGFloat(clamped)
      } catch {}
    }
  }

  func setFlash(mode: String) {
    switch mode {
    case "on":
      flashMode = .off
      torchEnabled = true
    case "auto":
      flashMode = .auto
      torchEnabled = false
    default:
      flashMode = .off
      torchEnabled = false
    }
    sessionQueue.async {
      guard let device = self.videoInput?.device, device.hasTorch else { return }
      do {
        try device.lockForConfiguration()
        device.torchMode = self.torchEnabled ? .on : .off
        device.unlockForConfiguration()
      } catch {}
    }
  }

  func snapshotPreview(completion: @escaping (String?) -> Void) {
    DispatchQueue.main.async {
      guard let view = self.previewView, view.bounds.width > 0 else {
        completion(nil)
        return
      }
      let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
      let image = renderer.image { _ in
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
      }
      let fileName = "preview_snap_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
      guard let data = image.jpegData(compressionQuality: 0.82) else {
        completion(nil)
        return
      }
      do {
        try data.write(to: url)
        completion(url.path)
      } catch {
        completion(nil)
      }
    }
  }

  func takePicture(completion: @escaping (Result<[String: Any], Error>) -> Void) {
    sessionQueue.async {
      let settings = AVCapturePhotoSettings()
      if self.videoInput?.device.hasFlash == true && !self.torchEnabled {
        settings.flashMode = self.flashMode
      }
      self.captureCompletion = completion
      self.photoOutput.capturePhoto(with: settings, delegate: self)
    }
  }

  private func configureSession() throws {
    session.beginConfiguration()
    session.sessionPreset = .photo

    for input in session.inputs {
      session.removeInput(input)
    }
    for output in session.outputs {
      session.removeOutput(output)
    }

    guard let device = bestDevice(for: currentPosition) else {
      session.commitConfiguration()
      throw NSError(domain: "NativeCamera", code: -1, userInfo: [NSLocalizedDescriptionKey: "No camera"])
    }

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      session.commitConfiguration()
      throw NSError(domain: "NativeCamera", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot add input"])
    }
    session.addInput(input)
    videoInput = input

    if session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)
      photoOutput.isHighResolutionCaptureEnabled = false
    }

    minZoom = Double(device.minAvailableVideoZoomFactor)
    maxZoom = Double(device.maxAvailableVideoZoomFactor)
    baselineOneX = minZoom < 1.0 ? minZoom : 1.0
    currentZoom = CGFloat(baselineOneX)

    try device.lockForConfiguration()
    device.videoZoomFactor = currentZoom
    device.unlockForConfiguration()

    let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    if dims.height > 0 {
      let w = Double(min(dims.width, dims.height))
      let h = Double(max(dims.width, dims.height))
      previewAspectRatio = w / h
    }

    session.commitConfiguration()
  }

  private func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    if position == .back {
      if let triple = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
        return triple
      }
      if let dual = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
        return dual
      }
    }
    return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
  }

  private func stateMap() -> [String: Any] {
    [
      "baselineOneX": baselineOneX,
      "minZoom": minZoom,
      "maxZoom": maxZoom,
      "previewAspectRatio": previewAspectRatio,
      "isBackCamera": currentPosition == .back,
    ]
  }

  private func writeThumbnail(from data: Data, to url: URL) throws {
    guard let image = UIImage(data: data) else { return }
    let size = CGSize(width: 160, height: 160)
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
    image.draw(in: CGRect(origin: .zero, size: size))
    let thumb = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    if let jpeg = thumb?.jpegData(compressionQuality: 0.75) {
      try jpeg.write(to: url)
    }
  }
}

extension NativeCameraController: AVCapturePhotoCaptureDelegate {
  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    let completion = captureCompletion
    captureCompletion = nil

    if let error = error {
      DispatchQueue.main.async {
        completion?(.failure(error))
      }
      return
    }

    guard let data = photo.fileDataRepresentation() else {
      DispatchQueue.main.async {
        completion?(.failure(NSError(domain: "NativeCamera", code: -3, userInfo: nil)))
      }
      return
    }

    let fileName = "capture_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
    let photoURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    let thumbURL = FileManager.default.temporaryDirectory.appendingPathComponent("thumb_\(fileName)")

    do {
      try data.write(to: photoURL)
      try writeThumbnail(from: data, to: thumbURL)
      DispatchQueue.main.async {
        completion?(.success([
          "path": photoURL.path,
          "thumbnailPath": thumbURL.path,
        ]))
      }
    } catch {
      DispatchQueue.main.async {
        completion?(.failure(error))
      }
    }
  }
}

final class NativeCameraPreviewView: UIView {
  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  var videoPreviewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }
}

final class NativeCameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeCameraPlatformView(frame: frame)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class NativeCameraPlatformView: NSObject, FlutterPlatformView {
  private let previewView = NativeCameraPreviewView()

  init(frame: CGRect) {
    super.init()
    previewView.frame = frame
    NativeCameraController.shared.attachPreview(previewView)
  }

  func view() -> UIView {
    previewView
  }
}

final class NativeCameraPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.example.pet_ai_camera/native_camera",
      binaryMessenger: registrar.messenger()
    )
    let instance = NativeCameraPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.register(
      NativeCameraPreviewFactory(),
      withId: "native-camera-preview"
    )
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let controller = NativeCameraController.shared
    switch call.method {
    case "initialize":
      controller.initialize { r in
        switch r {
        case .success(let map): result(map)
        case .failure(let error): result(FlutterError(code: "INIT_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    case "dispose":
      controller.dispose()
      result(nil)
    case "pause":
      controller.pause()
      result(nil)
    case "resume":
      controller.resume { r in
        switch r {
        case .success(let map): result(map)
        case .failure(let error): result(FlutterError(code: "RESUME_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    case "switchCamera":
      controller.switchCamera { r in
        switch r {
        case .success(let map): result(map)
        case .failure(let error): result(FlutterError(code: "SWITCH_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    case "setZoom":
      guard let args = call.arguments as? [String: Any],
            let zoom = args["zoom"] as? Double else {
        result(FlutterError(code: "ARG", message: "zoom required", details: nil))
        return
      }
      controller.setZoom(zoom)
      result(nil)
    case "setFlash":
      let args = call.arguments as? [String: Any]
      let mode = args?["mode"] as? String ?? "off"
      controller.setFlash(mode: mode)
      result(nil)
    case "snapshotPreview":
      controller.snapshotPreview { path in
        result(path)
      }
    case "setPreviewFitContain":
      let args = call.arguments as? [String: Any]
      let contain = args?["contain"] as? Bool ?? false
      controller.setPreviewFitContain(contain)
      result(nil)
    case "setPreviewMode":
      let args = call.arguments as? [String: Any]
      let contain = args?["contain"] as? Bool ?? false
      controller.setPreviewFitContain(contain)
      result(controller.stateMap())
    case "playShutterSound":
      controller.playShutterSound()
      result(nil)
    case "takePicture":
      controller.takePicture { r in
        switch r {
        case .success(let map): result(map)
        case .failure(let error): result(FlutterError(code: "CAPTURE_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
