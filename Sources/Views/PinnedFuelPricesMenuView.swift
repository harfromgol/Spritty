import SwiftUI

/// Inhalt des Menüleisten-Popovers: angepinnte Tankstellen/Sorten mit
/// Preis, Update-Intervall und manuellem Aktualisieren-Button – dazu die
/// Wege zu Tankstellenauswahl, Einstellungen und Beenden.
struct PinnedFuelPricesMenuView: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 12) {
            if vm.pinnedSelections.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "fuelpump")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Keine Auswahl")
                        .font(.headline)
                    Text("Wähle über „Tankstelle wählen\u{201C} eine Tankstelle und Spritsorte aus.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.pinnedSelections) { selection in
                        PinnedFuelPriceRow(selection: selection)
                    }
                }

                if let lastErrorMessage = vm.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Divider()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = vm.secondsRemaining(asOf: context.date)
                    VStack(spacing: 4) {
                        HStack {
                            Picker("Aktualisierung", selection: $vm.refreshInterval) {
                                ForEach(FuelPriceRefreshInterval.allCases) { interval in
                                    Text(interval.displayName).tag(interval)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()

                            Spacer()

                            Button("Aktualisieren", systemImage: "arrow.clockwise") {
                                Task { await vm.refresh() }
                            }
                            .buttonStyle(.glass)
                            .disabled(remaining != nil || vm.isRefreshing)
                            .pointerStyle(remaining == nil && !vm.isRefreshing ? .link : nil)
                        }
                        if let remaining {
                            Text("Nächste Abfrage in \(DisplayFormatter.countdownString(remaining))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                Divider()

                TankerkoenigAttributionView()
            }

            Divider()

            HStack(spacing: 8) {
                Button("Tankstelle wählen", systemImage: "fuelpump") {
                    openWindow.showWindow(id: WindowID.stationSelection)
                }
                .buttonStyle(.glass)
                .pointerStyle(.link)

                Spacer()

                Button {
                    openWindow.showWindow(id: WindowID.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.glass)
                .pointerStyle(.link)
                .help("Einstellungen")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.glass)
                .pointerStyle(.link)
                .help("Spritty beenden")
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
