import SwiftUI

/// Eine Zeile im Menüleisten-Popover: angepinnte Tankstelle/Sorte mit
/// letztem bekannten Preis, Auf/Ab-Buttons zum Umsortieren und einem „×"
/// zum direkten Entfernen (zusätzlich zur Checkbox im Listen-Fenster).
/// Kein Drag&Drop: Im `MenuBarExtra`-Popover (`.window`-Stil, kein
/// aktivierendes Fenster) kommt dabei keine echte `NSDraggingSession`
/// zustande – mit der Maus bewegen sich die Zeilen einfach nicht.
struct PinnedFuelPriceRow: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    let selection: PinnedFuelSelection

    private var index: Int? {
        vm.pinnedSelections.firstIndex { $0.id == selection.id }
    }

    private var isFirst: Bool { index == 0 }
    private var isLast: Bool { index == vm.pinnedSelections.count - 1 }

    private var snapshot: FuelPriceSnapshot? {
        vm.snapshots[selection.id]
    }

    private var priceText: String {
        guard let price = snapshot?.price else { return "–" }
        return DisplayFormatter.pricePerLiterString(Decimal(price))
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                Button {
                    vm.moveSelectionUp(selection.id)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(isFirst)

                Button {
                    vm.moveSelectionDown(selection.id)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(isLast)
            }
            .buttonStyle(.plain)
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .pointerStyle(.link)

            VStack(alignment: .leading, spacing: 1) {
                Text(selection.brand.isEmpty ? selection.name : selection.brand)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(selection.fuelKind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(priceText)
                .font(.subheadline.monospacedDigit())
            Button {
                vm.unpin(selection.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .help("Entfernen")
        }
    }
}
