import SwiftUI
import AppKit

/// Reine Menüleisten-App (`LSUIElement`, siehe `project.yml`): kein Dock-
/// Symbol, keine App-Menüleiste. Sichtbar ist nur das Symbol in der
/// Menüleiste; Tankstellenauswahl und Einstellungen sind eigene Fenster, die
/// aus dem Popover heraus geöffnet werden.
@main
struct SprittyApp: App {
    @State private var pinnedViewModel = PinnedFuelPricesViewModel()
    @State private var searchViewModel = StationSearchViewModel()

    var body: some Scene {
        MenuBarExtra {
            PinnedFuelPricesMenuView()
                .environment(pinnedViewModel)
                .environment(searchViewModel)
        } label: {
            PinnedFuelPricesMenuBarLabel()
                .environment(pinnedViewModel)
        }
        .menuBarExtraStyle(.window)

        // `.suppressed`: Fenster-Szenen öffnen sich sonst beim Start von
        // selbst – hier sollen sie nur auf Wunsch erscheinen.
        Window("Tankstelle wählen", id: WindowID.stationSelection) {
            StationSelectionWindow()
                .environment(searchViewModel)
                .environment(pinnedViewModel)
        }
        .defaultSize(width: 480, height: 560)
        .defaultLaunchBehavior(.suppressed)

        Window("Einstellungen", id: WindowID.settings) {
            SettingsView()
                .environment(searchViewModel)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

enum WindowID {
    static let stationSelection = "station-selection"
    static let settings = "settings"
}

extension OpenWindowAction {
    /// Öffnet ein Fenster und holt die App nach vorn. Ohne Dock-Symbol
    /// (`LSUIElement`) bleibt ein Fenster sonst hinter der aktiven App.
    @MainActor
    func showWindow(id: String) {
        callAsFunction(id: id)
        NSApp.activate()
    }
}
