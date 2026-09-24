import SwiftUI
import AppKit

/// Inhalt des Menüleisten-Icons selbst (nicht das Popover dahinter). Ist
/// mindestens eine Kombination angepinnt, steht der Preis der OBERSTEN
/// Zeile im Popover direkt neben dem Icon – wer eine andere Tankstelle dort
/// sehen will, schiebt sie im Popover per Auf/Ab-Buttons nach oben.
struct PinnedFuelPricesMenuBarLabel: View {
    @Environment(PinnedFuelPricesViewModel.self) private var vm

    /// `nil` ohne Anpinnung. Sonst immer ein Text (notfalls „–"), damit das
    /// Icon nicht flackernd zwischen Icon-only und Icon+Preis wechselt,
    /// während der erste Preis noch lädt.
    private var topPriceText: String? {
        guard let selection = vm.pinnedSelections.first else { return nil }
        guard let price = vm.snapshots[selection.id]?.price else { return "–" }
        return DisplayFormatter.pricePerLiterString(Decimal(price))
    }

    var body: some View {
        Group {
            if let topPriceText, let combined = Self.combinedImage(price: topPriceText) {
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
