import CoreLocation

enum LocationError: Error {
    case denied
    case restricted
    case unavailable
    case timeout
}

/// Ermittelt einmalig den aktuellen Standort. Nutzt bewusst das klassische
/// `CLLocationManagerDelegate`-Muster statt `CLLocationUpdate.liveUpdates()` –
/// analog zur bereits im Projekt etablierten Konkurrenz-Brücke in
/// `WindowFramePersistence.swift` (`@MainActor`-Coordinator,
/// `nonisolated(unsafe)` für den gehaltenen Zustand, `MainActor.assumeIsolated`
/// in den nonisolated Delegate-Callbacks).
enum LocationProvider {
    /// Läuft die Standortermittlung gegen ein 120-Sekunden-Zeitlimit. Das
    /// Zeitlimit deckt auch die Wartezeit auf die Nutzerentscheidung im
    /// System-Berechtigungsdialog ab (falls die Berechtigung noch nicht erteilt
    /// ist) – daher bewusst großzügig bemessen, nicht nur für den eigentlichen
    /// GPS/WLAN-Fix. `requestOnMain()` bleibt eine eigene `@MainActor`-Funktion,
    /// damit `withCheckedThrowingContinuation` seine Isolation erbt und deren
    /// Callback-Closure direkt den `@MainActor`-isolierten `LocationDelegate`
    /// ansprechen darf – innerhalb einer `@Sendable`-TaskGroup-Closure wäre diese
    /// Vererbung nicht gegeben.
    static func currentCoordinate() async throws -> CLLocationCoordinate2D {
        try await withThrowingTaskGroup(of: CLLocationCoordinate2D.self) { group in
            group.addTask { try await requestOnMain() }
            group.addTask {
                try await Task.sleep(for: .seconds(120))
                throw LocationError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    @MainActor
    private static func requestOnMain() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = LocationDelegate(continuation: continuation)
            delegate.start()
        }
    }
}

@MainActor
private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    // Wird praktisch nur auf dem Main-Actor angefasst; die Delegate-Methoden
    // sind protokollbedingt nonisolated und hoppen selbst per
    // `MainActor.assumeIsolated` zurück – siehe WindowFramePersistence.Coordinator
    // für das identische, bereits bewährte Muster.
    nonisolated(unsafe) private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var didResume = false
    // Hält sich selbst am Leben, bis der Callback eintrifft (kein anderer
    // Besitzer hält eine Referenz auf den Delegate).
    private var selfRetain: LocationDelegate?

    init(continuation: CheckedContinuation<CLLocationCoordinate2D, Error>) {
        self.continuation = continuation
        super.init()
        manager.delegate = self
        selfRetain = self
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied:
            resume(.failure(LocationError.denied))
        case .restricted:
            resume(.failure(LocationError.restricted))
        default:
            manager.requestLocation()
        }
    }

    // Die eingehenden `manager`-Parameter werden bewusst ignoriert (Underscore) –
    // sie sind dieselbe Instanz wie `self.manager`, aber als task-isoliertes
    // Argument einer nonisolated Callback-Signatur lässt sich das dem Compiler
    // nicht beweisen. Stattdessen wird die eigene, bereits `@MainActor`-sichere
    // `self.manager`-Property verwendet.
    nonisolated func locationManagerDidChangeAuthorization(_ changedManager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .authorizedAlways:
                manager.requestLocation()
            case .denied:
                resume(.failure(LocationError.denied))
            case .restricted:
                resume(.failure(LocationError.restricted))
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ updatedManager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            if let coordinate = locations.last?.coordinate {
                resume(.success(coordinate))
            }
        }
    }

    nonisolated func locationManager(_ failedManager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            resume(.failure(LocationError.unavailable))
        }
    }

    private func resume(_ result: Result<CLLocationCoordinate2D, Error>) {
        guard !didResume else { return }
        didResume = true
        continuation?.resume(with: result)
        continuation = nil
        selfRetain = nil
    }
}
