//  ContentView.swift
//  Rapidual - App
//
//  Created by Thomas Peters on 11/16/25.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit
import Combine

// MARK: - Theme

private enum AppTheme {
    static let brandBlue = Color(hue: 215/360, saturation: 0.75, brightness: 0.55)
    static let deepBlue = Color(hue: 226/360, saturation: 0.74, brightness: 0.32)
    static let success = Color(hue: 150/360, saturation: 0.60, brightness: 0.60)
    static let warning = Color(hue: 38/360, saturation: 0.85, brightness: 0.95)
    static let softBG = Color(uiColor: .systemGroupedBackground)
    static let cardBG = Color(uiColor: .secondarySystemGroupedBackground)
    static let shadow = Color.black.opacity(0.08)

    static let cornerLarge: CGFloat = 22
    static let corner: CGFloat = 16
    static let cornerSmall: CGFloat = 12
}

// MARK: - Location / Availability

struct ServiceArea: Identifiable {
    let id = UUID()
    let name: String
    let center: CLLocationCoordinate2D
    let radius: CLLocationDistance // meters

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let there = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return there.distance(from: here) <= radius
    }

    // Only available in these California cities
    static let defaultAreas: [ServiceArea] = [
        .init(name: "Newport Beach, CA",
              center: CLLocationCoordinate2D(latitude: 33.6189, longitude: -117.9298),
              radius: 11_000),
        .init(name: "Huntington Beach, CA",
              center: CLLocationCoordinate2D(latitude: 33.6603, longitude: -117.9992),
              radius: 12_000),
        .init(name: "Irvine, CA",
              center: CLLocationCoordinate2D(latitude: 33.6846, longitude: -117.8265),
              radius: 13_000),
        .init(name: "Costa Mesa, CA",
              center: CLLocationCoordinate2D(latitude: 33.6411, longitude: -117.9187),
              radius: 7_000),
        .init(name: "Tustin, CA",
              center: CLLocationCoordinate2D(latitude: 33.7458, longitude: -117.8262),
              radius: 6_000),
        .init(name: "Fountain Valley, CA",
              center: CLLocationCoordinate2D(latitude: 33.7090, longitude: -117.9537),
              radius: 6_000)
    ]
}

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Status {
        case notDetermined, denied, restricted, authorized
    }

    @Published var status: Status = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var isInServiceArea: Bool?
    @Published var placemark: CLPlacemark?

    private let manager = CLLocationManager()
    private let serviceAreas: [ServiceArea]
    private let geocoder = CLGeocoder()

    override init() {
        self.serviceAreas = ServiceArea.defaultAreas
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func refreshLocation() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorization(manager.authorizationStatus)
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            refreshLocation()
        default:
            break
        }
    }

    private func updateAuthorization(_ clStatus: CLAuthorizationStatus) {
        switch clStatus {
        case .notDetermined: status = .notDetermined
        case .restricted:    status = .restricted
        case .denied:        status = .denied
        case .authorizedAlways, .authorizedWhenInUse: status = .authorized
        @unknown default:    status = .notDetermined
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        isInServiceArea = serviceAreas.contains { $0.contains(loc.coordinate) }

        // Reverse geocode using Core Location (works across all supported iOS versions).
        reverseGeocode(location: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }

    // MARK: - Reverse Geocoding (Core Location)
    private func reverseGeocode(location: CLLocation) {
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self = self, let pm = placemarks?.first else { return }
            Task { @MainActor in
                self.placemark = pm
            }
        }
    }
}

// MARK: - Root with Mode Switch

struct ContentView: View {
    @State private var appMode: AppMode = .user

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    ModeSwitcher(appMode: $appMode)
                    Spacer()
                }

                if appMode == .user {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome Back, User!")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppTheme.brandBlue)
                        Text("Ready for your next order?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)

            Group {
                switch appMode {
                case .user:
                    CustomerMainTabView()
                case .driver:
                    DriverMainTabView()
                }
            }
        }
    }
}

enum AppMode: String, CaseIterable, Identifiable {
    case user = "User"
    case driver = "Driver"
    var id: String { rawValue }
}

struct ModeSwitcher: View {
    @Binding var appMode: AppMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppMode.allCases) { mode in
                Button {
                    appMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.caption).bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(appMode == mode ? Color.accentColor.opacity(0.2) : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .overlay(
                    Capsule()
                        .stroke(appMode == mode ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    ContentView()
}

// MARK: - CUSTOMER EXPERIENCE

struct CustomerMainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CustomerHomeView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }

            NavigationStack {
                CustomerOrdersView()
            }
            .tabItem {
                Image(systemName: "waveform.path.ecg")
                Text("Activity")
            }

            NavigationStack {
                CustomerExploreView()
            }
            .tabItem {
                Image(systemName: "building.2.fill")
                Text("Retail")
            }

            NavigationStack {
                SupportTicketsView()
            }
            .tabItem {
                Image(systemName: "questionmark.circle.fill")
                Text("Support")
            }

            NavigationStack {
                CustomerAccountView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle.fill")
                Text("Account")
            }
        }
        .tint(.primary)
    }
}

// MARK: - Customer Home

struct CustomerHomeView: View {
    @StateObject private var locationService = LocationService()

    @State private var bagCount: Int = 1
    @State private var estimatedCost: Double = 7
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var phoneNumber: String = ""
    @State private var searchTextHome: String = ""

    @State private var pickupMode: PickupMode = .asap
    @State private var scheduledDate: Date = Date()

    enum PickupMode: String, CaseIterable {
        case asap = "ASAP"
        case later = "Later"
    }

