import Foundation

/// Formatierung von Preisen, Distanzen und Countdowns (deutsches Format).
enum DisplayFormatter {
    private static let pricePerLiter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    private static let radiusKm: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    /// Literpreis, z. B. „1,899 €".
    static func pricePerLiterString(_ decimal: Decimal) -> String {
        pricePerLiter.string(from: NSDecimalNumber(decimal: decimal)) ?? "\(decimal)"
    }

    /// Verbleibende Sekunden eines Cooldowns als „m:ss", z. B. 9:47.
    static func countdownString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Distanz mit einer Nachkommastelle, z. B. „5,5 km".
    static func radiusKmString(_ value: Double) -> String {
        (radiusKm.string(from: NSNumber(value: value)) ?? "\(value)") + " km"
    }
}
