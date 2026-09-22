import Foundation
import Observation

/// Steuert die an die Menüleiste angepinnten Tankstellen/Sorten: Auswahl,
/// Update-Intervall, Cooldown und die gezielte Preisabfrage (Tankerkönig-
/// Methode 2, `TankerkoenigService.prices(ids:apiKey:)`). Lebt als
/// `@State`-Singleton auf `SprittyApp` für die gesamte
/// Prozesslaufzeit (wie `FuelPricesViewModel`) – unabhängig von der
/// bestehenden Umkreissuche, die ihren eigenen, in-memory-only Cooldown
/// behält. Anders als dort überlebt der Cooldown hier bewusst einen
/// Neustart der App, da `lastQueryAt` aus `PinnedFuelPricesCacheStore`
/// geladen wird statt bei jedem Start neu zu beginnen.
@MainActor
@Observable
final class PinnedFuelPricesViewModel {
    private(set) var pinnedSelections: [PinnedFuelSelection]
    /// Zuletzt abgefragte Preise, nach `PinnedFuelSelection.id` – beim Start
    /// aus dem Cache geladen, damit das Popover sofort (vor jedem
    /// Netzwerkaufruf) die letzten bekannten Preise zeigt.
    private(set) var snapshots: [String: FuelPriceSnapshot]
    private(set) var lastQueryAt: Date?
    private(set) var isRefreshing = false
    private(set) var lastErrorMessage: String?

    var refreshInterval: FuelPriceRefreshInterval {
        didSet {
            guard oldValue != refreshInterval else { return }
            FuelPriceRefreshIntervalStore.set(refreshInterval)
            restartLoop()
        }
    }

    private var loopTask: Task<Void, Never>?

    init() {
        // Alles zunächst in lokale Variablen laden und erst danach den
        // Properties zuweisen: Der `@Observable`-Makro leitet Property-
        // Zugriffe über `self`; ein lesender Zugriff auf `self.<property>`
        // (auch auf eine bereits zugewiesene) gilt dafür schon als
        // „`self` verwendet", solange nicht ALLE Properties zugewiesen
        // sind – deshalb hier ausschließlich lokale Werte verwenden, bis
        // jede Property gesetzt ist.
        let selections = PinnedFuelSelectionStore.get()
        let interval = FuelPriceRefreshIntervalStore.get()
        let cache = PinnedFuelPricesCacheStore.get()

        pinnedSelections = selections
        refreshInterval = interval
        lastQueryAt = cache.lastQueryAt
        snapshots = Dictionary(uniqueKeysWithValues: cache.snapshots.map { ($0.id, $0) })

        restartLoop()
    }

    func isPinned(stationId: String, fuelKind: FuelKind) -> Bool {
        pinnedSelections.contains { $0.stationId == stationId && $0.fuelKind == fuelKind }
    }

    /// Pinnt eine Kombination an, falls noch nicht vorhanden. Übernimmt
    /// sofort den aus der Umkreissuche bereits bekannten Preis – die Station
    /// steht ja nur deshalb zur Auswahl, weil die Suche ihn gerade geliefert
    /// hat, ein Strich bis zur ersten gezielten Abfrage wäre unnötig. Löst
    /// dafür KEINEN eigenen Tankerkönig-Aufruf aus; läuft aber gerade ein
    /// automatischer Aktualisierungs-Countdown, beginnt der neu (siehe
    /// `restartCountdownIfActive()`), da die Preise ja bereits frisch sind.
    func pin(_ station: GasStation, fuelKind: FuelKind) {
        let selection = PinnedFuelSelection(station: station, fuelKind: fuelKind)
        guard !isPinned(stationId: station.id, fuelKind: fuelKind) else { return }

        let wasEmpty = pinnedSelections.isEmpty
        pinnedSelections.append(selection)
        PinnedFuelSelectionStore.set(pinnedSelections)

        snapshots[selection.id] = FuelPriceSnapshot(
            stationId: station.id,
            fuelKind: fuelKind,
            price: fuelKind.price(for: station),
            status: station.isOpen ? "open" : "closed"
        )
        persistCache()

        if wasEmpty {
            restartLoop()
        }
        restartCountdownIfActive()
    }

