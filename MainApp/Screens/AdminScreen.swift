import SwiftUI
import MapKit

/// Admin console screen — equivalent of Android's ModernAdminScreen.kt.
/// Tabbed interface: Simulator | Settings
struct AdminScreen: View {
    var onBack: () -> Void

    @State private var selectedTab: AdminTab = .simulator

    var body: some View {
        ZStack {
            Color(hex: "#121212").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("CONSOLE ADMIN")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                    Spacer()
                    Rectangle().fill(Color.clear).frame(width: 20, height: 20)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Tab Content
                switch selectedTab {
                case .simulator:
                    AdminSimulatorTab()
                case .settings:
                    AdminSettingsTab()
                }

                // Bottom Tab Bar
                AdminBottomBar(selectedTab: $selectedTab)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Tab Enum

enum AdminTab: CaseIterable {
    case simulator
    case settings

    var label: String {
        switch self {
        case .simulator: return "Sim"
        case .settings: return "Options"
        }
    }

    var icon: String {
        switch self {
        case .simulator: return "gamecontroller.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Bottom Bar

struct AdminBottomBar: View {
    @Binding var selectedTab: AdminTab

    var body: some View {
        HStack {
            ForEach(AdminTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.label)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(selectedTab == tab ? .white : Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 10)
        .background(Color(hex: "#1a1a1a"))
    }
}

// MARK: - Simulator Tab

struct AdminSimulatorTab: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.5019, longitude: -73.5674),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @State private var startPoint: CLLocationCoordinate2D? = nil
    @State private var endPoint: CLLocationCoordinate2D? = nil
    @State private var pickingMode: PickingMode = .none
    @State private var isRunning = false
    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var speedKmh: Double = 50
    @State private var annotations: [SimAnnotation] = []

    enum PickingMode {
        case none, start, end
    }

    var body: some View {
        ZStack {
            // Map
            SimulatorMapView(
                region: $region,
                annotations: $annotations,
                onTap: handleMapTap
            )
            .ignoresSafeArea(edges: .bottom)

            // Controls overlay
            VStack {
                // Control panel
                VStack(spacing: 10) {
                    Text("Simulation")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Buttons row
                    HStack(spacing: 8) {
                        SimButton(
                            text: "Départ",
                            isActive: pickingMode == .start,
                            color: Color(hex: "#FFB74D")
                        ) {
                            pickingMode = pickingMode == .start ? .none : .start
                        }

                        SimButton(
                            text: "Arrivée",
                            isActive: pickingMode == .end,
                            color: Color(hex: "#4DB6AC")
                        ) {
                            pickingMode = pickingMode == .end ? .none : .end
                        }

                        SimButton(
                            text: isRunning ? "Stop" : "Go",
                            isActive: isRunning,
                            color: isRunning ? Color(hex: "#E53935") : Color(hex: "#4CAF50")
                        ) {
                            if isRunning {
                                stopSimulation()
                            } else if startPoint != nil && endPoint != nil {
                                startSimulation()
                            }
                        }
                        .opacity(startPoint != nil && endPoint != nil || isRunning ? 1.0 : 0.4)
                    }

                    // Speed slider
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(Color(hex: "#00FFAA"))
                            .font(.system(size: 14))
                        Text("Vitesse")
                            .foregroundColor(.white)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(speedKmh)) km/h")
                            .foregroundColor(Color(hex: "#00FFAA"))
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                    }

                    Slider(value: $speedKmh, in: 10...120, step: 5)
                        .tint(Color(hex: "#00FFAA"))

                    // Use my position shortcut
                    Button {
                        useCurrentLocation()
                    } label: {
                        HStack {
                            Text("📍")
                            Text("Ma position → Départ")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#4CAF50").opacity(0.3))
                        .cornerRadius(8)
                    }

                    // Status
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#00FFAA"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .padding(12)
                .background(Color(hex: "#1a1a1a").opacity(0.95))
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.3), radius: 8)
                .padding(12)

                Spacer()

                // Picking mode indicator
                if pickingMode != .none {
                    Text(pickingMode == .start ? "Touchez la carte pour placer le DÉPART" : "Touchez la carte pour placer l'ARRIVÉE")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(pickingMode == .start ? Color(hex: "#FFB74D") : Color(hex: "#4DB6AC"))
                        .cornerRadius(20)
                        .shadow(radius: 4)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        switch pickingMode {
        case .start:
            startPoint = coordinate
            pickingMode = .none
            updateAnnotations()
            statusMessage = "Départ placé"
        case .end:
            endPoint = coordinate
            pickingMode = .none
            updateAnnotations()
            statusMessage = "Arrivée placée"
        case .none:
            break
        }
    }

    private func useCurrentLocation() {
        let locManager = CLLocationManager()
        if let loc = locManager.location {
            startPoint = loc.coordinate
            region = MKCoordinateRegion(
                center: loc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            updateAnnotations()
            statusMessage = "Départ = position actuelle"
        } else {
            statusMessage = "⚠️ Position GPS indisponible"
        }
    }

    private func updateAnnotations() {
        var newAnnotations: [SimAnnotation] = []
        if let start = startPoint {
            newAnnotations.append(SimAnnotation(coordinate: start, type: .start))
        }
        if let end = endPoint {
            newAnnotations.append(SimAnnotation(coordinate: end, type: .end))
        }
        annotations = newAnnotations
    }

    private func startSimulation() {
        guard let start = startPoint, let end = endPoint else { return }
        isLoading = true
        statusMessage = "⏳ Calcul de la route..."

        let baseUrl = "https://drivehunt.ngrok.app"
        guard let token = AuthManager.shared.getAccessToken() else {
            statusMessage = "❌ Non authentifié"
            isLoading = false
            return
        }

        // Step 1: Get route from backend
        let routeUrlStr = "\(baseUrl)/v1/admin/route?start=\(start.latitude),\(start.longitude)&end=\(end.latitude),\(end.longitude)"
        guard let routeUrl = URL(string: routeUrlStr) else { return }

        var routeReq = URLRequest(url: routeUrl)
        routeReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        routeReq.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: routeReq) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    statusMessage = "❌ \(error.localizedDescription)"
                    isLoading = false
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let coordinates = json["coordinates"] as? [[Double]] else {
                DispatchQueue.main.async {
                    statusMessage = "❌ Route invalide"
                    isLoading = false
                }
                return
            }

            // Step 2: Send route to simulation/start
            let route = coordinates.map { [$0[1], $0[0]] } // [lon,lat] → [lat,lon]
            let simBody: [String: Any] = [
                "route": route,
                "speedKmh": Int(speedKmh),
                "startPoint": ["lat": start.latitude, "lon": start.longitude],
                "endPoint": ["lat": end.latitude, "lon": end.longitude]
            ]

            guard let simUrl = URL(string: "\(baseUrl)/v1/dev/simulation/start") else { return }
            var simReq = URLRequest(url: simUrl)
            simReq.httpMethod = "POST"
            simReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            simReq.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
            simReq.httpBody = try? JSONSerialization.data(withJSONObject: simBody)

            URLSession.shared.dataTask(with: simReq) { _, simResp, simErr in
                DispatchQueue.main.async {
                    isLoading = false
                    if let httpResp = simResp as? HTTPURLResponse, httpResp.statusCode == 200 {
                        isRunning = true
                        statusMessage = "✅ Simulation démarrée (\(coordinates.count) points, \(Int(speedKmh)) km/h)"
                    } else {
                        statusMessage = "❌ Erreur simulation: \(simErr?.localizedDescription ?? "HTTP \((simResp as? HTTPURLResponse)?.statusCode ?? 0)")"
                    }
                }
            }.resume()
        }.resume()
    }

    private func stopSimulation() {
        let baseUrl = "https://drivehunt.ngrok.app"

        // Stop simulation
        if let url = URL(string: "\(baseUrl)/v1/dev/simulation/stop") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
            URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
        }

        // Also clear mock-location (legacy)
        if let url = URL(string: "\(baseUrl)/v1/dev/mock-location") {
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
            URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
        }

        isRunning = false
        statusMessage = "⏹️ Simulation arrêtée"
    }
}

// MARK: - Simulator Map (UIKit wrapper for tap gesture)

struct SimAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType

    enum AnnotationType {
        case start, end
    }
}

struct SimulatorMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [SimAnnotation]
    var onTap: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.mapType = .satellite

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update annotations
        mapView.removeAnnotations(mapView.annotations)
        for ann in annotations {
            let mkAnn = MKPointAnnotation()
            mkAnn.coordinate = ann.coordinate
            mkAnn.title = ann.type == .start ? "🟢 Départ" : "🔴 Arrivée"
            mapView.addAnnotation(mkAnn)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: SimulatorMapView

        init(_ parent: SimulatorMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTap(coordinate)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let id = "sim_pin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            if let marker = view as? MKMarkerAnnotationView {
                marker.markerTintColor = annotation.title == "🟢 Départ" ? .systemGreen : .systemRed
                marker.glyphText = annotation.title == "🟢 Départ" ? "A" : "B"
            }
            return view
        }
    }
}

// MARK: - Settings Tab

struct AdminSettingsTab: View {
    @State private var fogOpacity: Double = 100
    @State private var showMetrics = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Fog Toggle
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🌫️")
                        Text("Brouillard")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        Spacer()
                        Text(fogOpacity > 0 ? "ON" : "OFF")
                            .foregroundColor(fogOpacity > 0 ? Color(hex: "#4CAF50") : Color.gray)
                            .fontWeight(.bold)
                    }

