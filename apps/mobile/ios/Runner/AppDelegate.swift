import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PerlesStorage")!
    FlutterMethodChannel(name: "perles_divines/storage", binaryMessenger: registrar.messenger()).setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "freeBytes":
          let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
          result(attributes[.systemFreeSize] as? NSNumber)
        case "excludeBackup":
          guard let args = call.arguments as? [String: String], let path = args["path"], path.hasPrefix(NSHomeDirectory() + "/") else {
            result(FlutterError(code: "PATH_REFUSED", message: "Chemin refusé", details: nil)); return
          }
          var url = URL(fileURLWithPath: path)
          var values = URLResourceValues(); values.isExcludedFromBackup = true
          try url.setResourceValues(values); result(true)
        default: result(FlutterMethodNotImplemented)
        }
      } catch { result(FlutterError(code: "STORAGE", message: "Stockage indisponible", details: nil)) }
    }
  }
}
