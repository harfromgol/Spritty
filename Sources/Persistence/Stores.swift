import Foundation

/// Speichert den Tankerkönig-API-Schlüssel in den UserDefaults.
enum TankerkoenigKeyStore {
    private static let defaultsKey = "tankerkoenigAPIKey"

    static func get() -> String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }

    static func set(_ key: String) {
        UserDefaults.standard.set(key, forKey: defaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

/// Speichert den gewählten Suchradius (km) der Umkreissuche.
enum FuelSearchRadiusStore {
    private static let defaultsKey = "fuelPricesSearchRadiusKm"

    static let defaultValue: Double = 5

    static func get() -> Double {
        UserDefaults.standard.object(forKey: defaultsKey) as? Double ?? defaultValue
    }

    static func set(_ radiusKm: Double) {
        UserDefaults.standard.set(radiusKm, forKey: defaultsKey)
    }
}

/// Speichert die zuletzt gewählten sichtbaren Kraftstoffsorten der
/// Tankstellenauswahl, damit die Auswahl einen Neustart übersteht.
enum FuelTypeFilterStore {
    private static let defaultsKey = "fuelPricesEnabledFuelKinds"

    /// `nil`, wenn noch nichts gespeichert wurde – dann sind alle Sorten aktiv.
    static func get() -> Set<FuelKind>? {
        guard let rawValues = UserDefaults.standard.array(forKey: defaultsKey) as? [String] else {
            return nil
        }
        return Set(rawValues.compactMap(FuelKind.init(rawValue:)))
    }

    static func set(_ kinds: Set<FuelKind>) {
        UserDefaults.standard.set(kinds.map(\.rawValue), forKey: defaultsKey)
    }
}

/// Speichert die an die Menüleiste angepinnten Tankstellen/Sorten (JSON-Blob).
enum PinnedFuelSelectionStore {
    private static let defaultsKey = "pinnedFuelSelections"

    static func get() -> [PinnedFuelSelection] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let selections = try? JSONDecoder().decode([PinnedFuelSelection].self, from: data)
        else { return [] }
        return selections
    }

    static func set(_ selections: [PinnedFuelSelection]) {
        guard let data = try? JSONEncoder().encode(selections) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

/// Speichert Zeitpunkt und Ergebnis der letzten Preisabfrage der angepinnten
/// Kombinationen – damit nach einem Neustart sofort die letzten Preise
/// erscheinen und das Update-Intervall eingehalten wird.
enum PinnedFuelPricesCacheStore {
    private static let defaultsKey = "pinnedFuelPricesCache"

    static func get() -> PinnedFuelPricesCache {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let cache = try? JSONDecoder().decode(PinnedFuelPricesCache.self, from: data)
        else { return .empty }
        return cache
    }

    static func set(_ cache: PinnedFuelPricesCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

/// Speichert das gewählte Update-Intervall der angepinnten Spritpreise.
enum FuelPriceRefreshIntervalStore {
    private static let defaultsKey = "fuelPriceRefreshInterval"

    static func get() -> FuelPriceRefreshInterval {
        let raw = UserDefaults.standard.object(forKey: defaultsKey) as? Int
        return raw.flatMap(FuelPriceRefreshInterval.init(rawValue:)) ?? .manual
    }

    static func set(_ interval: FuelPriceRefreshInterval) {
        UserDefaults.standard.set(interval.rawValue, forKey: defaultsKey)
    }
}
