import SwiftUI

/// Checkboxen zum Ein-/Ausblenden der Kraftstoffsorten auf der Karte.
struct FuelTypeFilterView: View {
    @Binding var enabled: Set<FuelKind>

    var body: some View {
        HStack(spacing: 16) {
            ForEach(FuelKind.allCases) { kind in
                Toggle(kind.displayName, isOn: Binding(
                    get: { enabled.contains(kind) },
                    set: { isOn in
                        if isOn { enabled.insert(kind) } else { enabled.remove(kind) }
                    }
                ))
                .toggleStyle(.checkbox)
            }
        }
    }
}
