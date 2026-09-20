import SwiftUI

/// Eine Zeile im Menüleisten-Popover: angepinnte Tankstelle/Sorte mit
/// letztem bekannten Preis und einem „×" zum direkten Entfernen (zusätzlich
/// zur Checkbox im Listen-Fenster).
struct PinnedFuelPriceRow: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    let selection: PinnedFuelSelection

    private var snapshot: FuelPriceSnapshot? {
        vm.snapshots[selection.id]
    }

    private var priceText: String {
        guard let price = snapshot?.price else { return "–" }
        return DisplayFormatter.pricePerLiterString(Decimal(price))
    }

    var body: some View {
        HStack(spacing: 8) {
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