    // Names-only tiles with additional row
    private var retailerNames: [String] {
        [
            "Walmart", "Target", "Costco", "Home Depot",
            "Best Buy", "Kohl's", "Walgreens", "Bed Bath",
            "Lowe's", "CVS", "Nordstrom", "Trader Joes"
        ]
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    private var pickupWindowText: String {
        switch pickupMode {
        case .asap:
            return "25–35 min"
        case .later:
            let fmt = DateFormatter()
            fmt.dateFormat = "EEE h:mm a"
            return fmt.string(from: scheduledDate)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                homeHeroHeader

                quickActionsChips

                laundryHeroCard

                popularRetailersRow

                personalizedSection

                savingsGrid
                savingsSummaryPair

                footerSignupCentered
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(AppTheme.softBG.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            switch locationService.status {
            case .notDetermined:
                locationService.requestAuthorization()
            case .authorized:
                locationService.refreshLocation()
            case .denied, .restricted:
                break
            }
        }
    }

    // MARK: - Modernized Header

    private var homeHeroHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(greeting)
                    .font(.title2.weight(.heavy))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    // Could open settings or preferences
                } label: {
                    Image(systemName: "bell")
                        .foregroundColor(.white.opacity(0.9))
                        .padding(8)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.white.opacity(0.9))
                Group {
                    switch locationService.status {
                    case .authorized:
                        if let city = locationService.placemark?.locality {
                            Text("Delivering to \(city)")
                        } else {
                            Text("Locating…")
                                .redacted(reason: .placeholder)
                        }
                    case .notDetermined:
                        Text("Enable location to set your address")
                    case .denied, .restricted:
                        Text("Enable Location in Settings")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.95))
                Spacer()
                availabilityStatusSmall
            }

