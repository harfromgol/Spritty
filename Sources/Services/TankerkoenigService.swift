import Foundation

/// Fehler beim Abruf der Tankerkönig-Umkreissuche.
enum TankerkoenigError: Error {
    /// Die API hat den Aufruf mit `ok: false` abgelehnt (z. B. ungültiger Key).
    case rejected(String)
}

/// Preis einer einzelnen Station aus der gezielten Preisabfrage
/// (`prices.php`). Eigener `init(from:)`, weil Tankerkönig für
/// `diesel`/`e5`/`e10` JSON `false` statt einer Zahl liefert, sobald die
/// Station nicht `status == "open"` ist – ein synthetisierter `Decodable`
/// würde daran mit einem `DecodingError` scheitern. `try?` lässt sowohl
/// einen Bool-Wert als auch ein fehlendes Feld einfach zu `nil` werden.
struct StationPrice: Decodable, Sendable {
    let status: String
    let diesel: Double?
    let e5: Double?
    let e10: Double?

    private enum CodingKeys: String, CodingKey { case status, diesel, e5, e10 }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        diesel = try? container.decode(Double.self, forKey: .diesel)
        e5 = try? container.decode(Double.self, forKey: .e5)
        e10 = try? container.decode(Double.self, forKey: .e10)
    }
}

/// Antwort der Tankerkönig-`prices.php`-Preisabfrage.
struct TankerkoenigPricesResponse: Decodable, Sendable {
    let ok: Bool
    /// Nur bei Fehlern gesetzt (`ok == false`).
    let message: String?
    let prices: [String: StationPrice]?
}

extension StationPrice {
    /// Preis der angegebenen Sorte, falls die Station sie führt – Pendant zu
    /// `FuelKind.price(for station: GasStation)`, nur für das Ergebnis der
    /// gezielten Preisabfrage statt der Umkreissuche.
    func price(for kind: FuelKind) -> Double? {
        switch kind {
        case .diesel: return diesel
        case .e5: return e5
        case .e10: return e10
        }
    }
}

/// Zugriff auf die Tankerkönig-API (Creative Commons). Siehe
/// https://creativecommons.tankerkoenig.de/ – „list.php" für die
/// Umkreissuche (Methode 1), „prices.php" für die gezielte Abfrage
/// einzelner Stations-IDs (Methode 2).
enum TankerkoenigService {
    private static let listBase = URL(string: "https://creativecommons.tankerkoenig.de/json/list.php")!
    private static let pricesBase = URL(string: "https://creativecommons.tankerkoenig.de/json/prices.php")!

    /// Höchstzahl an Stations-IDs, die Tankerkönig je Aufruf von `prices.php`
    /// entgegennimmt.
    private static let maxIDsPerRequest = 10

    /// Tankstellen im angegebenen Radius um eine Position, alle Kraftstoffsorten.
    /// Wirft bei Netzwerk-/Dekodierfehlern den jeweiligen Fehler von
    /// `URLSession`/`JSONDecoder` durch; bei einer von der API abgelehnten
    /// Anfrage `TankerkoenigError.rejected(message)`.
    static func stations(lat: Double, lng: Double, radiusKm: Double, apiKey: String) async throws -> [GasStation] {
        var components = URLComponents(url: listBase, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "rad", value: String(radiusKm)),
            URLQueryItem(name: "sort", value: "dist"),
            URLQueryItem(name: "type", value: "all"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(TankerkoenigListResponse.self, from: data)

        guard decoded.ok else {
            throw TankerkoenigError.rejected(decoded.message ?? "Unbekannter Fehler")
        }
        return decoded.stations ?? []
    }

    /// Gezielte Preisabfrage für die angegebenen Stations-IDs. Teilt die IDs
    /// selbst in `maxIDsPerRequest`-Gruppen auf und führt bei Bedarf mehrere
    /// Aufrufe zusammen – realistische Auswahlgrößen (angepinnte Stationen)
    /// liegen im einstelligen Bereich, ein `TaskGroup` für parallele Aufrufe
    /// lohnt sich hier nicht. Lehnt eine Gruppe die Anfrage ab
    /// (`ok == false`), wird sofort mit `TankerkoenigError.rejected`
    /// abgebrochen, da ein abgelehnter Key/eine abgelehnte Anfrage bei jeder
    /// weiteren Gruppe identisch scheitern würde.
    static func prices(ids: [String], apiKey: String) async throws -> [String: StationPrice] {
        var result: [String: StationPrice] = [:]
        for chunk in ids.chunked(into: maxIDsPerRequest) {
            var components = URLComponents(url: pricesBase, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "ids", value: chunk.joined(separator: ",")),
                URLQueryItem(name: "apikey", value: apiKey)
            ]

            let (data, _) = try await URLSession.shared.data(from: components.url!)
            let decoded = try JSONDecoder().decode(TankerkoenigPricesResponse.self, from: data)

            guard decoded.ok else {
                throw TankerkoenigError.rejected(decoded.message ?? "Unbekannter Fehler")
            }
            result.merge(decoded.prices ?? [:]) { _, new in new }
        }
        return result
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
