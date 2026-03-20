import Foundation
import CoreLocation
import Combine

/// GPS tracking service using CLLocationManager.
/// Equivalent of Android's LocationService.kt + DefaultLocationTracker.kt.
///
/// RESPONSIBILITIES:
/// 1. Track device location continuously
/// 2. Forward GPS to Unity via UnityBridge
/// 3. Kotlin-side hex discovery (call backend /v1/game/hexes/explore)
/// 4. Client-side route simulation (same as Kotlin's startRouteSimulation)
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = LocationService()

    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var firstExploreCompleted: Bool = false

    /// Last sent coordinates (avoid spamming Unity with identical positions)
    private var lastSentLat: Double = 0
    private var lastSentLon: Double = 0

    /// Discovery throttling (max 1 explore call per 2 seconds, matches Android)
    private var lastExploreTime: Date = .distantPast
    private let exploreThrottleInterval: TimeInterval = 2.0

    // MARK: - Simulation State (matches Kotlin DefaultLocationTracker)

    @Published var isSimRunning: Bool = false
    @Published var isSimPaused: Bool = false
    @Published var simSpeedKmh: Double = 50

    private var simRoute: [(lat: Double, lon: Double)] = []
    private var simTimer: Timer?
    private var simCurrentIndex: Int = 0
    private var simDistanceCovered: Double = 0
    private var simSegmentDistance: Double = 0

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // meters
        // Note: Background location requires UIBackgroundModes capability
        // locationManager.allowsBackgroundLocationUpdates = true
        // locationManager.showsBackgroundLocationIndicator = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Start / Stop

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTracking() {
        print("🚀 LocationService: Starting GPS tracking")
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        print("■ LocationService: Stopped GPS tracking")
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        // Block real GPS when simulation is active (matches Kotlin _manualLocation override)
        if isSimRunning {
            return
        }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let bearing = location.course >= 0 ? location.course : 0

        // Only send to Unity if position changed (matches Android behavior)
        if lat != lastSentLat || lon != lastSentLon {
            let message = "\(lat),\(lon),\(bearing)"
            print("📍 LocationService: GPS → Unity: \(message)")

            UnityBridge.shared.send("UpdatePlayerPositionFromString", value: message)

            lastSentLat = lat
            lastSentLon = lon
        }

        // Kotlin-side hex discovery (same as Android LocationService.exploreAtLocation)
        exploreAtLocation(lat: lat, lon: lon)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 LocationService: Authorization changed to \(authorizationStatus.rawValue)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationService: GPS error — \(error.localizedDescription)")
    }

    // MARK: - Route Simulation (matches Kotlin DefaultLocationTracker)

    /// Start route simulation — interpolates positions along the route at the given speed.
    /// Same logic as Kotlin's startRouteSimulation() in DefaultLocationTracker.kt
    func startRouteSimulation(path: [(lat: Double, lon: Double)], speedKmh: Double) {
        stopRouteSimulation()

        guard path.count >= 2 else {
            print("⚠️ LocationService: Route needs at least 2 points")
            return
        }

        simRoute = path
        simSpeedKmh = speedKmh
        simCurrentIndex = 0
        simDistanceCovered = 0
        simSegmentDistance = 0

        isSimRunning = true
        isSimPaused = false

        print("🚗 LocationService: Simulation started — \(path.count) points, \(Int(speedKmh)) km/h")

        // Advance to first valid segment
        advanceToNextSegment()

        // Timer at 100ms (matches Kotlin's delay(100))
        simTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.simulationTick()
        }
    }

    func pauseRouteSimulation() {
        isSimPaused = true
        // Just freeze — simulationTick returns early when paused,
        // so the last interpolated position stays on screen.
        print("⏸️ LocationService: Simulation paused (frozen in place)")
    }

    func resumeRouteSimulation() {
        isSimPaused = false
        print("▶️ LocationService: Simulation resumed")
    }

    func stopRouteSimulation() {
        simTimer?.invalidate()
        simTimer = nil
        let wasRunning = isSimRunning
        isSimRunning = false
        isSimPaused = false
        simRoute = []

        if wasRunning {
            print("⏹️ LocationService: Simulation stopped — returning to real GPS")

            // Immediately send real GPS position back to Unity
            if let realLocation = currentLocation {
                let lat = realLocation.coordinate.latitude
                let lon = realLocation.coordinate.longitude
                let bearing = realLocation.course >= 0 ? realLocation.course : 0
                let message = "\(lat),\(lon),\(bearing)"
                print("📍 LocationService: Sending real GPS to Unity: \(message)")
                UnityBridge.shared.send("UpdatePlayerPositionFromString", value: message)
                lastSentLat = lat
                lastSentLon = lon
            }
        }
    }

    /// Reset GPS tracking state for a new player session.
    /// Forces next GPS update to re-send to Unity and re-trigger explore.
    func resetForNewSession() {
        lastSentLat = 0
        lastSentLon = 0
        lastExploreTime = .distantPast
        firstExploreCompleted = false
        print("📍 LocationService: Reset for new session — GPS will re-send on next update")

        // Force immediate re-send of current position
        if let loc = currentLocation {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            let bearing = loc.course >= 0 ? loc.course : 0
            let message = "\(lat),\(lon),\(bearing)"
            UnityBridge.shared.send("UpdatePlayerPositionFromString", value: message)
            lastSentLat = lat
            lastSentLon = lon
            exploreAtLocation(lat: lat, lon: lon)
        }
    }

    func setSimulationSpeed(_ speedKmh: Double) {
        simSpeedKmh = speedKmh
    }

    // MARK: - Simulation internals

    private func simulationTick() {
        guard isSimRunning else {
            simTimer?.invalidate()
            return
        }

        // Paused — just wait
        if isSimPaused { return }

        guard simCurrentIndex < simRoute.count - 1 else {
            // Route finished
            print("🏁 LocationService: Simulation complete!")
            stopRouteSimulation()
            return
        }

        let startNode = simRoute[simCurrentIndex]
        let endNode = simRoute[simCurrentIndex + 1]

        // Step distance based on current speed (100ms tick)
        let speedMps = simSpeedKmh / 3.6
        let stepDist = speedMps * 0.1

        simDistanceCovered += stepDist

        if simSegmentDistance < 1 {
            // Skip tiny segments
            simCurrentIndex += 1
            advanceToNextSegment()
            return
        }

        let fraction = min(simDistanceCovered / simSegmentDistance, 1.0)

        // Interpolate position
        let lat = startNode.lat + (endNode.lat - startNode.lat) * fraction
        let lon = startNode.lon + (endNode.lon - startNode.lon) * fraction

        // Calculate bearing
        let bearing = calculateBearing(
            lat1: startNode.lat, lon1: startNode.lon,
            lat2: endNode.lat, lon2: endNode.lon
        )

        let speedMpsFloat = simSpeedKmh / 3.6
        sendSimulatedPositionToUnity(lat: lat, lon: lon, bearing: bearing, speed: speedMpsFloat)

        // Also trigger hex discovery with simulated position
        exploreAtLocation(lat: lat, lon: lon)

        // Move to next segment if we've covered this one
        if simDistanceCovered >= simSegmentDistance {
            simCurrentIndex += 1
            advanceToNextSegment()
        }
    }

    private func advanceToNextSegment() {
        simDistanceCovered = 0

        guard simCurrentIndex < simRoute.count - 1 else { return }

        let start = simRoute[simCurrentIndex]
        let end = simRoute[simCurrentIndex + 1]

        simSegmentDistance = distanceBetween(
            lat1: start.lat, lon1: start.lon,
            lat2: end.lat, lon2: end.lon
        )
    }

    private func sendSimulatedPositionToUnity(lat: Double, lon: Double, bearing: Double, speed: Double) {
        let message = "\(lat),\(lon),\(bearing)"
        UnityBridge.shared.send("UpdatePlayerPositionFromString", value: message)

        lastSentLat = lat
        lastSentLon = lon
    }

    /// Haversine distance in meters (matches Kotlin Location.distanceBetween)
    private func distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    /// Calculate bearing in degrees (0-360). Same formula as Kotlin calculateBearing()
    private func calculateBearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let lonDiff = (lon2 - lon1) * .pi / 180

        let y = sin(lonDiff) * cos(lat2Rad)
        let x = cos(lat1Rad) * sin(lat2Rad) -
                sin(lat1Rad) * cos(lat2Rad) * cos(lonDiff)

        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Hex Discovery (Kotlin-side equivalent)

    /// Call backend /v1/game/hexes/explore directly from Swift.
    /// Works even when Unity is paused. Throttled to 1 call per 2 seconds.
    private func exploreAtLocation(lat: Double, lon: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastExploreTime) >= exploreThrottleInterval else { return }
        lastExploreTime = now

        guard let token = AuthManager.shared.getAccessToken() else {
            print("⚠️ LocationService: No auth token — skipping explore")
            return
        }

        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/game/hexes/explore") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = "{\"lat\":\(lat),\"lon\":\(lon)}".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ LocationService: Explore failed — \(error.localizedDescription)")
                return
            }
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse else { return }

            // AAA Force Logout: detect SESSION_REVOKED on game API calls
            if httpResponse.statusCode == 401 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = json["code"] as? String, code == "SESSION_REVOKED" {
                    let msg = json["message"] as? String ?? "Déconnexion forcée par l'administrateur."
                    print("🔒 LocationService: SESSION_REVOKED — forcing logout")
                    DispatchQueue.main.async {
                        HudOverlayManager.shared.performLogout(reason: msg)
                    }
                }
                return
            }

            guard httpResponse.statusCode == 200 else { return }

            DispatchQueue.main.async {
                if !self.firstExploreCompleted {
                    self.firstExploreCompleted = true
                    print("✅ LocationService: First explore completed — hex data ready")
                }
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newHexes = json["newHexes"] as? [[String: Any]] {
                let count = newHexes.count
                if count > 0 {
                    print("🔷 LocationService: Discovered \(count) new hexes!")
                }
            }
        }.resume()
    }
}