            SearchBarLarge(text: $searchTextHome, placeholder: "Search retailers, items, or help")
        }
        .padding(16)
        .background(
            LinearGradient(colors: [AppTheme.brandBlue, AppTheme.deepBlue],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
        )
        .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 6)
    }

    private var availabilityStatusSmall: some View {
        Group {
            switch locationService.status {
            case .notDetermined:
                Pill(background: Color.white.opacity(0.15)) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                        Text("Enable")
                            .foregroundColor(.white)
                            .font(.caption).bold()
                    }
                }
                .onTapGesture { locationService.requestAuthorization() }
            case .restricted, .denied:
                Pill(background: Color.white.opacity(0.15)) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Off")
                            .foregroundColor(.white)
                            .font(.caption).bold()
                    }
                }
            case .authorized:
                if let isIn = locationService.isInServiceArea {
                    if isIn {
                        Pill(background: Color.white.opacity(0.15)) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                                Text("Available").foregroundColor(.white).font(.caption).bold()
                            }
                        }
                    } else {
                        Pill(background: Color.white.opacity(0.15)) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.white)
                                Text("Coming soon").foregroundColor(.white).font(.caption).bold()
                            }
                        }
                    }
                } else {
                    Pill(background: Color.white.opacity(0.15)) {
                        HStack(spacing: 6) {
                            ProgressView().tint(.white)
                            Text("Checking").foregroundColor(.white).font(.caption).bold()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Availability Pill (kept, not displayed in header anymore)

    private var availabilityPill: some View {
        Pill(background: .white, content: {
            HStack(spacing: 8) {
                switch locationService.status {
                case .notDetermined:
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Enable Location to check availability")
                        .foregroundColor(.primary)
                        .font(.subheadline).bold()
                    Spacer()
                    Button("Enable") {
                        locationService.requestAuthorization()
                    }
                    .font(.footnote).bold()

                case .restricted, .denied:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Allow Location in Settings to check availability")
                        .foregroundColor(.orange)
                        .font(.subheadline).bold()
                    Spacer()
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.footnote).bold()

                case .authorized:
                    if let isIn = locationService.isInServiceArea {
                        if isIn {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.success)
                            Text("Available in your area now!")
                                .foregroundColor(AppTheme.success)
                                .font(.subheadline).bold()
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Coming soon to your area")
                                .foregroundColor(.red)
                                .font(.subheadline).bold()
                        }
                    } else {
                        ProgressView().scaleEffect(0.9)
                        Text("Checking availability near you…")
                            .foregroundColor(.secondary)
                            .font(.subheadline).bold()
                    }
                }
            }
            .padding(.horizontal, 4)
        })
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }

    // MARK: - Hero Order Card (refined)

    private var laundryHeroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                // Gradient header
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: "washer").foregroundColor(.white))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Laundry: On Demand")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Pickup & redelivery that fits your day")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    LinearGradient(colors: [AppTheme.brandBlue, AppTheme.deepBlue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                )

                // Mode: ASAP vs Later
                PickupModeSwitcher(mode: $pickupMode)

                if pickupMode == .later {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        DatePicker("Pickup time", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous))
                }

                // Centered "How Many Bags" block
                VStack(spacing: 10) {
                    Text("How many bags?")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        StepperCircle(symbol: "minus", enabled: bagCount > 1) {
                            if bagCount > 1 { bagCount -= 1; updateEstimate() }
                        }

                        VStack(spacing: 2) {
                            Text("\(bagCount)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppTheme.success)
                            Text("bag\(bagCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                                .stroke(AppTheme.success, lineWidth: 2)
                        )

                        StepperCircle(symbol: "plus", enabled: true) {
                            bagCount += 1; updateEstimate()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

                // ETA + Cost
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("Pickup \(pickupMode == .asap ? "ETA" : "at") \(pickupWindowText)")
                            .foregroundColor(.primary)
                            .font(.subheadline)
                    }
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous))
                    .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)

                    Spacer()

                    HStack {
                        Text("Est.")
                            .foregroundColor(.secondary)
                        Text("$\(Int(estimatedCost))")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous))
                    .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
                }

                ZStack(alignment: .topTrailing) {
                    Button {
                        // Start order flow
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bag.fill")
                            Text("Start Order")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [AppTheme.deepBlue, AppTheme.brandBlue],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)

                    Text(pickupMode == .asap ? "ASAP" : "SCHEDULED")
                        .font(.caption2).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange, in: Capsule())
                        .offset(x: -6, y: -10)
                }

                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Need Laundry Bags?")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button("Order Here") {}.font(.footnote).bold()
                        Image(systemName: "arrow.up.right.square").font(.footnote)
                    }
                    Text("They're Free! 🎁")
                        .font(.footnote).bold()
                        .foregroundColor(AppTheme.success)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Quick Actions (chips)

    private var quickActionsChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ActionChip(icon: "location.viewfinder", title: "Track Order")
                ActionChip(icon: "bubble.left.and.bubble.right.fill", title: "Chat Support", tint: .green)
                ActionChip(icon: "creditcard.fill", title: "Quick Pay", tint: .purple)
                ActionChip(icon: "bell.fill", title: "Notifications", tint: .orange)
                ActionChip(icon: "tag.fill", title: "Promos", tint: .pink)
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Popular Retailers

    private var popularRetailersRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Popular near you")
                    .font(.headline)
                Spacer()
                Button("See all") { }
                    .font(.caption).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.08), in: Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(retailerNames, id: \.self) { name in
                        PopularRetailerChip(name: name, tint: brandTint(for: name))
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Personalized

    private var personalizedSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(icon: "sparkles", title: "Personalized for You",
                                  subtitle: "AI-powered recommendations based on your preferences")
                    Spacer()
                    Button("See all") { }
                        .font(.caption).bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.08), in: Capsule())
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        RecommendationCard(
                            icon: "cube.box.fill", iconTint: AppTheme.brandBlue,
                            title: "Try 3 Bags",
                            detail: "Based on your history, you might need an extra bag",
                            badge: ("Save $2 per bag", .green),
                            confidence: 0.85
                        )
                        RecommendationCard(
                            icon: "clock.fill", iconTint: .green,
                            title: "Book Afternoon (12PM–5PM)",
                            detail: "Your usual preferred time slot",
                            badge: ("On-time guarantee", .blue),
                            confidence: 0.92
                        )
                    }
                    .padding(.vertical, 4)
                }

                Divider().padding(.vertical, 4)

                HStack {
                    StatTile(value: "8", label: "Orders")
                    StatTile(value: "2", label: "Avg Bags")
                    StatTile(value: "2", label: "Retailers")
                }
            }
        }
    }

    // MARK: - Retail accounts

    private var linkRetailAccounts: some View {
        Card {
            VStack(spacing: 12) {
                // Centered header
                VStack(spacing: 2) {
                    Text("Link Your Retail Accounts")
                        .font(.headline)
                    Text("For Rapid Free Delivery")
                        .font(.subheadline).bold()
                        .foregroundColor(AppTheme.success)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                Divider()

                Text("Available in your area now!")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                // Names-only tiles, centered, keep brand colors (no icons)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(retailerNames, id: \.self) { name in
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(colors: [brandTint(for: name).opacity(0.12),
                                                        brandTint(for: name).opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(height: 64)
                            .overlay(
                                Text(name)
                                    .font(.caption).bold()
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 6)
                            )
                            .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func brandTint(for name: String) -> Color {
        switch name {
        case "Target", "CVS", "Trader Joes": return .red
        case "Walmart": return .blue
        case "Lowe's": return .blue
        case "Best Buy": return .indigo
        case "Home Depot": return .orange
        case "Kohl's": return .brown
        case "Walgreens": return .red
        case "Bed Bath": return .teal
        case "Costco": return .gray
        case "Nordstrom": return .gray
        default: return AppTheme.brandBlue
        }
    }

    // MARK: - Sustainability

    private var savingsGrid: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Sustainability & Cost Savings", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(AppTheme.success)
                        .font(.subheadline).bold()
                    Spacer()
                }
                .padding(10)
                .background(AppTheme.success.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    SavingsMetricCard(value: "19", unit: "Gallons", tint: .blue, icon: "drop.fill")
                    SavingsMetricCard(value: "3", unit: "Kilowatts", tint: .orange, icon: "bolt.fill")
                    SavingsMetricCard(value: "4", unit: "Pounds CO2", tint: .green, icon: "leaf.fill")
                    SavingsMetricCard(value: "24", unit: "Minutes", tint: .purple, icon: "clock.fill")
                }

                Text("Tap any card to learn how we calculate savings")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }

    private var savingsSummaryPair: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: AppTheme.cornerLarge)
                .fill(AppTheme.success)
                .frame(height: 120)
                .overlay(
                    VStack(spacing: 4) {
                        Text("Total Cost Savings").font(.subheadline).bold().foregroundColor(.white)
                        Text("$5.60").font(.system(size: 36, weight: .heavy)).foregroundColor(.white)
                        Text("your utility, environmental & time value")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding()
                )

            RoundedRectangle(cornerRadius: AppTheme.cornerLarge)
                .fill(AppTheme.deepBlue)
                .frame(height: 120)
                .overlay(
                    VStack(spacing: 6) {
                        Text("Real Order Price").font(.subheadline).bold().foregroundColor(.white)
                        Text("$1.40").font(.system(size: 36, weight: .heavy)).foregroundColor(.white)
                        Button("Add Promo Code") { }
                            .font(.caption).bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15), in: Capsule())
                            .foregroundColor(.white)
                    }
                    .padding()
                )
        }
    }

    // MARK: - Footer (centered signup)

    private var footerSignupCentered: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                Text("Keep up to date on service\ncoming to your area")
                    .font(.title3).bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.secondary)
                    TextField("Enter your mobile number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .foregroundColor(.primary)

                    Button {
                        // Handle notify action
                    } label: {
                        Text("Notify Me")
                            .font(.subheadline).bold()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black, in: Capsule())
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: 420) // keep centered and compact
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Color.black, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
        }
    }

    private func updateEstimate() {
        estimatedCost = Double(7 + max(0, bagCount - 1) * 6)
    }
}

// MARK: - Reusable UI Pieces (Customer)

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 6)
    }
}

private struct Pill<Content: View>: View {
    var background: Color = .white
    @ViewBuilder var content: Content
    var body: some View {
        HStack { content }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(background, in: Capsule())
    }
}

private struct StepperCircle: View {
    let symbol: String
    var enabled: Bool = true
    var action: () -> Void
    var body: some View {
        Button(action: { if enabled { action() } }) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundColor(enabled ? .primary : Color.secondary.opacity(0.5))
                .frame(width: 44, height: 44)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct QuickAction: View {
    var icon: String
    var title: String
    var tint: Color = AppTheme.brandBlue

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .padding(10)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title).font(.caption).foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

private struct ActionChip: View {
    var icon: String
    var title: String
    var tint: Color = AppTheme.brandBlue

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 3)
    }
}

