import CoreLocation
import Observation

/// Steuert den Ablauf der Tankstellenauswahl: API-Key → Standort → Abruf →
/// Liste. Lebt als Environment-Objekt für die Dauer der App-Sitzung (siehe
/// `SprittyApp.swift`), NICHT als lokaler `@State` in der View – so
/// bleiben Cooldown/Countdown erhalten, wenn das Fenster geschlossen wird. Ein
/// erneutes Öffnen aktualisiert automatisch, aber nur wenn die
/// Abklingzeit bereits abgelaufen ist – `start()` bleibt dafür der zentrale
/// Cooldown-Wächter, der Tankerkönigs Rate Limit unabhängig vom Auslöser
/// einhält.
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
    private var lastFetchAt: Date?

    /// Tankerkönigs Nutzungsbedingungen bitten darum, nicht öfter als alle
    /// 5 Minuten abzufragen; hier bewusst mit Sicherheitsabstand auf 10
    /// Minuten gesetzt. Gilt für jede neue Abfrage (Aktualisieren UND einen
    /// neu eingegebenen Schlüssel), nicht nur den manuellen Button.
    private let cooldown: TimeInterval = 600

    /// Verbleibende Sekunden bis zur nächsten erlaubten Abfrage, `nil` wenn
    /// gerade abgefragt werden darf. `asOf` erlaubt einen von außen
    /// vorgegebenen Zeitpunkt (z. B. aus einer `TimelineView`) für einen live
    /// aktualisierenden Countdown.
    func secondsRemaining(asOf now: Date = Date()) -> Int? {
        guard let lastFetchAt else { return nil }
        let remaining = cooldown - now.timeIntervalSince(lastFetchAt)
        guard remaining > 0 else { return nil }
        return Int(remaining.rounded(.up))
    }

    /// Ob gerade eine neue Abfrage gestartet werden darf (weder ein Abruf
    /// läuft noch die Abklingzeit aktiv ist). Der automatische Erststart ist
    /// davon nicht betroffen, da `lastFetchAt` dann noch `nil` ist.
    func canQuery(asOf now: Date = Date()) -> Bool {
        !running && secondsRemaining(asOf: now) == nil
    }

    /// Sichtbare Stationen: mindestens eine angehakte Sorte wird dort geführt.
    var visibleStations: [GasStation] {
        stations.filter { station in
            FuelKind.allCases.contains { enabledFuelKinds.contains($0) && $0.price(for: station) != nil }
        }
    }

    /// Wird bei jedem Erscheinen der View aufgerufen (auch nach Rückkehr aus
    /// dem Schließen des Fensters). Startet den Ablauf, wenn ein gültiger
    /// Schlüssel hinterlegt ist – `start()` lässt das aber nur zu, wenn
    /// gerade keine Abfrage läuft und die Abklingzeit bereits abgelaufen ist;
    /// andernfalls bleiben die zuletzt geladenen Daten samt Countdown einfach
    /// stehen.
    func onAppear() {
        guard UUID(uuidString: apiKey) != nil else {
            phase = .needsKey
            return
        }
        start()
    }

    /// Speichert den aktuellen Schlüssel dauerhaft, wenn er gültig ist –
    /// unabhängig von `isKeyFieldValid`, das nur bei tatsächlicher Eingabe im
    /// Textfeld gesetzt wird (siehe `ValidatedField`) und deshalb bei einem
    /// bereits gültig vorbelegten, aber unberührten Feld noch `false` wäre.
    /// Wird vom „Fertig"-Button des Einstellungsfensters aufgerufen; das
    /// eigentliche (Neu-)Laden übernimmt dort direkt danach `onAppear()`,
    /// aber nur wenn das Auswahlfenster gerade offen ist.
    func saveKeyIfValid() {
        guard UUID(uuidString: apiKey) != nil else { return }
        TankerkoenigKeyStore.set(apiKey)
        savedKey = apiKey
    }

    /// Manuelles Aktualisieren, respektiert die Abklingzeit (siehe `start()`).
    func refresh() {
        start()
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

    /// Zentrale Stelle, die jede neue Abfrage gegen die Abklingzeit prüft –
    /// „Aktualisieren", ein neu gespeicherter Schlüssel und die automatische
    /// Prüfung bei jedem `onAppear()` laufen hier durch, damit die
    /// Tankerkönig-Nutzungsbedingungen unabhängig vom Auslöser eingehalten
    /// werden.
    private func start() {
        guard canQuery() else { return }
        running = true
        Task { await runFlow() }
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
