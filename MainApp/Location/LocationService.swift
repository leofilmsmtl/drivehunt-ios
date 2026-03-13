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
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = LocationService()

    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Last sent coordinates (avoid spamming Unity with identical positions)
    private var lastSentLat: Double = 0
    private var lastSentLon: Double = 0

    /// Discovery throttling (max 1 explore call per 2 seconds, matches Android)
    private var lastExploreTime: Date = .distantPast
    private let exploreThrottleInterval: TimeInterval = 2.0

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
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

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