private struct SectionHeader: View {
    var icon: String
    var title: String
    var subtitle: String?
    var body: some View {
        HStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.purple.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).foregroundColor(.purple))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundColor(.secondary) }
            }
            Spacer()
        }
    }
}

private struct RecommendationCard: View {
    var icon: String
    var iconTint: Color
    var title: String
    var detail: String
    var badge: (text: String, color: Color)?
    var confidence: CGFloat // 0...1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconTint.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(Image(systemName: icon).foregroundColor(iconTint))
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text("\(Int(confidence * 100))%")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Text(title).font(.subheadline).bold()
            Text(detail).font(.caption).foregroundColor(.secondary).lineLimit(2)

            if let badge {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(badge.color)
                    Text(badge.text).font(.caption).foregroundColor(badge.color)
                }
                .padding(8)
                .background(badge.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Spacer(minLength: 0)

            ProgressLine(progress: 0.85, tint: iconTint)
        }
        .padding(12)
        .frame(width: 220, height: 150)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

private struct ProgressLine: View {
    var progress: CGFloat
    var tint: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 4)
                Capsule().fill(tint).frame(width: max(0, progress) * geo.size.width, height: 4)
            }
        }
        .frame(height: 4)
    }
}

private struct StatTile: View {
    var value: String
    var label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SavingsMetricCard: View {
    var value: String
    var unit: String
    var tint: Color
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(colors: [tint.opacity(0.20), tint.opacity(0.10)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: icon).foregroundColor(tint))
                Spacer()
            }
            Text(value).font(.title2).bold()
            Text(unit).font(.caption).foregroundColor(.secondary)
            ProgressLine(progress: 0.6, tint: tint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

// MARK: - Extra Customer Home Helpers

private struct SearchBarLarge: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct PickupModeSwitcher: View {
    @Binding var mode: CustomerHomeView.PickupMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CustomerHomeView.PickupMode.allCases, id: \.self) { option in
                Button {
                    mode = option
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(mode == option ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(mode == option ? Color.black : Color.clear, in: Capsule())
                        .overlay(
                            Capsule().stroke(mode == option ? Color.black : Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PopularRetailerChip: View {
    let name: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "bag.fill").foregroundColor(tint))
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 3)
    }
}

// MARK: - Customer Orders (Activity content)

struct CustomerOrdersView: View {
    struct Order: Identifiable {
        let id: Int
        let title: String
        let status: Status
        let date: String
        let bags: Int
        let eta: String?
        let tint: Color
        enum Status: String {
            case inProgress = "In Progress"
            case scheduled = "Scheduled"
            case delivered = "Delivered"
            case canceled = "Canceled"
        }
    }

    @State private var segment: Segment = .active
    @State private var search: String = ""
    @State private var showFilters: Bool = false

    enum Segment: String, CaseIterable, Identifiable {
        case active = "Active"
        case scheduled = "Scheduled"
        case completed = "Completed"
        var id: String { rawValue }
    }

    @State private var orders: [Order] = [
        .init(id: 1, title: "WasHQ", status: .inProgress, date: "Today", bags: 2, eta: "35–45m", tint: .blue),
        .init(id: 2, title: "Quick Cleaners", status: .delivered, date: "Yesterday", bags: 1, eta: nil, tint: .green),
        .init(id: 3, title: "Eco Wash", status: .scheduled, date: "Mon 10:00 AM", bags: 3, eta: "10:00 AM", tint: .orange)
    ]

    private var filtered: [Order] {
        orders.filter { order in
            switch segment {
            case .active:
                return order.status == .inProgress
            case .scheduled:
                return order.status == .scheduled
            case .completed:
                return order.status == .delivered || order.status == .canceled
            }
        }
        .filter { order in
            let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return true }
            return order.title.localizedCaseInsensitiveContains(q)
            || order.status.rawValue.localizedCaseInsensitiveContains(q)
            || order.date.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSummary

                segmentControl

                searchBar

                if segment == .active && !filtered.isEmpty {
                    HStack {
                        Text("Order in Progress")
                            .font(.title3).bold()
                        Spacer()
                    }
                }

                if filtered.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(filtered) { order in
                            NavigationLink {
                                CustomerOrderDetailView(order: order)
                            } label: {
                                if order.status == .inProgress {
                                    InProgressOrderCard(order: order)
                                } else {
                                    OrderCard(order: order)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(AppTheme.softBG.ignoresSafeArea())
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Filters")
            }
        }
    }

    private var headerSummary: some View {
        HStack(spacing: 12) {
            SummaryTile(icon: "bag.fill", title: "Orders", value: "\(orders.count)", tint: .blue)
            SummaryTile(icon: "scalemass.fill", title: "Bags", value: "\(orders.reduce(0) { $0 + $1.bags })", tint: .purple)
            SummaryTile(icon: "banknote.fill", title: "Saved", value: "$12.40", tint: .green)
        }
    }

    private var segmentControl: some View {
        HStack(spacing: 8) {
            ForEach(Segment.allCases) { seg in
                Button {
                    segment = seg
                } label: {
                    Text(seg.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(segment == seg ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(segment == seg ? Color.black : Color.clear, in: Capsule())
                        .overlay(
                            Capsule().stroke(segment == seg ? Color.black : Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search orders…", text: $search)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Nothing here yet")
                .font(.headline)
            Text("When you have \(segment.rawValue.lowercased()) orders, they’ll appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Subviews

    private struct SummaryTile: View {
        let icon: String
        let title: String
        let value: String
        let tint: Color
        var body: some View {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: icon).foregroundColor(tint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundColor(.secondary)
                    Text(value).font(.headline)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private struct OrderCard: View {
        let order: Order

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(order.tint.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "bag.fill").foregroundColor(order.tint))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(order.title).font(.headline)
                            Spacer()
                            statusBadge
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "calendar").foregroundColor(.secondary)
                            Text(order.date).foregroundColor(.secondary)
                            if let eta = order.eta, order.status == .inProgress || order.status == .scheduled {
                                Circle().fill(Color.secondary.opacity(0.35)).frame(width: 4, height: 4)
                                Image(systemName: "clock").foregroundColor(.secondary)
                                Text(eta).foregroundColor(.secondary)
                            }
                        }
                        .font(.caption)

                        HStack(spacing: 8) {
                            TagPill(text: "\(order.bags) bag\(order.bags == 1 ? "" : "s")")
                            if order.status == .inProgress { TagPill(text: "On the way") }
                            if order.status == .scheduled { TagPill(text: "Scheduled") }
                        }

                        if order.status == .inProgress {
                            ProgressLine(progress: 0.55, tint: order.tint)
                                .padding(.top, 4)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        // Track
                    } label: {
                        Label("Track", systemImage: "location.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        // Support
                    } label: {
                        Label("Support", systemImage: "bubble.left.and.bubble.right.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        // Reorder
                    } label: {
                        Label("Reorder", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline)
                .padding(.top, 2)
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
        }

        private var statusBadge: some View {
            switch order.status {
            case .inProgress:
                return AnyView(BadgePill(text: "In Progress", tint: .blue))
            case .scheduled:
                return AnyView(BadgePill(text: "Scheduled", tint: .orange))
            case .delivered:
                return AnyView(BadgePill(text: "Delivered", tint: .green))
            case .canceled:
                return AnyView(BadgePill(text: "Canceled", tint: .red))
            }
        }
    }

    // MARK: - Rich card for the active order (like your screenshot)

    private struct InProgressOrderCard: View {
        let order: Order

        private let steps: [Step] = [
            .init(title: "Order Placed", time: "1:30 PM", state: .done),
            .init(title: "Driver Assigned", time: "1:45 PM", state: .done),
            .init(title: "Pickup Complete", time: "2:00 PM", state: .done),
            .init(title: "Washing", time: "2:15 PM", state: .current),
            .init(title: "Drying", time: "2:45 PM", state: .next),
            .init(title: "Folding", time: "3:15 PM", state: .next),
            .init(title: "Out for Delivery", time: "3:30 PM", state: .next),
            .init(title: "Delivered", time: "4:00 PM", state: .next)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Laundry Pickup")
                        .font(.headline)
                    BadgePill(text: order.title, tint: order.tint)
                    Spacer()
                    Text("15 min remaining")
                        .font(.footnote).bold()
                        .foregroundColor(.orange)
                }

                HStack(spacing: 8) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("Washing")
                        .font(.subheadline).bold()
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 8) {
                    InfoRowSmall(icon: "mappin.and.ellipse", text: "123 Main St, Irvine, CA")
                    InfoRowSmall(icon: "cube.box.fill", text: "\(order.bags) bag\(order.bags == 1 ? "" : "s")")
                    InfoRowSmall(icon: "clock", text: "Picked up at 2:15 PM")
                }

                Divider()

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Driver: Mike Johnson")
                            .font(.subheadline).bold()
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").foregroundColor(.orange)
                            Text("4.9").foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        SoftActionCapsule(icon: "location.viewfinder", title: "Track", tint: .blue)
                        SoftActionCapsule(icon: "bubble.left.and.bubble.right.fill", title: "Chat", tint: .green)
                        SoftActionCapsule(icon: "star", title: "Rate", tint: .orange)
                    }
                }

                Divider()

                Text("Order Progress")
                    .font(.headline)

                VStack(spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        ProgressTimelineRow(step: step, isLast: index == steps.count - 1)
                    }
                }
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
        }

        // MARK: - Subviews for the in-progress card

        private struct InfoRowSmall: View {
            let icon: String
            let text: String
            var body: some View {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundColor(.secondary)
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
        }

        private struct SoftActionCapsule: View {
            let icon: String
            let title: String
            let tint: Color
            var body: some View {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundColor(tint)
                    Text(title)
                        .font(.caption).bold()
                        .foregroundColor(tint)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tint.opacity(0.12), in: Capsule())
            }
        }

        private struct ProgressTimelineRow: View {
            let step: Step
            let isLast: Bool
            var body: some View {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 4) {
                        bullet
                        if !isLast {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 2, height: 24)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.subheadline)
                            .fontWeight(step.state == .current ? .semibold : .regular)
                            .foregroundColor(step.state == .current ? .blue : .primary)
                        Text(step.time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }

            private var bullet: some View {
                Group {
                    switch step.state {
                    case .done:
                        ZStack {
                            Circle().fill(Color.green).frame(width: 16, height: 16)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                    case .current:
                        ZStack {
                            Circle().stroke(Color.blue, lineWidth: 3).frame(width: 16, height: 16)
                            Circle().fill(Color.blue).frame(width: 6, height: 6)
                        }
                    case .next:
                        Circle().fill(Color.secondary.opacity(0.25)).frame(width: 16, height: 16)
                    }
                }
            }
        }

        private struct Step: Identifiable {
            let id = UUID()
            let title: String
            let time: String
            let state: State
            enum State { case done, current, next }
        }
    }
}

struct CustomerOrderDetailView: View {
    let order: CustomerOrdersView.Order

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                header

                mapPreview

                timeline

                actions
            }
            .padding(16)
        }
        .background(AppTheme.softBG.ignoresSafeArea())
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.title)
                    .font(.title3).bold()
                Spacer()
                statusBadge
            }
            HStack(spacing: 8) {
                Image(systemName: "calendar").foregroundColor(.secondary)
                Text(order.date).foregroundColor(.secondary)
            }
            .font(.caption)

            HStack(spacing: 8) {
                TagPill(text: "\(order.bags) bag\(order.bags == 1 ? "" : "s")")
                TagPill(text: "0.8 mi")
                TagPill(text: "ETA \(order.eta ?? "—")")
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }

    private var mapPreview: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(uiColor: .secondarySystemBackground))
            .frame(height: 160)
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "map.fill").foregroundColor(.secondary)
                    Text("Live map tracking")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            )
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                TimelineRow(title: "Order Placed", time: "2:05 PM", active: true)
                TimelineRow(title: "Picked Up", time: "2:28 PM", active: true)
                TimelineRow(title: "In Wash", time: "—", active: order.status == .inProgress)
                TimelineRow(title: "En Route", time: "—", active: false)
                TimelineRow(title: "Delivered", time: "—", active: false)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                // Track
            } label: {
                Label("Track", systemImage: "location.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                // Support
            } label: {
                Label("Contact Support", systemImage: "bubble.left.and.bubble.right.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                // Reorder
            } label: {
                Label("Reorder", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 2)
    }

    private var statusBadge: some View {
        switch order.status {
        case .inProgress:
            return AnyView(BadgePill(text: "In Progress", tint: .blue))
        case .scheduled:
            return AnyView(BadgePill(text: "Scheduled", tint: .orange))
        case .delivered:
            return AnyView(BadgePill(text: "Delivered", tint: .green))
        case .canceled:
            return AnyView(BadgePill(text: "Canceled", tint: .red))
        }
    }

    private struct TimelineRow: View {
        let title: String
        let time: String
        let active: Bool
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                VStack {
                    Circle()
                        .fill(active ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 2, height: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.subheadline).bold()
                        if active {
                            PillLabel(text: "Active", color: .blue)
                        }
                    }
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Retail (formerly Explore)

struct CustomerExploreView: View {

    // MARK: - Models
    struct FeaturedDeal: Identifiable {
        let id = UUID()
        let brand: String
        let headline: String
        let subheadline: String
        let tint: Color
    }

    struct RetailerItem: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let tags: [String]
        let rating: Double
        let perkText: String
        let etaText: String
        let freeDelivery: Bool
        let logoTint: Color
        let categories: [String]
    }

    // MARK: - State
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"

    // MARK: - Data
    private let categories: [(title: String, icon: String)] = [
        ("All", "square.grid.2x2.fill"),
        ("Grocery", "cart.fill"),
        ("Retail", "bag.fill"),
        ("Electronics", "desktopcomputer"),
        ("Home", "house.fill"),
        ("Fashion", "tshirt.fill"),
        ("Wholesale", "shippingbox.fill")
    ]

    private let deals: [FeaturedDeal] = [
        .init(brand: "Target Circle 360",
              headline: "Free delivery on all orders",
              subheadline: "100% off delivery",
              tint: .red),
        .init(brand: "Walmart+",
              headline: "Same-day grocery delivery",
              subheadline: "Free on $35+",
              tint: .blue),
        .init(brand: "Best Buy",
              headline: "Tech deals & member pricing",
              subheadline: "Up to 20% off",
              tint: .blue)
    ]

    private let retailers: [RetailerItem] = [
        .init(name: "Walmart+",
              description: "Groceries, household essentials, and everyday items with free delivery on orders $35+",
              tags: ["Free Delivery", "Same Day", "Grocery"],
              rating: 4.2,
              perkText: "Up to 5% back",
              etaText: "2–3 hours",
              freeDelivery: true,
              logoTint: .blue,
              categories: ["Grocery", "Retail"]),
        .init(name: "Target Circle 360",
              description: "Fashion, electronics, home goods, and beauty products with unlimited free delivery",
              tags: ["Free Delivery", "Express", "Fashion"],
              rating: 4.5,
              perkText: "Up to 10% off",
              etaText: "1–2 hours",
              freeDelivery: true,
              logoTint: .red,
              categories: ["Retail", "Fashion", "Electronics", "Home"]),
        .init(name: "Costco",
              description: "Bulk items, fresh produce, and warehouse deals with member pricing",
              tags: ["Bulk Items", "Member Prices", "Fresh Food"],
              rating: 4.7,
              perkText: "Member pricing",
              etaText: "3–5 hours",
              freeDelivery: false,
              logoTint: .gray,
              categories: ["Grocery", "Wholesale"]),
        .init(name: "Home Depot",
              description: "Home improvement, tools, garden supplies, and building materials",
              tags: ["Tools", "Garden", "Building"],
              rating: 4.3,
              perkText: "Pro discounts",
              etaText: "4–6 hours",
              freeDelivery: false,
              logoTint: .orange,
              categories: ["Home"]),
        .init(name: "Best Buy",
              description: "Electronics, computers, phones, and tech accessories with expert support",
              tags: ["Electronics", "Tech Support", "Same Day"],
              rating: 4.4,
              perkText: "Member deals",
              etaText: "2–4 hours",
              freeDelivery: true,
              logoTint: .indigo,
              categories: ["Electronics", "Retail"]),
        .init(name: "Kohls",
              description: "Fashion, home decor, and lifestyle products with Kohl's Cash rewards",
              tags: ["Fashion", "Home Decor", "Kohl's Cash"],
              rating: 4.1,
              perkText: "Kohl's Cash back",
              etaText: "1–3 days",
              freeDelivery: true,
              logoTint: .brown,
              categories: ["Fashion", "Retail", "Home"]),
        // Lowe's (added)
        .init(name: "Lowe's",
              description: "Home improvement, appliances, tools, and garden supplies with member savings",
              tags: ["Home Improvement", "Appliances", "Garden"],
              rating: 4.4,
              perkText: "Member deals",
              etaText: "3–5 hours",
              freeDelivery: false,
              logoTint: .blue,
              categories: ["Home", "Retail"])
    ]

    private var filteredRetailers: [RetailerItem] {
        retailers.filter { item in
            let byCategory = (selectedCategory == "All") || item.categories.contains(selectedCategory)
            let bySearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || item.name.localizedCaseInsensitiveContains(searchText)
            || item.description.localizedCaseInsensitiveContains(searchText)
            return byCategory && bySearch
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Retail Marketplace")
                        .font(.system(size: 32, weight: .heavy))
                    Text("Shop from your favorite retailers and receive free rapid delivery with your laundry redelivery")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)

                // Search
                searchBar

                // Featured
                VStack(alignment: .leading, spacing: 10) {
                    Text("Featured Deals")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(deals) { deal in
                                FeaturedDealCard(deal: deal)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)

                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.title) { cat in
                            CategoryChip(
                                title: cat.title,
                                icon: cat.icon,
                                isSelected: selectedCategory == cat.title
                            ) {
                                selectedCategory = cat.title
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .padding(.top, 4)

                // Retailer count
                Text("\(filteredRetailers.count) retailer\(filteredRetailers.count == 1 ? "" : "s")")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.top, 6)

                // Retailer list
                VStack(spacing: 12) {
                    ForEach(filteredRetailers) { item in
                        RetailerCard(item: item)
                    }
                }
                .padding(.top, 2)

                // Why shop section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why Shop Through Rapidual?")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        BenefitCard(icon: "shippingbox.and.arrow.backward.fill",
                                    iconTint: .blue,
                                    title: "Unified Delivery",
                                    subtitle: "Combine orders from multiple retailers for efficient delivery")
                        BenefitCard(icon: "lock.shield.fill",
                                    iconTint: .green,
                                    title: "Secure Shopping",
                                    subtitle: "Protected payments and secure account linking")
                        BenefitCard(icon: "star.fill",
                                    iconTint: .yellow,
                                    title: "Best Deals",
                                    subtitle: "Access exclusive offers and member pricing")
                        BenefitCard(icon: "clock.fill",
                                    iconTint: .purple,
                                    title: "Time Saving",
                                    subtitle: "Shop multiple stores without multiple apps")
                    }
                }
                .padding(.top, 10)

            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AppTheme.softBG.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search retailers or products...", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Retail helper views

private struct FeaturedDealCard: View {
    let deal: CustomerExploreView.FeaturedDeal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(deal.tint.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "gift.fill").foregroundColor(deal.tint))
            Text(deal.brand)
                .font(.subheadline).bold()
                .foregroundColor(.primary)
            Text(deal.headline)
                .font(.headline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(deal.subheadline)
                .font(.subheadline).bold()
                .foregroundColor(.blue)
        }
        .padding(14)
        .frame(width: 260, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(deal.tint.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : .primary)
            .background(isSelected ? Color.black : Color.clear, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.black : Color.secondary.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RetailerCard: View {
    let item: CustomerExploreView.RetailerItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Logo placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.logoTint.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "bag.fill")
                            .foregroundColor(item.logoTint)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(item.name)
                        .font(.title3).bold()

                    // Description
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Tags
                    HStack(spacing: 8) {
                        ForEach(item.tags, id: \.self) { tag in
                            TagPill(text: tag)
                        }
                    }

                    // Rating + Perk
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").foregroundColor(.orange)
                            Text(String(format: "%.1f", item.rating))
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)

                        Text("% \(item.perkText)")
                            .font(.subheadline).bold()
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    if item.freeDelivery {
                        BadgePill(text: "Free Delivery", tint: .green)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(item.etaText)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

private struct TagPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption).bold()
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(uiColor: .systemGray6), in: Capsule())
    }
}

private struct BadgePill: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.caption).bold()
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
    }
}

