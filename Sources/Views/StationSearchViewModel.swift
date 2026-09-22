import CoreLocation
import Observation

/// Steuert den Ablauf der Tankstellenauswahl: API-Key → Standort → Abruf →
/// Liste. Lebt als Environment-Objekt für die Dauer der App-Sitzung (siehe
/// `SprittyApp.swift`), NICHT als lokaler `@State` in der View. Anders als
/// früher gibt es hier keine eigene Abklingzeit mehr, die eine Suche
/// verhindert: Das Fenster „Tankstelle wählen“ führt bei jedem Öffnen über
/// den Button im Popover immer eine frische Umkreissuche durch – die
/// Tankerkönig-Nutzungsbedingungen hält stattdessen die Sperre dieses
/// Buttons ein (siehe `secondsRemaining(asOf:)` und
/// `PinnedFuelPricesMenuView`).
@MainActor
@Observable
final class StationSearchViewModel {
    enum Phase: Equatable {
        case needsKey
        case locating
        case fetching
        case ready
        case failed(FuelPricesError)
    }

    enum FuelPricesError: Equatable {
        case rejectedKey(String)
        case network
        case decoding
        case locationDenied
        case locationRestricted
        case locationUnavailable
        case locationTimeout

        var message: String {
            switch self {
            case .rejectedKey(let msg):
                return "Der Tankerkönig-API-Schlüssel wurde abgelehnt: \(msg). Bitte prüfe den Schlüssel."
            case .network:
                return "Keine Verbindung zum Tankerkönig-Dienst. Bitte prüfe deine Internetverbindung und versuche es erneut."
            case .decoding:
                return "Die Antwort von Tankerkönig konnte nicht verarbeitet werden."
            case .locationDenied:
                return "Der Standortzugriff wurde verweigert. Bitte erlaube ihn in den Systemeinstellungen unter „Datenschutz & Sicherheit\u{201C} › „Ortungsdienste\u{201C}."
            case .locationRestricted:
                return "Die Ortungsdienste sind auf diesem Gerät eingeschränkt."
            case .locationUnavailable:
                return "Dein aktueller Standort konnte nicht ermittelt werden. Bitte versuche es erneut."
            case .locationTimeout:
                return "Die Standortermittlung hat zu lange gedauert. Bitte versuche es erneut."
            }
        }

        /// Nur bei verweigertem Standortzugriff macht ein Link in die
        /// Systemeinstellungen Sinn.
        var showsSettingsButton: Bool { self == .locationDenied }
    }

    var apiKey: String = TankerkoenigKeyStore.get() ?? ""
    /// Zuletzt gespeicherter gültiger Schlüssel – ändert er sich, lädt ein
    /// offenes Auswahlfenster neu.
    private(set) var savedKey: String = TankerkoenigKeyStore.get() ?? ""
    var isKeyFieldValid = false
    private(set) var phase: Phase = .needsKey
    private(set) var stations: [GasStation] = []
    private(set) var userCoordinate: CLLocationCoordinate2D?
    /// Vorbelegt aus den UserDefaults, damit die zuletzt gewählten Sorten
    /// einen Neustart überstehen; ohne gespeicherten Wert sind alle Sorten
    /// aktiv. Jede Änderung (z. B. per Checkbox) wird sofort zurückgespeichert.
    var enabledFuelKinds: Set<FuelKind> = FuelTypeFilterStore.get() ?? Set(FuelKind.allCases) {
        didSet { FuelTypeFilterStore.set(enabledFuelKinds) }
    }

    /// Suchradius (km) der Umkreissuche, einstellbar in den Einstellungen
    /// (Sektion „Spritpreise“) zwischen 1 und 25 km in 0,5-km-Schritten.
    /// Vorbelegt aus den UserDefaults, jede Änderung wird sofort
    /// zurückgespeichert – analog zu `enabledFuelKinds`.
    var searchRadiusKm: Double = FuelSearchRadiusStore.get() {
        didSet { FuelSearchRadiusStore.set(searchRadiusKm) }
    }

    private var running = false
    /// Zeitpunkt der letzten erfolgreichen Suche. `private(set)` statt rein
    /// privat: `StationSelectionWindow` hängt sein `.onChange(of:)` hieran
    /// auf statt an `stations` selbst (siehe dessen Kommentar).
    private(set) var lastFetchAt: Date?

