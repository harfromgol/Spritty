import AppKit
import Observation

/// Hell/Dunkel/System.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }
}

/// Speichert das gewählte Erscheinungsbild in den UserDefaults.
enum AppearanceModeStore {
    private static let defaultsKey = "appearanceMode"

    static func get() -> AppearanceMode {
        let raw = UserDefaults.standard.string(forKey: defaultsKey)
        return raw.flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    static func set(_ mode: AppearanceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
    }
}

/// Steuert das Erscheinungsbild der gesamten App über `NSApp.appearance`
/// statt über `.preferredColorScheme` an jeder Szene: Popover und Fenster
/// erben die App-weite Vorgabe automatisch.
@MainActor
@Observable
final class AppearanceSettings {
    var mode: AppearanceMode {
        didSet {
            guard mode != oldValue else { return }
            AppearanceModeStore.set(mode)
            apply()
        }
    }

    init() {
        mode = AppearanceModeStore.get()
        // `NSApp` existiert noch nicht, wenn SwiftUI die `@State`-Startwerte
        // der App erzeugt – die erste Anwendung folgt deshalb erst nach dem
        // Start.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.apply()
            }
        }
    }

    private func apply() {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