private struct BenefitCard: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(iconTint.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: icon).foregroundColor(iconTint))
            Text(title).font(.subheadline).bold()
            Text(subtitle).font(.caption).foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemGray6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Account

struct CustomerAccountView: View {
    var body: some View {
        List {
            Section("Profile") {
                NavigationLink("Personal Info") { Text("Personal Info") }
                NavigationLink("Addresses") { Text("Addresses") }
                NavigationLink("Payment Methods") { Text("Payment Methods") }
            }
            Section("Preferences") {
                Toggle("Notifications", isOn: .constant(true))
                Toggle("Promotions", isOn: .constant(true))
            }
            Section("Help") {
                NavigationLink("Support") { SupportTicketsView() }
                Button(role: .destructive) { } label: { Text("Log Out") }
            }
        }
        .navigationTitle("Account")
    }
}

// MARK: - DRIVER EXPERIENCE

struct DriverMainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DriverHomeView()
            }
            .tabItem {
                Image(systemName: "steeringwheel")
                Text("Home")
            }

            NavigationStack {
                JobMatchingView()
            }
            .tabItem {
                Image(systemName: "briefcase.fill")
                Text("Jobs")
            }

            NavigationStack {
                OrderIntakeView()
            }
            .tabItem {
                Image(systemName: "tray.full.fill")
                Text("Orders")
            }

            NavigationStack {
                OperationsDashboardView()
            }
            .tabItem {
                Image(systemName: "speedometer")
                Text("Ops")
            }

            NavigationStack {
                SupportTicketsView()
            }
            .tabItem {
                Image(systemName: "questionmark.circle.fill")
                Text("Support")
            }
        }
        .tint(.primary)
    }
}