    /// Feste Sperrzeit nach einer Umkreissuche – dient NICHT mehr dazu, eine
    /// erneute Suche zu verhindern (die führt `search()` jetzt immer sofort
    /// aus), sondern nur noch als Anzeigewert für den Button „Tankstelle
    /// wählen“ im Popover (siehe `PinnedFuelPricesMenuView`): Der bleibt für
    /// diese Zeit gesperrt und zeigt einen Countdown statt seines Textes.
    private let lockDuration: TimeInterval = 300

    /// Verbleibende Sekunden der Anzeige-Sperre nach der letzten Umkreissuche,
    /// `nil` wenn abgelaufen. `asOf` erlaubt einen von außen vorgegebenen
    /// Zeitpunkt (aus einer `TimelineView`) für einen live aktualisierenden
    /// Countdown.
    func secondsRemaining(asOf now: Date = Date()) -> Int? {
        guard let lastFetchAt else { return nil }
        let remaining = lockDuration - now.timeIntervalSince(lastFetchAt)
        guard remaining > 0 else { return nil }
        return Int(remaining.rounded(.up))
    }

    /// Sichtbare Stationen: mindestens eine angehakte Sorte wird dort geführt.
    var visibleStations: [GasStation] {
        stations.filter { station in
            FuelKind.allCases.contains { enabledFuelKinds.contains($0) && $0.price(for: station) != nil }
        }
    }

    /// Speichert den aktuellen Schlüssel dauerhaft, wenn er gültig ist –
    /// unabhängig von `isKeyFieldValid`, das nur bei tatsächlicher Eingabe im
    /// Textfeld gesetzt wird (siehe `ValidatedField`) und deshalb bei einem
    /// bereits gültig vorbelegten, aber unberührten Feld noch `false` wäre.
    /// Wird vom „Fertig"-Button des Einstellungsfensters aufgerufen; das
    /// eigentliche (Neu-)Laden übernimmt dort direkt danach der Button
    /// „Tankstelle wählen".
    func saveKeyIfValid() {
        guard UUID(uuidString: apiKey) != nil else { return }
        TankerkoenigKeyStore.set(apiKey)
        savedKey = apiKey
    }

    /// Führt eine Umkreissuche durch – ausgelöst vom Button „Tankstelle
    /// wählen" im Popover, unabhängig von jeder Abklingzeit (die gilt nur
    /// noch für die Sperre dieses Buttons selbst). `running` verhindert
    /// lediglich einen doppelten, gleichzeitig laufenden Aufruf.
    func search() {
        guard UUID(uuidString: apiKey) != nil else {
            phase = .needsKey
            return
        }
        guard !running else { return }
        running = true
        Task { await runFlow() }
    }

    /// Löscht den gespeicherten API-Schlüssel (UserDefaults) und setzt den
    /// laufenden Zustand zurück. Wird von „App zurücksetzen" aufgerufen,
    /// damit dabei auch kein Tankerkönig-Schlüssel zurückbleibt.
    func resetAPIKey() {
        TankerkoenigKeyStore.clear()
        apiKey = ""
        isKeyFieldValid = false
        phase = .needsKey
        stations = []
        userCoordinate = nil
        lastFetchAt = nil
    }

    private func runFlow() async {
        defer { running = false }
        phase = .locating
        do {
            let coordinate = try await LocationProvider.currentCoordinate()
            userCoordinate = coordinate
            phase = .fetching
            stations = try await TankerkoenigService.stations(
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                radiusKm: searchRadiusKm,
                apiKey: apiKey
            )
            lastFetchAt = Date()
            phase = .ready
        } catch let error as LocationError {
            phase = .failed(map(error))
        } catch let error as TankerkoenigError {
            phase = .failed(map(error))
        } catch is DecodingError {
            phase = .failed(.decoding)
        } catch {
            phase = .failed(.network)
        }
    }

    private func map(_ error: LocationError) -> FuelPricesError {
        switch error {
        case .denied: return .locationDenied
        case .restricted: return .locationRestricted
        case .unavailable: return .locationUnavailable
        case .timeout: return .locationTimeout
        }
    }

    private func map(_ error: TankerkoenigError) -> FuelPricesError {
        switch error {
        case .rejected(let message): return .rejectedKey(message)
        }
    }
}
