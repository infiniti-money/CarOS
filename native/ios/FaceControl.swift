import Vision
import ImageIO
import CoreGraphics

private func registerInfinitiFace(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "InfinitiFace") else { return }
    let channel = FlutterMethodChannel(name: "infiniti/face", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
        guard call.method == "yaw" else { result(FlutterMethodNotImplemented); return }
        guard let args = call.arguments as? [String: Any],
              let typed = args["bytes"] as? FlutterStandardTypedData,
              let width = args["width"] as? Int, let height = args["height"] as? Int,
              let stride = args["stride"] as? Int, let raw = args["orientation"] as? Int,
              (1...1280).contains(width), (1...1280).contains(height),
              stride >= width * 4, stride <= 8192,
              typed.data.count >= stride * height, typed.data.count <= 12_000_000,
              (1...8).contains(raw),
              let orientation = CGImagePropertyOrientation(rawValue: UInt32(raw)),
              let provider = CGDataProvider(data: typed.data as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: stride, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { result(nil); return }
        do {
            let request = VNDetectFaceLandmarksRequest()
            try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
            guard let faces = request.results, faces.count == 1,
                  let yaw = faces[0].yaw?.doubleValue, yaw.isFinite
            else { result(nil); return }
            result(yaw)
        } catch {
            result(FlutterError(code: "vision", message: "Face analysis unavailable", details: nil))
        }
    }
}
