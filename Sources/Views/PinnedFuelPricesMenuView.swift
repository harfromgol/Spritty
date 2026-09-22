import SwiftUI

/// Inhalt des Menüleisten-Popovers: angepinnte Tankstellen/Sorten mit
/// Preis, Update-Intervall und manuellem Aktualisieren-Button – dazu die
/// Wege zu Tankstellenauswahl, Einstellungen und Beenden.
struct PinnedFuelPricesMenuView: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm
    @Environment(StationSearchViewModel.self) private var searchVM
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
                    // Lief gerade KEIN eigener Preisabfrage-Countdown, aber
                    // eine Umkreissuche über „Tankstelle wählen" hat
                    // stattgefunden, sperrt deren 5-Minuten-Anzeige-Sperre
                    // (`searchVM.secondsRemaining`) zusätzlich Dropdown und
                    // Button – ohne eigene Countdown-Anzeige. Läuft bereits
                    // ein Preisabfrage-Countdown, bleibt es bei dessen
                    // gewohntem Verhalten.
                    let searchLock = remaining == nil ? searchVM.secondsRemaining(asOf: context.date) : nil
                    let disabled = remaining != nil || searchLock != nil
                    VStack(spacing: 4) {
                        HStack {
                            Picker("Aktualisierung", selection: $vm.refreshInterval) {
                                ForEach(FuelPriceRefreshInterval.allCases) { interval in
                                    Text(interval.displayName).tag(interval)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                            .disabled(disabled)

                            Spacer()

                            Button("Aktualisieren", systemImage: "arrow.clockwise") {
                                Task { await vm.refresh() }
                            }
                            .buttonStyle(.glass)
                            .disabled(disabled || vm.isRefreshing)
                            .pointerStyle(!disabled && !vm.isRefreshing ? .link : nil)
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
                // Nach JEDER Abfrage an Tankerkönig – Umkreissuche hier wie
                // Preisabfrage im Aktualisieren-Button oben – ist der Button
                // für 5 Minuten gesperrt; statt des Textes läuft der
                // Countdown der jeweils später abgelaufenen Sperre.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let searchRemaining = searchVM.secondsRemaining(asOf: context.date)
                    let queryRemaining = vm.recentRequestSecondsRemaining(asOf: context.date)
                    let remaining = [searchRemaining, queryRemaining].compactMap { $0 }.max()
                    Button {
                        openWindow.showWindow(id: WindowID.stationSelection)
                        searchVM.search()
                    } label: {
                        Label {
                            if let remaining {
                                Text(DisplayFormatter.countdownString(remaining))
                                    .monospacedDigit()
                            } else {
                                Text("Tankstelle wählen")
                            }
                        } icon: {
                            Image(systemName: "fuelpump")
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(remaining != nil)
                    .pointerStyle(remaining == nil ? .link : nil)
                }

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