struct DriverHomeView: View {
    // Irvine, CA
    private let irvine = CLLocationCoordinate2D(latitude: 33.6846, longitude: -117.8265)

    @State private var isOnline: Bool = true

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.6846, longitude: -117.8265),
        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
    )
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 33.6846, longitude: -117.8265),
                           span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045))
    )

    @State private var hasCurrentJob: Bool = true
    @State private var currentJobPickup: String = "123 Main St, Irvine"
    @State private var currentJobDropoff: String = "456 Elm St, Irvine"
    @State private var currentJobBags: Int = 2

    @State private var navigateToDriverFlow: Bool = false
    @State private var navigateToJobs: Bool = false
    @State private var showBoostBanner: Bool = true

    var body: some View {
        ZStack {
            Map(position: $position)
                .ignoresSafeArea()

            // Subtle bottom-only gradient to keep most of the map visible
            LinearGradient(colors: [Color.clear, Color.black.opacity(0.10)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 220)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)

                Spacer()

                bottomSheet
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
        }
        .navigationDestination(isPresented: $navigateToDriverFlow) {
            DriverAppView()
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationDestination(isPresented: $navigateToJobs) {
            JobMatchingView()
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "person.fill").foregroundColor(.primary))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(isOnline ? Color.green : Color.gray).frame(width: 6, height: 6)
                    Text(isOnline ? "Online" : "Offline")
                        .font(.subheadline).bold()
                        .foregroundColor(isOnline ? .green : .secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.secondary)
                    Text("Irvine, CA")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            Spacer()

            // Recenter button moved into top bar to avoid obstructing the map
            SolidCircleButton(systemName: "location.fill") {
                withAnimation(.easeInOut) { position = .region(region) }
            }

            Toggle("", isOn: $isOnline)
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .labelsHidden()
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Bottom Sheet

    private var bottomSheet: some View {
        VStack(spacing: 12) {
            HandleBar()

            if showBoostBanner {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill").foregroundColor(.yellow)
                    Text("Irvine Boost: +$10/trip 5–8 PM")
                        .font(.footnote).bold()
                    Spacer()
                    Button {
                        withAnimation(.spring) { showBoostBanner = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.yellow.opacity(0.12))
                )
            }

            metricsGrid

            if hasCurrentJob {
                currentJobCard
            } else {
                noJobCard
            }

            quickActions
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            DriverMetricTile(icon: "dollarsign.circle.fill", title: "Earnings", value: "$128.40", tint: .green)
            DriverMetricTile(icon: "figure.walk.circle.fill", title: "Trips", value: "6", tint: .blue)
            DriverMetricTile(icon: "clock.fill", title: "Online", value: "3h 12m", tint: .orange)
            DriverMetricTile(icon: "star.fill", title: "Rating", value: "4.9", tint: .purple)
        }
    }

    private var currentJobCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Job")
                    .font(.headline)
                Spacer()
                PillLabel(text: "On Trip", color: .green)
            }

            HStack(alignment: .top, spacing: 12) {
                // Route dots
                VStack(spacing: 6) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Rectangle().fill(Color.gray.opacity(0.35)).frame(width: 2, height: 18)
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pickup").font(.caption).foregroundColor(.secondary)
                        Text(currentJobPickup).font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Drop-off").font(.caption).foregroundColor(.secondary)
                        Text(currentJobDropoff).font(.subheadline)
                    }

                    HStack(spacing: 8) {
                        TagPill(text: "\(currentJobBags) bag\(currentJobBags == 1 ? "" : "s")")
                        TagPill(text: "0.8 mi")
                        TagPill(text: "ETA 12m")
                    }
                    .padding(.top, 2)
                }
            }

            HStack(spacing: 10) {
                Button {
                    navigateToDriverFlow = true
                } label: {
                    Label("Open Workflow", systemImage: "arrow.forward.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    hasCurrentJob = false
                } label: {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var noJobCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill").foregroundColor(.green)
                Text("You’re Online").font(.headline)
                Spacer()
                PillLabel(text: "Irvine, CA", color: .blue.opacity(0.9))
            }

            Text("No current job. Head to Jobs to accept a pickup nearby.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button {
                    navigateToJobs = true
                } label: {
                    Label("Browse Jobs", systemImage: "list.bullet.rectangle.portrait.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    // preferences
                } label: {
                    Label("Preferences", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            GlassAction(icon: "bolt.fill", title: "Go") {
                navigateToJobs = true
            }
            GlassAction(icon: "mappin.and.ellipse", title: "Set Dest.") { }
            GlassAction(icon: "clock.arrow.circlepath", title: "History") { }
            GlassAction(icon: "gearshape.fill", title: "Settings") { }
        }
    }
}

// MARK: - Driver Helper Views

private struct HandleBar: View {
    var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 42, height: 5)
            .padding(.bottom, 4)
    }
}

