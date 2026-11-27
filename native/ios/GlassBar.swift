import SwiftUI

private struct InfinitiGlassBar: View {
    let dark: Bool
    let action: (String) -> Void
    let items: [String]
    let columns: Int
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                if items.isEmpty {
                HStack(spacing: 6) {
                    item("map", "Bản đồ", "map")
                    item("music", "Âm nhạc", "music.note")
                    item("theme", "Sáng tối", dark ? "sun.max" : "moon")
                    item("voice", "Trợ lý", "mic")
                    item("settings", "Cài đặt", "gearshape")
                }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: max(2, min(columns, 6))), spacing: 8) {
                        ForEach(items, id: \.self) { label in
                            launcher(label)
                        }
                    }
                }
            }
            .preferredColorScheme(dark ? .dark : .light)
            .padding(4)
        } else {
            EmptyView()
        }
    }

    @available(iOS 26.0, *)
    private func launcher(_ label: String) -> some View {
        let symbols = ["Bản đồ": "map", "Bản đồ Apple": "location", "Giải trí": "music.note", "Spotify": "headphones", "Podcast": "mic.fill", "Trợ lý": "mic", "Điện thoại": "phone", "Lịch": "calendar", "Cài đặt": "gearshape", "Camera hành trình": "video"]
        return Button { action(label) } label: {
            VStack(spacing: 8) {
                Image(systemName: symbols[label] ?? "square.grid.2x2")
                    .font(.system(size: 27, weight: .medium))
                    .frame(width: 62, height: 62)
                    .glassEffect(.regular.interactive(), in: Circle())
                Text(label).font(.caption).lineLimit(2).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
        let items = (args as? [String: Any])?["items"] as? [String] ?? []
        let columns = (args as? [String: Any])?["columns"] as? Int ?? 3
        host = UIHostingController(rootView: InfinitiGlassBar(dark: dark, action: { value in
            channel.invokeMethod("action", arguments: value)
        }, items: items, columns: columns))
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