    /// Übernimmt Preise aus einer Umkreissuche direkt für bereits angepinnte
    /// Kombinationen, ohne dafür extra die gezielte Preisabfrage
    /// (`prices.php`) zu bemühen – `list.php` liefert die Preise ja bereits
    /// mit. Aufgerufen von `StationSelectionWindow`, sobald eine neue
    /// Umkreissuche frische `GasStation`-Ergebnisse liefert. Läuft gerade
    /// ein automatischer Aktualisierungs-Countdown, beginnt der neu.
    func applySearchResults(_ stations: [GasStation]) {
        guard !pinnedSelections.isEmpty else { return }
        let stationsByID = Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0) })

        var changed = false
        for selection in pinnedSelections {
            guard let station = stationsByID[selection.stationId] else { continue }
            snapshots[selection.id] = FuelPriceSnapshot(
                stationId: selection.stationId,
                fuelKind: selection.fuelKind,
                price: selection.fuelKind.price(for: station),
                status: station.isOpen ? "open" : "closed"
            )
            changed = true
        }
        guard changed else { return }
        persistCache()
        restartCountdownIfActive()
    }

    /// Entfernt eine angepinnte Kombination – bedient sowohl das
    /// Checkbox-Fenster als auch das „×" im Menüleisten-Popover.
    func unpin(_ selectionId: String) {
        pinnedSelections.removeAll { $0.id == selectionId }
        snapshots.removeValue(forKey: selectionId)
        PinnedFuelSelectionStore.set(pinnedSelections)
        persistCache()
    }

    /// Löscht Auswahl und Cache (nicht das Intervall, das ist eine
    /// generelle Präferenz) – aufgerufen von „App zurücksetzen".
    func resetPinnedSelections() {
        pinnedSelections = []
        snapshots = [:]
        lastQueryAt = nil
        PinnedFuelSelectionStore.set([])
        persistCache()
    }

    /// Verbleibende Sekunden bis zur nächsten erlaubten Abfrage, `nil` wenn
    /// gerade abgefragt werden darf. Rechnet gegen den persistierten
    /// `lastQueryAt` und das aktuelle Intervall (`effectiveFloorSeconds`
    /// erzwingt mindestens 30 Minuten, auch bei „Manuell").
    func secondsRemaining(asOf now: Date = Date()) -> Int? {
        guard let lastQueryAt else { return nil }
        let remaining = refreshInterval.effectiveFloorSeconds - now.timeIntervalSince(lastQueryAt)
        guard remaining > 0 else { return nil }
        return Int(remaining.rounded(.up))
    }

    func canRefresh(asOf now: Date = Date()) -> Bool {
        !isRefreshing && secondsRemaining(asOf: now) == nil
    }

    /// Feste 5-Minuten-Sperre nach der letzten Preisabfrage – unabhängig vom
    /// gewählten Aktualisierungsintervall (das erzwingt über
    /// `effectiveFloorSeconds` mindestens 30 Minuten, siehe
    /// `secondsRemaining(asOf:)`). Dient nur der Anzeige-Sperre des Buttons
    /// „Tankstelle wählen" im Popover (siehe `PinnedFuelPricesMenuView`),
    /// zusammen mit der entsprechenden Sperre von
    /// `StationSearchViewModel.secondsRemaining(asOf:)` für die
    /// Umkreissuche – zusammen decken beide jede Art von Tankerkönig-Aufruf
    /// ab.
    private static let stationButtonLockDuration: TimeInterval = 300

    func recentRequestSecondsRemaining(asOf now: Date = Date()) -> Int? {
        guard let lastQueryAt else { return nil }
        let remaining = Self.stationButtonLockDuration - now.timeIntervalSince(lastQueryAt)
        guard remaining > 0 else { return nil }
        return Int(remaining.rounded(.up))
    }

    /// Manuelle bzw. automatische Aktualisierung – beide laufen hier
    /// zusammen, damit der Cooldown unabhängig vom Auslöser eingehalten
    /// wird (analog zu `FuelPricesViewModel.start()`).
    func refresh() async {
        guard !pinnedSelections.isEmpty, canRefresh() else { return }
        guard let apiKey = TankerkoenigKeyStore.get(), UUID(uuidString: apiKey) != nil else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let uniqueIDs = Array(Set(pinnedSelections.map(\.stationId)))
            let prices = try await TankerkoenigService.prices(ids: uniqueIDs, apiKey: apiKey)

            for selection in pinnedSelections {
                guard let stationPrice = prices[selection.stationId] else { continue }
                snapshots[selection.id] = FuelPriceSnapshot(
                    stationId: selection.stationId,
                    fuelKind: selection.fuelKind,
                    price: stationPrice.price(for: selection.fuelKind),
                    status: stationPrice.status
                )
            }
            lastQueryAt = Date()
            lastErrorMessage = nil
            persistCache()
        } catch let error as TankerkoenigError {
            if case .rejected(let message) = error {
                lastErrorMessage = "Tankerkönig hat die Anfrage abgelehnt: \(message)"
            }
        } catch {
            lastErrorMessage = "Aktualisierung fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Setzt den automatischen Aktualisierungs-Countdown auf den vollen
    /// Wert zurück, aber NUR wenn gerade einer läuft (`secondsRemaining()
    /// != nil`) – ohne laufenden Countdown wird keiner neu gestartet.
    /// Aufgerufen, nachdem `pin(_:fuelKind:)` oder `applySearchResults(_:)`
    /// Preise bereits ohne eigenen Tankerkönig-Aufruf aufgefrischt haben:
    /// die nächste fällige Abfrage darf sich entsprechend weiter nach
    /// hinten verschieben.
    private func restartCountdownIfActive() {
        guard secondsRemaining() != nil else { return }
        lastQueryAt = Date()
        persistCache()
        restartLoop()
    }

    private func persistCache() {
        PinnedFuelPricesCacheStore.set(
            PinnedFuelPricesCache(lastQueryAt: lastQueryAt, snapshots: Array(snapshots.values))
        )
    }

    private func restartLoop() {
        loopTask?.cancel()
        loopTask = Task { await self.runLoop() }
    }

    /// Selbstständige Hintergrundschleife für die automatische
    /// Aktualisierung – bewusst in `init()`/über `restartLoop()` gestartet
    /// statt über `.task {}` an einem Fenster (wie
    /// `AppCommands.scheduleDailyDueCheck()` es für die tägliche
    /// Fälligkeitsprüfung tut): Jene Schleife stirbt und startet neu, wenn
    /// das Hauptfenster geschlossen/erneut geöffnet wird – für dieses
    /// Feature falsch, da die Menüleiste gerade OHNE offenes Hauptfenster
    /// funktionieren soll. Da dieser View-Model selbst als
    /// `@State`-Singleton auf `SprittyApp` nie neu erzeugt wird,
    /// ist ein nie explizit abgebrochener Hintergrund-Task hier kein Leak,
    /// sondern ein bewusster, dauerhafter Hintergrund-Loop für die gesamte
    /// Prozesslaufzeit. `refreshInterval`s `didSet` bricht die laufende
    /// Schleife ab und startet sie neu, damit ein Intervall-Wechsel nicht
    /// erst nach Ablauf des alten, mitten im Schlaf befindlichen Intervalls
    /// wirkt.
    private func runLoop() async {
        guard let interval = refreshInterval.seconds else { return }
        while !Task.isCancelled {
            let due = (lastQueryAt ?? .distantPast).addingTimeInterval(interval)
            let wait = due.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
                if Task.isCancelled { return }
            }
            guard !pinnedSelections.isEmpty else { return }
            await refresh()
        }
    }
}
