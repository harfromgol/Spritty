import CoreLocation

/// Eine Tankstelle aus der Tankerkönig-Umkreissuche.
struct GasStation: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let brand: String
    let street: String
    let houseNumber: String
    let place: String
    let lat: Double
    let lng: Double
    let dist: Double
    let isOpen: Bool
    let diesel: Double?
    let e5: Double?
    let e10: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

/// Antwort der Tankerkönig-`list.php`-Umkreissuche.
struct TankerkoenigListResponse: Decodable, Sendable {
    let ok: Bool
    /// Nur bei Fehlern gesetzt (`ok == false`).
    let message: String?
    let stations: [GasStation]?
}

/// Die drei über Tankerkönig abfragbaren Kraftstoffsorten.
enum FuelKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case diesel
    case e5
    case e10

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diesel: return "Diesel"
        case .e5: return "Super E5"
        case .e10: return "Super E10"
        }
    }

    /// Preis dieser Sorte an der Station, falls sie dort geführt wird.
    func price(for station: GasStation) -> Double? {
        switch self {
        case .diesel: return station.diesel
        case .e5: return station.e5
        case .e10: return station.e10
        }
    }
}
