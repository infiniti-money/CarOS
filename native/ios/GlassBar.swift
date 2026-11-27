import SwiftUI

private struct InfinitiGlassBar: View {
    let dark: Bool
    let action: (String) -> Void
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 6) {
                    item("map", "Bản đồ", "map")
                    item("music", "Âm nhạc", "music.note")
                    item("theme", "Sáng tối", dark ? "sun.max" : "moon")
                    item("voice", "Trợ lý", "mic")
                    item("settings", "Cài đặt", "gearshape")
                }
            }
            .preferredColorScheme(dark ? .dark : .light)
            .padding(4)
        } else {
            EmptyView()
        }
    }

    @available(iOS 26.0, *)
    private func item(_ id: String, _ label: String, _ icon: String) -> some View {
        Button { action(id) } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 19, weight: .semibold))
                Text(label).font(.caption2).lineLimit(1).minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(label)
    }
}

private final class InfinitiGlassView: NSObject, FlutterPlatformView {
    private let host: UIHostingController<InfinitiGlassBar>
    init(frame: CGRect, id: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "infiniti/glass/actions/\(id)", binaryMessenger: messenger)
        let dark = (args as? [String: Any])?["dark"] as? Bool ?? true
        host = UIHostingController(rootView: InfinitiGlassBar(dark: dark) { value in
            channel.invokeMethod("action", arguments: value)
        })
        super.init()
        host.view.frame = frame
        host.view.backgroundColor = .clear
    }
    func view() -> UIView { host.view }
}

private final class InfinitiGlassFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        InfinitiGlassView(frame: frame, id: viewId, args: args, messenger: messenger)
    }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

private func registerInfinitiGlass(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "InfinitiGlass") else { return }
    let messenger = registrar.messenger()
    registrar.register(InfinitiGlassFactory(messenger: messenger), withId: "infiniti/glassbar")
    let probe = FlutterMethodChannel(name: "infiniti/glass", binaryMessenger: messenger)
    probe.setMethodCallHandler { call, result in
        guard call.method == "available" else { result(FlutterMethodNotImplemented); return }
        if #available(iOS 26.0, *) { result(true) } else { result(false) }
    }
}