                    Button {
                        let newVal: Double = fogOpacity > 0 ? 0 : 100
                        fogOpacity = newVal
                        let opacity = newVal == 100 ? "1" : "0"
                        UnityBridge.shared.send("SetFogOpacity", value: opacity)
                    } label: {
                        Text(fogOpacity > 0 ? "🌫️ Désactiver Brouillard" : "🌫️ Activer Brouillard")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(fogOpacity > 0 ? Color(hex: "#4CAF50") : Color.gray)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                // Fog Opacity Slider
                SettingSlider(
                    title: "Fog Opacity",
                    value: $fogOpacity,
                    range: 0...100,
                    unit: "%",
                    icon: "cloud.fog.fill"
                ) { newValue in
                    let opacity = newValue == 100 ? "1" : newValue == 0 ? "0" : String(format: "%.2f", newValue / 100.0)
                    UnityBridge.shared.send("SetFogOpacity", value: opacity)
                }

                // Debug Metrics Toggle
                Toggle(isOn: $showMetrics) {
                    Label("Show Debug Metrics", systemImage: "chart.bar.fill")
                        .foregroundColor(.white)
                }
                .tint(Color(hex: "#00FFAA"))
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .onChange(of: showMetrics) { newValue in
                    UnityBridge.shared.send("SetShowMetrics", value: newValue ? "1" : "0")
                }

                // Debug Tools Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔧 Outils Debug")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.gray)

                    Button {
                        UnityBridge.shared.send("export_logs", value: "")
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("📋 Exporter Logs Unity")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#78909C"))
                        .cornerRadius(10)
                    }

                    Button {
                        UnityBridge.shared.send("start_benchmark", value: "")
                    } label: {
                        HStack {
                            Image(systemName: "gauge")
                            Text("📊 Start Benchmark")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#4CAF50"))
                        .cornerRadius(10)
                    }

                    Button {
                        UnityBridge.shared.send("stop_benchmark", value: "")
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("📊 Stop + Export Benchmark")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#E53935"))
                        .cornerRadius(10)
                    }

                    // Loot Reset
                    LootResetButton()
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

// MARK: - Loot Reset Button

struct LootResetButton: View {
    @State private var isResetting = false
    @State private var status = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isResetting = true
                status = "⏳ Reset en cours..."

                let baseUrl = "https://drivehunt.ngrok.app"
                guard let url = URL(string: "\(baseUrl)/v1/admin/loot/respawn") else { return }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
                req.httpBody = "{}".data(using: .utf8)

                URLSession.shared.dataTask(with: req) { _, response, error in
                    DispatchQueue.main.async {
                        isResetting = false
                        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                            status = "✅ Loot reset! Les gems vont apparaître au prochain sync."
                        } else {
                            status = "❌ Erreur: \(error?.localizedDescription ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")"
                        }
                    }
                }.resume()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("🔄 Reset & Repopulate Loot")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "#FF9800"))
                .cornerRadius(10)
            }
            .disabled(isResetting)

            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Sim Button Component

struct SimButton: View {
    let text: String
    var isActive: Bool = false
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isActive ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isActive ? color : color.opacity(0.15))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        }
    }
}

// MARK: - Setting Slider Component

struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let icon: String
    var onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "#00FFAA"))
                Text(title)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(value))\(unit)")
                    .foregroundColor(Color(hex: "#00FFAA"))
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range, step: 1)
                .tint(Color(hex: "#00FFAA"))
                .onChange(of: value) { newValue in
                    onChange(newValue)
                }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
