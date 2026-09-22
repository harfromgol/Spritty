import SwiftUI

/// Eine Zeile im Menüleisten-Popover: angepinnte Tankstelle/Sorte mit
/// letztem bekannten Preis, einem Griff zum Umsortieren per Drag&Drop und
/// einem „×" zum direkten Entfernen (zusätzlich zur Checkbox im
/// Listen-Fenster).
struct PinnedFuelPriceRow: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    let selection: PinnedFuelSelection

    /// Ob gerade eine andere Zeile über dieser hier schwebt – hebt die
    /// Zielposition beim Ziehen farblich hervor.
    @State private var isDropTarget = false

    private var snapshot: FuelPriceSnapshot? {
        vm.snapshots[selection.id]
    }

    private var priceText: String {
        guard let price = snapshot?.price else { return "–" }
        return DisplayFormatter.pricePerLiterString(Decimal(price))
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .imageScale(.small)
                .accessibilityHidden(true)

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
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTarget ? Color.accentColor.opacity(0.15) : .clear)
        )
        // Zieht die ganze Zeile per `selection.id` (reiner String, dadurch
        // ohne eigenes `Transferable`-Modell übertragbar); jede andere Zeile
        // nimmt sie als Drop-Ziel an und rutscht selbst davor.
        .draggable(selection.id)
        .dropDestination(for: String.self) { draggedIDs, _ in
            guard let draggedID = draggedIDs.first else { return false }
            vm.moveSelection(id: draggedID, before: selection.id)
            return true
        } isTargeted: { isDropTarget = $0 }
    }
}
