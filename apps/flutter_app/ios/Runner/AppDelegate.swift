import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "bolo/native_share", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "shareText" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Missing arguments", details: nil))
          return
        }

        let text = args["text"] as? String ?? ""
        let subject = args["subject"] as? String

        DispatchQueue.main.async {
          let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
          if let subject = subject, !subject.isEmpty {
            activityVC.setValue(subject, forKey: "subject")
          }

          if let popover = activityVC.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(
              x: controller.view.bounds.midX,
              y: controller.view.bounds.midY,
              width: 1,
              height: 1
            )
            popover.permittedArrowDirections = []
          }

          controller.present(activityVC, animated: true) {
            result(true)
          }
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
