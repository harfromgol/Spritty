import SwiftUI
import AppKit

/// Inhalt des Menüleisten-Icons selbst (nicht das Popover dahinter). Bei
/// genau einer angepinnten Kombination steht der Preis direkt neben dem
/// Icon in der Menüleiste – bei mehreren wäre nicht erkennbar, welcher
/// Preis gemeint ist, dort bleibt es beim reinen Icon.
struct PinnedFuelPricesMenuBarLabel: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    /// `nil` bei keiner oder mehreren Anpinnungen. Bei genau einer immer ein
    /// Text (notfalls „–"), damit das Icon nicht flackernd zwischen Icon-only
    /// und Icon+Preis wechselt, während der erste Preis noch lädt.
    private var singleSelectionPriceText: String? {
        guard vm.pinnedSelections.count == 1, let selection = vm.pinnedSelections.first else { return nil }
        guard let price = vm.snapshots[selection.id]?.price else { return "–" }
        return DisplayFormatter.pricePerLiterString(Decimal(price))
    }

    var body: some View {
        Group {
            if let singleSelectionPriceText, let combined = Self.combinedImage(price: singleSelectionPriceText) {
                Image(nsImage: combined)
            } else {
                Image(systemName: "fuelpump.fill")
            }
        }
        .accessibilityLabel("Spritpreise")
    }

    /// Rendert Icon und Preis vorab zu EINEM Bild, statt sie SwiftUI als
    /// Bild+Text-Label zu übergeben: `MenuBarExtra` legt Bild und Titel eines
    /// Labels über AppKits eigene Status-Item-Logik übereinander, die sich
    /// über SwiftUI-Modifikatoren wie `.offset`/`.padding` auf dem Icon
    /// nachweislich nicht beeinflussen lässt (beides ohne jede Wirkung
    /// getestet) – der Preis saß dadurch sichtbar zu hoch neben der
    /// Zapfsäule. Als ein einzelnes, bereits fertig ausgerichtetes Bild
    /// übernimmt AppKit nur noch dessen (immer korrekte) Zentrierung als
    /// Ganzes.
    @MainActor
    private static func combinedImage(price: String) -> NSImage? {
        let content = HStack(spacing: 4) {
            Image(systemName: "fuelpump.fill")
            Text(price)
        }
        .font(.system(size: 13))
        .foregroundStyle(.black)
        .fixedSize()

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}
