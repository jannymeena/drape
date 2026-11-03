import Flutter
import MediaPipeTasksVision
import UIKit

/// Finds the body in a photo on the device with MediaPipe's Pose Landmarker
/// (the bundled `pose_landmarker_full.task`). The photo never leaves the phone.
///
/// `detect` takes the image as raw RGBA (`rgba`, `width`, `height`), decoded
/// and scaled by Flutter so orientation and coordinates match what the app
/// shows. It answers `{poses: [{landmarks, mask, maskWidth, maskHeight}]}`:
/// 33 landmarks as x, y, visibility, presence (x and y as fractions of the
/// image), and the body mask as one byte per pixel (255 = body).
///
/// Mirrors `android/.../PoseDetectorChannel.kt`.
final class PoseDetectorChannel {
  static let name = "style.zoura.mobile/pose"
  static let model = "assets/models/pose_landmarker_full.task"

  private let modelPath: String?
  private let queue = DispatchQueue(label: "style.zoura.mobile.pose", qos: .userInitiated)

  /// Loaded on first use, then kept: loading the model takes a moment.
  private var landmarker: PoseLandmarker?

  private init(modelPath: String?) {
    self.modelPath = modelPath
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let key = registrar.lookupKey(forAsset: model)
    let detector = PoseDetectorChannel(modelPath: Bundle.main.path(forResource: key, ofType: nil))
    let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
    // The handler holds the detector for the engine's lifetime.
    channel.setMethodCallHandler { call, result in detector.handle(call, result: result) }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "detect" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
      let rgba = args["rgba"] as? FlutterStandardTypedData,
      let width = args["width"] as? Int,
      let height = args["height"] as? Int
    else {
      result(FlutterError(code: "bad_args", message: "rgba, width and height are required", details: nil))
      return
    }
    queue.async {
      do {
        let poses = try self.detect(rgba.data, width: width, height: height)
        DispatchQueue.main.async { result(poses) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "pose_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func makeLandmarker() throws -> PoseLandmarker {
    if let landmarker { return landmarker }
    guard let modelPath else { throw PoseDetectorError.modelMissing }
    let options = PoseLandmarkerOptions()
    options.baseOptions.modelAssetPath = modelPath
    options.runningMode = .image
    // Two, so a second person in the shot can be reported.
    options.numPoses = 2
    options.shouldOutputSegmentationMasks = true
    let made = try PoseLandmarker(options: options)
    landmarker = made
    return made
  }

  private func detect(_ rgba: Data, width: Int, height: Int) throws -> [String: Any] {
    guard let provider = CGDataProvider(data: rgba as CFData),
      let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else { throw PoseDetectorError.badImage }

    let found = try makeLandmarker().detect(image: try MPImage(uiImage: UIImage(cgImage: cgImage)))
    let masks = found.segmentationMasks
    var poses: [[String: Any]] = []
    for (i, points) in found.landmarks.enumerated() {
      var landmarks: [Double] = []
      landmarks.reserveCapacity(points.count * 4)
      for p in points {
        landmarks += [
          Double(p.x), Double(p.y),
          p.visibility?.doubleValue ?? 0, p.presence?.doubleValue ?? 0,
        ]
      }
      var pose: [String: Any] = [
        "landmarks": FlutterStandardTypedData(
          float64: landmarks.withUnsafeBufferPointer { Data(buffer: $0) })
      ]
      if i < masks.count {
        let mask = masks[i]
        let count = mask.width * mask.height
        let floats = mask.float32Data
        var bytes = Data(count: count)
        bytes.withUnsafeMutableBytes { (out: UnsafeMutableRawBufferPointer) in
          for k in 0..<count {
            out[k] = UInt8(max(0, min(1, floats[k])) * 255)
          }
        }
        pose["mask"] = FlutterStandardTypedData(bytes: bytes)
        pose["maskWidth"] = mask.width
        pose["maskHeight"] = mask.height
      }
      poses.append(pose)
    }
    return ["poses": poses]
  }
}

enum PoseDetectorError: Error {
  case modelMissing
  case badImage
}
