import SwiftUI
import AppKit

/// Fenster zur Auswahl von Tankstelle und Spritsorte: Standort →
/// Tankerkönig-Umkreissuche → Liste aller Tankstellen im Radius, je Sorte
/// eine Checkbox zum Anpinnen an die Menüleiste. Der API-Schlüssel und der
/// Suchradius werden in den Einstellungen gepflegt.
struct StationSelectionWindow: View {
    @Environment(StationSearchViewModel.self) private var vm
    @Environment(PinnedFuelPricesViewModel.self) private var pinnedVM
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch vm.phase {
            case .needsKey:
                needsKeyHint
            case .locating:
                progressView("Standort wird ermittelt…")
            case .fetching:
                progressView("Tankstellen werden geladen…")
            case .ready:
                stationList
            case .failed(let error):
                if vm.stations.isEmpty {
                    errorView(error)
                } else {
                    stationList
                        .overlay(alignment: .top) { errorBanner(error) }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 400)
        // Die eigentliche Umkreissuche löst der Button „Tankstelle wählen"
        // im Popover aus (immer, ohne Abklingzeit – siehe
        // `PinnedFuelPricesMenuView`); dieses Fenster zeigt nur das
        // Ergebnis. Liefert eine Suche frische Preise, werden bereits
        // angepinnte Kombinationen direkt hier übernommen.
        // Auslöser ist `lastFetchAt`, NICHT `vm.stations` selbst: Tankerkönigs
        // Umkreissuche liefert bei zwei Suchen oft exakt dieselben Treffer
        // (reale Tankstellen ändern sich selten, der Test-API-Key liefert
        // sogar IMMER dieselben Werte) – ein `.onChange(of: vm.stations)`
        // würde dann, weil sich der verglichene Wert nicht ändert, bei der
        // zweiten Suche einfach nicht mehr feuern und bereits angepinnte
        // Preise blieben auf dem Stand der ersten Suche stehen. `lastFetchAt`
        // bekommt dagegen bei JEDER erfolgreichen Suche einen frischen
        // `Date()`-Wert und unterscheidet sich deshalb garantiert vom vorigen.
        .onChange(of: vm.lastFetchAt) { _, _ in
            pinnedVM.applySearchResults(vm.stations)
        }
    }

    private var needsKeyHint: some View {
        ContentUnavailableView {
            Label("Kein API-Schlüssel", systemImage: "key")
        } description: {
            VStack(spacing: 4) {
                Text("Hinterlege in den Einstellungen deinen Tankerkönig-API-Schlüssel, um Tankstellen in deiner Umgebung zu sehen.")
                Link("Kostenlos registrieren unter tankerkoenig.de", destination: URL(string: "https://creativecommons.tankerkoenig.de")!)
            }
        } actions: {
            Button("Einstellungen öffnen") {
                openWindow.showWindow(id: WindowID.settings)
            }
            .buttonStyle(.glass)
            .pointerStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func progressView(_ text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: StationSearchViewModel.FuelPricesError) -> some View {
        ContentUnavailableView {
            Label("Fehler", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.message)
        } actions: {
            HStack {
                Button("Erneut versuchen") { vm.search() }
                    .buttonStyle(.glass)
                    .pointerStyle(.link)
                if error.showsSettingsButton {
                    Button("Systemeinstellungen öffnen") { openLocationSettings() }
                        .buttonStyle(.glass)
                        .pointerStyle(.link)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ error: StationSearchViewModel.FuelPricesError) -> some View {
        Text(error.message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.red.opacity(0.4), lineWidth: 1))
            .padding(.top, 8)
    }

    /// Kopfzeile mit Sortenfilter, darunter die Liste.
    private var stationList: some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: 8) {
            FuelTypeFilterView(enabled: $vm.enabledFuelKinds)

            ScrollView {
                GlassEffectContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        if vm.visibleStations.isEmpty {
                            ContentUnavailableView(
                                "Keine Tankstellen",
                                systemImage: "fuelpump",
                                description: Text("Im Umkreis von \(DisplayFormatter.radiusKmString(vm.searchRadiusKm)) wurde keine Tankstelle mit den gewählten Sorten gefunden.")
                            )
                            .padding(.top, 60)
                        } else {
                            ForEach(vm.visibleStations) { station in
                                GasStationPriceRow(station: station, enabled: vm.enabledFuelKinds)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            TankerkoenigAttributionView()
        }
        .padding(20)
    }

    private func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Eine Tankstelle in der Auswahl: Stammdaten plus eine Checkbox mit Preis
/// je (sichtbarer) Sorte, die die Station führt.
struct GasStationPriceRow: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    let station: GasStation
    let enabled: Set<FuelKind>

    private var availableKinds: [FuelKind] {
        FuelKind.allCases.filter { enabled.contains($0) && $0.price(for: station) != nil }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.brand.isEmpty ? station.name : station.brand)
                        .font(.subheadline.bold())
                    Text("\(station.street) \(station.houseNumber), \(station.place)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(availableKinds) { kind in
                    if let price = kind.price(for: station) {
                        Toggle(isOn: Binding(
                            get: { vm.isPinned(stationId: station.id, fuelKind: kind) },
                            set: { isOn in
                                if isOn {
                                    vm.pin(station, fuelKind: kind)
                                } else {
                                    vm.unpin(PinnedFuelSelection(station: station, fuelKind: kind).id)
                                }
                            }
                        )) {
                            HStack {
                                Text(kind.displayName)
                                Spacer()
                                Text(DisplayFormatter.pricePerLiterString(Decimal(price)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }
}
