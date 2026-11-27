import UIKit
import Flutter

private let sharedCarEngine = FlutterEngine(name: "InfinitiSharedCarEngine", project: nil, allowHeadlessExecution: true)

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(_ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        sharedCarEngine.run()
        GeneratedPluginRegistrant.register(with: sharedCarEngine)
        registerInfinitiGlass(sharedCarEngine)
        registerInfinitiFace(sharedCarEngine)
        let profile = FlutterMethodChannel(name: "infiniti/car_profile", binaryMessenger: sharedCarEngine.binaryMessenger)
        profile.setMethodCallHandler { call, result in
            guard call.method == "category" else { result(FlutterMethodNotImplemented); return }
            result(Bundle.main.object(forInfoDictionaryKey: "InfinitiCarCategory") as? String)
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

@available(iOS 13.0, *)
class InfinitiPhoneScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let phone = UIWindow(windowScene: windowScene)
        let controller = FlutterViewController(engine: sharedCarEngine, nibName: nil, bundle: nil)
        controller.loadDefaultSplashScreenView()
        phone.rootViewController = controller
        window = phone
        phone.makeKeyAndVisible()
    }
}
