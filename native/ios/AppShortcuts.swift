import AppIntents
import Flutter
import Foundation

@MainActor
final class InfinitiShortcutMailbox {
    static let shared = InfinitiShortcutMailbox()
    private var pending: (String, Date)?
    var channel: FlutterMethodChannel?
    private init() {}

    func put(_ route: String) {
        pending = (route, Date())
        channel?.invokeMethod("routeAvailable", arguments: nil)
    }

    func take() -> String? {
        defer { pending = nil }
        guard let (route, time) = pending else { return nil }
        let age = Date().timeIntervalSince(time)
        guard age >= 0, age <= 20 else { return nil }
        return route
    }
}

@available(iOS 16.0, *)
struct InfinitiOpenMap: AppIntent {
    static var title: LocalizedStringResource = "Open CarOS Map"
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        InfinitiShortcutMailbox.shared.put("map")
        return .result()
    }
}

@available(iOS 16.0, *)
struct InfinitiOpenAudio: AppIntent {
    static var title: LocalizedStringResource = "Open CarOS Audio"
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        InfinitiShortcutMailbox.shared.put("audio")
        return .result()
    }
}

@available(iOS 16.0, *)
struct InfinitiOpenAssistant: AppIntent {
    static var title: LocalizedStringResource = "Open CarOS Assistant"
    static var openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        InfinitiShortcutMailbox.shared.put("assistant")
        return .result()
    }
}

@available(iOS 16.0, *)
struct InfinitiAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: InfinitiOpenMap(), phrases: ["Open map in \(.applicationName)"],
                    shortTitle: "Map", systemImageName: "map")
        AppShortcut(intent: InfinitiOpenAudio(), phrases: ["Open audio in \(.applicationName)"],
                    shortTitle: "Audio", systemImageName: "music.note")
        AppShortcut(intent: InfinitiOpenAssistant(), phrases: ["Open assistant in \(.applicationName)"],
                    shortTitle: "Assistant", systemImageName: "mic")
    }
}

private func registerInfinitiShortcuts(_ registry: FlutterPluginRegistry) {
    guard #available(iOS 16.0, *) else { return }
    guard let registrar = registry.registrar(forPlugin: "InfinitiShortcuts") else { return }
    let channel = FlutterMethodChannel(name: "infiniti/shortcuts", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
        guard call.method == "takeRoute" else {
            result(FlutterMethodNotImplemented)
            return
        }
        Task { @MainActor in
            result(InfinitiShortcutMailbox.shared.take())
        }
    }
    Task { @MainActor in
        InfinitiShortcutMailbox.shared.channel = channel
        InfinitiAppShortcuts.updateAppShortcutParameters()
    }
}
