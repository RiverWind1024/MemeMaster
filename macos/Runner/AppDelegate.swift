import Cocoa
import FlutterMacOS
import Vision

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.mememaster/vision_ocr",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "recognizeText":
        self?.handleRecognizeText(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleRecognizeText(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: String],
          let path = args["imagePath"] else {
      result(FlutterError(code: "INVALID_ARGS", message: "imagePath required", details: nil))
      return
    }

    guard let image = NSImage(contentsOfFile: path),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      result(FlutterError(code: "INVALID_IMAGE", message: "Cannot load image: \(path)", details: nil))
      return
    }

    let request = VNRecognizeTextRequest { (request, error) in
      if let error = error {
        result(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
        return
      }

      guard let observations = request.results as? [VNRecognizedTextObservation] else {
        result(["text": "", "blocks": []] as [String: Any])
        return
      }

      let blocks: [[String: Any]] = observations.compactMap { obs in
        guard let candidate = obs.topCandidates(1).first else { return nil }
        let bbox = obs.boundingBox
        return [
          "text": candidate.string,
          "confidence": Double(candidate.confidence),
          "x": Double(bbox.origin.x),
          "y": Double(bbox.origin.y),
          "width": Double(bbox.width),
          "height": Double(bbox.height),
        ]
      }

      let text = blocks.map { $0["text"] as! String }.joined(separator: "\n")
      result(["text": text, "blocks": blocks] as [String: Any])
    }

    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        try handler.perform([request])
      } catch {
        result(FlutterError(code: "VISION_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }
}