private struct DriverMetricTile: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: icon).foregroundColor(tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.headline)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct PillLabel: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption).bold()
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color, in: Capsule())
    }
}

private struct GlassButton: View {
    let icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primary)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// Solid circular button (black) for minimal obstruction
private struct SolidCircleButton: View {
    let systemName: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.9), in: Circle())
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                .accessibilityLabel("Recenter Map")
        }
        .buttonStyle(.plain)
    }
}

private struct GlassAction: View {
    let icon: String
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0.15)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// Existing driver flow prototype preserved
struct DriverAppView: View {
    @State private var currentScreen: String = "jobAvailable"
    @State private var acceptedJob: Bool = false
    @State private var jobDetails: String = "Pickup 2 bags at 123 Main St. Drop-off by 3 PM."
    @State private var notes: String = ""

    var body: some View {
        VStack {
            if currentScreen == "jobAvailable" {
                Text("New Pickup Job Nearby")
                    .font(.title2)
                    .padding()

                Text(jobDetails)
                    .padding()

                HStack {
                    Button("Decline") {
                        acceptedJob = false
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)

                    Button("Accept") {
                        acceptedJob = true
                        currentScreen = "jobInProgress"
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
            } else if currentScreen == "jobInProgress" {
                VStack {
                    Text("On the Way to Pickup")
                        .font(.title2)
                        .padding(.bottom)

                    Button("Confirm Pickup") {
                        currentScreen = "pickupConfirmed"
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)

                    Button("Add Notes") { }
                    .buttonStyle(.bordered)

                    TextField("Add notes here...", text: $notes)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                }
                .padding()
            } else if currentScreen == "pickupConfirmed" {
                VStack {
                    Text("Laundry Picked Up")
                        .font(.title2)
                        .padding(.bottom)

                    Text("Proceed to drop-off location.")
                        .padding(.bottom)

                    Button("Confirm Drop-off") {
                        currentScreen = "jobCompleted"
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if currentScreen == "jobCompleted" {
                VStack {
                    Text("Job Completed")
                        .font(.title2)
                        .padding(.bottom)

                    Text("Thank you! Notes:")
                        .padding(.bottom, 4)

                    Text(notes.isEmpty ? "No notes provided." : notes)
                        .italic()
                        .padding(.bottom)

                    Button("Back to Available Jobs") {
                        notes = ""
                        acceptedJob = false
                        currentScreen = "jobAvailable"
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                Text("Unknown State")
                Button("Reset") {
                    currentScreen = "jobAvailable"
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview("Driver Flow") {
    DriverAppView()
}
