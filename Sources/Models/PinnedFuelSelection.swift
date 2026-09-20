import Foundation

/// Eine an die Menüleiste angepinnte Kombination aus Tankstelle und
/// Kraftstoffsorte. Stammdaten (Name, Marke, Adresse) werden beim Anpinnen
/// aus dem `GasStation`-Treffer der Umkreissuche übernommen und dauerhaft
/// mitgespeichert, weil Tankerkönigs gezielte Preisabfrage (`prices.php`,
/// siehe `TankerkoenigService.prices(ids:apiKey:)`) nur Preis und Status je
/// Stations-ID liefert – keine Namen oder Adressen mehr. `dist`/`lat`/`lng`/
/// `isOpen` werden bewusst NICHT übernommen: die Entfernung war relativ zum
/// damaligen Suchstandort und wäre nach dem Anpinnen irreführend, Position
/// und Öffnungsstatus liefert ohnehin nur die Umkreissuche.
struct PinnedFuelSelection: Codable, Identifiable, Hashable {
    let stationId: String
    let fuelKind: FuelKind
    let name: String
    let brand: String
    let street: String
    let houseNumber: String
    let place: String

    var id: String { "\(stationId)|\(fuelKind.rawValue)" }

    init(station: GasStation, fuelKind: FuelKind) {
        self.stationId = station.id
        self.fuelKind = fuelKind
        self.name = station.name
        self.brand = station.brand
        self.street = station.street
        self.houseNumber = station.houseNumber
        self.place = station.place
    }
}

/// Wie oft die angepinnten Preise aktualisiert werden. „Manuell" heißt nicht
/// unbegrenzt oft: der manuelle Button bleibt trotzdem auf ein
/// Mindestintervall von 30 Minuten begrenzt (siehe `effectiveFloorSeconds`).
enum FuelPriceRefreshInterval: Int, Codable, CaseIterable, Identifiable {
    case manual = 0
    case min30 = 30
    case min60 = 60
    case min120 = 120

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manuell"
        case .min30: return "30 Minuten"
        case .min60: return "60 Minuten"
        case .min120: return "120 Minuten"
        }
    }

    /// Intervall für die automatische Aktualisierung, `nil` bei „Manuell"
    /// (dann läuft keine Auto-Schleife, nur der manuelle Button bleibt
    /// nutzbar).
    var seconds: TimeInterval? {
        self == .manual ? nil : TimeInterval(rawValue * 60)
    }

    /// Mindestabstand, den der manuelle Button in JEDEM Modus einhält –
    /// bei „Manuell" die geforderten 30 Minuten, bei 30/60/120 ohnehin
    /// bereits erfüllt.
    var effectiveFloorSeconds: TimeInterval {
        TimeInterval(max(rawValue, 30) * 60)
    }
}

/// Zuletzt abgefragter Preis einer angepinnten Kombination. `id` bildet sich
/// genauso wie bei `PinnedFuelSelection`, damit sich beide ohne separate
/// Umrechnung über denselben Schlüssel zuordnen lassen.
struct FuelPriceSnapshot: Codable {
    let stationId: String
    let fuelKind: FuelKind
    let price: Double?
    let status: String

    var id: String { "\(stationId)|\(fuelKind.rawValue)" }
}

/// Persistierter Stand der letzten Preisabfrage – ermöglicht, nach einem
/// Neustart sofort die letzten bekannten Preise zu zeigen und das
/// Update-Intervall über den Neustart hinweg einzuhalten.
struct PinnedFuelPricesCache: Codable {
    var lastQueryAt: Date?
    var snapshots: [FuelPriceSnapshot]

    static let empty = PinnedFuelPricesCache(lastQueryAt: nil, snapshots: [])
}
