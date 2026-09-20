import SwiftUI

/// Einstellungsfenster: Liste der Abschnitte links, Inhalt rechts – analog zu
/// den Systemeinstellungen (Aufbau wie in FuhrparkDesktop).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StationSearchViewModel.self) private var searchViewModel
    @State private var selection: SettingsSection = .fuelPrices

    /// `List(selection:)` erwartet eine optionale Bindung; ein `nil` von der
    /// Liste (Klick ins Leere) fällt auf den ersten Abschnitt zurück.
    private var selectionBinding: Binding<SettingsSection?> {
        Binding(
            get: { selection },
            set: { selection = $0 ?? .fuelPrices }
        )
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                List(selection: selectionBinding) {
                    ForEach(SettingsSection.allCases) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 180)

                Divider()

                ScrollView {
                    content(for: selection)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { finish() }
                }
            }
        }
        .frame(width: 640, height: 420)
    }

    @ViewBuilder
    private func content(for section: SettingsSection) -> some View {
        switch section {
        case .fuelPrices:
            FuelPricesSettingsSection()
        case .about:
            AboutSettingsSection()
        }
    }

    /// Speichert den Schlüssel (falls gültig) – ein offenes Auswahlfenster
    /// lädt daraufhin selbstständig neu (siehe `StationSearchViewModel.savedKey`).
    private func finish() {
        searchViewModel.saveKeyIfValid()
        dismiss()
    }
}

/// Sektion „Spritpreise": Tankerkönig-API-Schlüssel und Suchradius.
private struct FuelPricesSettingsSection: View {
    @Environment(StationSearchViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm
        VStack(alignment: .leading, spacing: 10) {
            Text("Tankerkönig-API-Schlüssel")
                .font(.headline)
            Text("Wird für die Umkreissuche nach Spritpreisen in der Nähe benötigt.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            APIKeyField(text: $vm.apiKey)

            Divider()
                .padding(.vertical, 4)

            Text("Suchradius")
                .font(.headline)
            Text("Wie weit die Umkreissuche nach Tankstellen reicht.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                Slider(value: $vm.searchRadiusKm, in: 1...25, step: 0.5) {
                    Text("Suchradius")
                } minimumValueLabel: {
                    Text("1 km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Text("25 km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .labelsHidden()

                Text(DisplayFormatter.radiusKmString(vm.searchRadiusKm))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

/// Textfeld mit Live-Validierung wie `ValidatedField` in FuhrparkDesktop:
/// grüner Rahmen bei gültigem Schlüssel (UUID), roter bei ungültigem,
/// neutral solange leer.
private struct APIKeyField: View {
    @Binding var text: String

    private var isValid: Bool { UUID(uuidString: text) != nil }

    private var borderColor: Color {
        if text.isEmpty { return Color.secondary.opacity(0.35) }
        return isValid ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("API-Schlüssel")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("API-Schlüssel", text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor, lineWidth: 1.5)
                )
                .onChange(of: text) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed != newValue { text = trimmed }
                }

            Text("API-Schlüssel (UUID), z. B. 474e5046-deaf-4f9b-9a32-9797b778f047")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

/// Sektion „Info": Version und Datenquelle.
private struct AboutSettingsSection: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spritty")
                .font(.headline)
            Text("Version \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Zeigt die Preise ausgewählter Tankstellen in der Menüleiste an.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TankerkoenigAttributionView()
        }
    }
}

/// Abschnitte im Einstellungsfenster.
enum SettingsSection: String, CaseIterable, Identifiable {
    case fuelPrices
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuelPrices: return "Spritpreise"
        case .about: return "Info"
        }
    }

    var systemImage: String {
        switch self {
        case .fuelPrices: return "fuelpump.circle"
        case .about: return "info.circle"
        }
    }
}
