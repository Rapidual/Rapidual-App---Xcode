//  ContentView.swift
//  Rapidual - App
//
//  Created by Thomas Peters on 10/16/24.
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

// MARK: - Root with Mode Switch

struct ContentView: View {
    @State private var appMode: AppMode = .user

    var body: some View {
        VStack(spacing: 0) {
            // Top-level header with mode switcher
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
                    .padding(.horizontal, 16)
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

#Preview("Driver Flow") {
    DriverAppView()
}

#Preview {
    ContentView()
}

// MARK: - CUSTOMER EXPERIENCE

struct CustomerMainTabView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CustomerHomeView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            NavigationStack {
                CustomerOrdersView()
            }
            .tabItem {
                Image(systemName: "waveform.path.ecg")
                Text("Orders")
            }
            .tag(1)

            NavigationStack {
                CustomerExploreView()
            }
            .tabItem {
                Image(systemName: "building.2.fill")
                Text("Shop")
            }
            .tag(2)

            NavigationStack {
                CustomerAccountView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle.fill")
                Text("Account")
            }
            .tag(3)
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
    
    // Location-related state
    @State private var isRequestingLocation: Bool = false
    @State private var showLocationRetry: Bool = false
    @State private var locationErrorMessage: String?
    
    // Search-related state
    @State private var searchResults: [SearchResult] = []
    @State private var showSearchResults: Bool = false
    @State private var isSearching: Bool = false
    
    // Quick action navigation/sheet state
    @State private var navigateToOrders: Bool = false
    @State private var navigateToSupport: Bool = false
    @State private var navigateToPromos: Bool = false
    @State private var showPaymentSheet: Bool = false
    @State private var showNotificationsSheet: Bool = false
    @State private var showOrderFlow: Bool = false

    enum PickupMode: String, CaseIterable {
        case asap = "ASAP"
        case later = "Later"
    }
    
    // MARK: - Search Model
    
    struct SearchResult: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let icon: String
        let category: SearchCategory
        let action: () -> Void
        
        enum SearchCategory: String {
            case retailer = "Retailers"
            case helpTopic = "Help Topics"
            case quickAction = "Quick Actions"
        }
    }
    
    // Search data source
    private var allSearchableItems: [SearchResult] {
        var items: [SearchResult] = []
        
        // Retailers
        for name in retailerNames {
            items.append(SearchResult(
                title: name,
                subtitle: "Browse \(name) products",
                icon: "bag.fill",
                category: .retailer,
                action: {
                    // Navigate to retailer
                    print("Navigate to \(name)")
                }
            ))
        }
        
        // Help Topics
        let helpTopics = [
            ("How to place an order", "Step-by-step guide", "questionmark.circle.fill"),
            ("Track my laundry", "Real-time tracking", "location.viewfinder"),
            ("Pricing information", "See our rates", "dollarsign.circle.fill"),
            ("Delivery areas", "Check if we serve your area", "map.fill"),
            ("Account settings", "Manage your profile", "person.crop.circle.fill"),
            ("Payment methods", "Add or update cards", "creditcard.fill"),
            ("Cancel order", "Cancel or modify orders", "xmark.circle.fill"),
            ("Contact support", "Get help from our team", "bubble.left.and.bubble.right.fill")
        ]
        
        for (title, subtitle, icon) in helpTopics {
            items.append(SearchResult(
                title: title,
                subtitle: subtitle,
                icon: icon,
                category: .helpTopic,
                action: {
                    print("Help: \(title)")
                }
            ))
        }
        
        // Quick Actions
        let quickActions = [
            ("Start laundry order", "Begin new pickup", "washer"),
            ("Reorder last order", "Repeat previous order", "arrow.clockwise"),
            ("Schedule pickup", "Set future pickup time", "calendar"),
            ("View all orders", "See order history", "list.bullet"),
            ("Chat with support", "Instant help", "message.fill"),
            ("Add promo code", "Save on your order", "tag.fill")
        ]
        
        for (title, subtitle, icon) in quickActions {
            items.append(SearchResult(
                title: title,
                subtitle: subtitle,
                icon: icon,
                category: .quickAction,
                action: {
                    print("Action: \(title)")
                }
            ))
        }
        
        return items
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
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Empty toolbar to remove title while keeping navigation bar visible
                Text("")
            }
        }
        .navigationDestination(isPresented: $navigateToOrders) {
            CustomerOrdersView(initialSegment: .active)
        }
        .navigationDestination(isPresented: $navigateToSupport) {
            SupportTicketsView()
        }
        .navigationDestination(isPresented: $navigateToPromos) {
            PromoCodesView()
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentMethodsSheet()
        }
        .sheet(isPresented: $showNotificationsSheet) {
            NotificationSettingsSheet()
        }
        .sheet(isPresented: $showOrderFlow) {
            OrderFlowView(
                bagCount: $bagCount,
                pickupMode: $pickupMode,
                scheduledDate: $scheduledDate,
                estimatedCost: estimatedCost
            )
        }
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
                        if let city = locationService.placemark?.locality ?? locationService.locality {
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

            // Search bar with overlay
            ZStack(alignment: .top) {
                SearchBarLarge(
                    text: $searchTextHome,
                    placeholder: "Search retailers, items, or help",
                    isSearching: $isSearching
                )
                .onChange(of: searchTextHome) { oldValue, newValue in
                    performSearch(query: newValue)
                }
                .onChange(of: isSearching) { oldValue, newValue in
                    if !newValue && searchTextHome.isEmpty {
                        withAnimation {
                            showSearchResults = false
                        }
                    }
                }
                
                // Search results overlay
                if showSearchResults && !searchResults.isEmpty {
                    SearchResultsOverlay(
                        results: searchResults,
                        onDismiss: {
                            withAnimation {
                                showSearchResults = false
                                searchTextHome = ""
                                isSearching = false
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
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
                // Prominent "Enable Location" button with animation
                Button {
                    requestLocationWithFeedback()
                } label: {
                    HStack(spacing: 6) {
                        if isRequestingLocation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white)
                                .symbolEffect(.bounce, value: isRequestingLocation)
                        }
                        Text(isRequestingLocation ? "Requesting..." : "Enable")
                            .foregroundColor(.white)
                            .font(.caption).bold()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    .scaleEffect(isRequestingLocation ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRequestingLocation)
                }
                .buttonStyle(.plain)
                .disabled(isRequestingLocation)
                
            case .restricted, .denied:
                // Show error state with retry option
                Pill(background: Color.orange.opacity(0.15)) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Off")
                            .foregroundColor(.orange)
                            .font(.caption).bold()
                        
                        if showLocationRetry {
                            Button {
                                openSettings()
                            } label: {
                                Text("Settings")
                                    .font(.caption2).bold()
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.spring()) {
                            showLocationRetry = true
                        }
                    }
                }
                
            case .authorized:
                if let isIn = locationService.isInServiceArea {
                    if isIn {
                        // Show city name when available
                        Pill(background: Color.green.opacity(0.15)) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .symbolEffect(.pulse, value: locationService.locality)
                                
                                if let city = locationService.locality {
                                    Text(city)
                                        .foregroundColor(.green)
                                        .font(.caption).bold()
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Text("Available")
                                        .foregroundColor(.green)
                                        .font(.caption).bold()
                                }
                            }
                        }
                        .animation(.spring(), value: locationService.locality)
                        
                    } else {
                        // Not in service area - show retry
                        Pill(background: Color.orange.opacity(0.15)) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.orange)
                                
                                if let city = locationService.locality {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(city)
                                            .foregroundColor(.orange)
                                            .font(.caption2).bold()
                                        Text("Coming soon")
                                            .foregroundColor(.orange.opacity(0.8))
                                            .font(.caption2)
                                    }
                                } else {
                                    Text("Coming soon")
                                        .foregroundColor(.orange)
                                        .font(.caption).bold()
                                }
                            }
                        }
                    }
                } else {
                    // Still determining service area
                    Pill(background: Color.white.opacity(0.15)) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Checking...")
                                .foregroundColor(.white)
                                .font(.caption).bold()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Location Helper Methods
    
    private func requestLocationWithFeedback() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation {
            isRequestingLocation = true
        }
        
        // Request authorization
        locationService.requestAuthorization()
        
        // Monitor for status change
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                withAnimation {
                    isRequestingLocation = false
                }
                
                // Success haptic if authorized
                if locationService.status == .authorized {
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                } else if locationService.status == .denied || locationService.status == .restricted {
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                    showLocationRetry = true
                }
            }
        }
    }
    
    private func openSettings() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
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
                        showOrderFlow = true
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
                ActionChip(icon: "location.viewfinder", title: "Track Order") {
                    navigateToOrders = true
                }
                ActionChip(icon: "bubble.left.and.bubble.right.fill", title: "Chat Support", tint: .green) {
                    navigateToSupport = true
                }
                ActionChip(icon: "creditcard.fill", title: "Quick Pay", tint: .purple) {
                    showPaymentSheet = true
                }
                ActionChip(icon: "bell.fill", title: "Notifications", tint: .orange) {
                    showNotificationsSheet = true
                }
                ActionChip(icon: "tag.fill", title: "Promos", tint: .pink) {
                    navigateToPromos = true
                }
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

    // MARK: - Search Methods
    
    private func performSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            withAnimation {
                searchResults = []
                showSearchResults = false
            }
            return
        }
        
        // Filter searchable items based on query
        let filtered = allSearchableItems.filter { item in
            item.title.localizedCaseInsensitiveContains(trimmedQuery) ||
            (item.subtitle?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }
        
        withAnimation {
            searchResults = filtered
            showSearchResults = !filtered.isEmpty
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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
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
    @Binding var isSearching: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($isFocused)
                .onChange(of: isFocused) { oldValue, newValue in
                    isSearching = newValue
                }
            
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? AppTheme.brandBlue : Color.white.opacity(0.20), lineWidth: isFocused ? 2 : 1)
        )
        .animation(.spring(response: 0.3), value: isFocused)
        .animation(.spring(response: 0.3), value: text.isEmpty)
    }
}

// MARK: - Search Results Overlay

private struct SearchResultsOverlay: View {
    let results: [CustomerHomeView.SearchResult]
    let onDismiss: () -> Void
    
    // Group results by category
    private var groupedResults: [(category: CustomerHomeView.SearchResult.SearchCategory, items: [CustomerHomeView.SearchResult])] {
        let categories: [CustomerHomeView.SearchResult.SearchCategory] = [.quickAction, .retailer, .helpTopic]
        return categories.compactMap { category in
            let items = results.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Backdrop/dimmer
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    onDismiss()
                }
            
            // Results container
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedResults, id: \.category.rawValue) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                // Category header
                                HStack {
                                    Text(group.category.rawValue)
                                        .font(.caption).bold()
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .font(.caption2).bold()
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15), in: Capsule())
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, group.category == groupedResults.first?.category ? 4 : 0)
                                
                                // Results in this category
                                ForEach(group.items) { result in
                                    SearchResultRow(result: result) {
                                        result.action()
                                        onDismiss()
                                    }
                                }
                            }
                            
                            if group.category != groupedResults.last?.category {
                                Divider()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 400)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SearchResultRow: View {
    let result: CustomerHomeView.SearchResult
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: result.icon)
                            .foregroundColor(iconColor)
                    )
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.subheadline).bold()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let subtitle = result.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Color.secondary.opacity(0.05)
                .opacity(0) // Invisible by default, shows on hover
        )
    }
    
    private var iconColor: Color {
        switch result.category {
        case .retailer:
            return .blue
        case .helpTopic:
            return .orange
        case .quickAction:
            return .green
        }
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

    @AppStorage("selectedOrderSegment") private var persistedSegment: String = Segment.active.rawValue
    @State private var segment: Segment = .active
    @State private var search: String = ""
    @State private var showFilters: Bool = false
    @State private var isLoading: Bool = false
    @State private var isRefreshing: Bool = false

    enum Segment: String, CaseIterable, Identifiable {
        case active = "Active"
        case scheduled = "Scheduled"
        case completed = "Completed"
        var id: String { rawValue }
    }
    
    // Allow initializing with a specific segment
    init(initialSegment: Segment = .active) {
        _segment = State(initialValue: initialSegment)
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
    
    // Badge counts for each segment
    private func badgeCount(for segment: Segment) -> Int {
        orders.filter { order in
            switch segment {
            case .active:
                return order.status == .inProgress
            case .scheduled:
                return order.status == .scheduled
            case .completed:
                return order.status == .delivered || order.status == .canceled
            }
        }.count
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
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if isLoading {
                    loadingState
                } else if filtered.isEmpty {
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
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: segment)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filtered.map { $0.id })
        }
        .background(AppTheme.softBG.ignoresSafeArea())
        .navigationTitle("Orders")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshOrders()
        }
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
        .onAppear {
            // Restore persisted segment on first appear
            if let persistedSeg = Segment(rawValue: persistedSegment) {
                segment = persistedSeg
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
                    // Haptic feedback on segment change
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        segment = seg
                        persistedSegment = seg.rawValue
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(seg.rawValue)
                            .font(.subheadline.bold())
                        
                        // Badge count
                        let count = badgeCount(for: seg)
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2.bold())
                                .foregroundColor(segment == seg ? AppTheme.brandBlue : .white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    segment == seg ? Color.white : AppTheme.brandBlue,
                                    in: Capsule()
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: segment)
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
        .transition(.scale.combined(with: .opacity))
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.brandBlue))
                .scaleEffect(1.5)
            
            Text("Loading orders...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .transition(.opacity)
    }
    
    // Simulate fetching orders from network
    @MainActor
    private func refreshOrders() async {
        isRefreshing = true
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // In a real app, you would fetch orders from your backend here
        // For now, we'll just reload the existing orders to simulate
        
        isRefreshing = false
        
        // Success haptic
        let successGenerator = UINotificationFeedbackGenerator()
        successGenerator.notificationOccurred(.success)
    }
    
    // Simulate initial loading (optional - can be triggered on first appear)
    private func loadOrders() async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        await MainActor.run {
            withAnimation {
                isLoading = false
            }
        }
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
        
        // State for real-time updates
        @State private var currentStepIndex: Int = 3 // Start at "Washing"
        @State private var stepProgress: Double = 0.0
        @State private var remainingMinutes: Int = 45
        @State private var showStepChangeAlert: Bool = false
        @State private var lastStepChange: String = ""
        
        // Timer for updates
        @State private var timer: Timer?

        private var steps: [Step] {
            [
                .init(title: "Order Placed", time: "1:30 PM", state: currentStepIndex > 0 ? .done : (currentStepIndex == 0 ? .current : .next)),
                .init(title: "Driver Assigned", time: "1:45 PM", state: currentStepIndex > 1 ? .done : (currentStepIndex == 1 ? .current : .next)),
                .init(title: "Pickup Complete", time: "2:00 PM", state: currentStepIndex > 2 ? .done : (currentStepIndex == 2 ? .current : .next)),
                .init(title: "Washing", time: "2:15 PM", state: currentStepIndex > 3 ? .done : (currentStepIndex == 3 ? .current : .next)),
                .init(title: "Drying", time: "2:45 PM", state: currentStepIndex > 4 ? .done : (currentStepIndex == 4 ? .current : .next)),
                .init(title: "Folding", time: "3:15 PM", state: currentStepIndex > 5 ? .done : (currentStepIndex == 5 ? .current : .next)),
                .init(title: "Out for Delivery", time: "3:30 PM", state: currentStepIndex > 6 ? .done : (currentStepIndex == 6 ? .current : .next)),
                .init(title: "Delivered", time: "4:00 PM", state: currentStepIndex > 7 ? .done : (currentStepIndex == 7 ? .current : .next))
            ]
        }
        
        private var currentStep: Step {
            steps[min(currentStepIndex, steps.count - 1)]
        }
        
        private var overallProgress: Double {
            let baseProgress = Double(currentStepIndex) / Double(steps.count)
            let stepIncrement = stepProgress / Double(steps.count)
            return min(baseProgress + stepIncrement, 1.0)
        }

        var body: some View {
            ZStack {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Laundry Pickup")
                            .font(.headline)
                        BadgePill(text: order.title, tint: order.tint)
                        Spacer()
                        
                        // Real-time countdown
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("\(remainingMinutes) min remaining")
                                .font(.footnote).bold()
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                    }

                    // Current step with pulse animation
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(stepColor(for: currentStep.state))
                                .frame(width: 12, height: 12)
                                .scaleEffect(currentStep.state == .current ? 1.2 : 1.0)
                                .animation(
                                    currentStep.state == .current ?
                                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                                        .default,
                                    value: currentStep.state == .current
                                )
                            
                            if currentStep.state == .current {
                                Circle()
                                    .stroke(stepColor(for: currentStep.state), lineWidth: 2)
                                    .frame(width: 20, height: 20)
                                    .scaleEffect(1.5)
                                    .opacity(0.5)
                                    .animation(
                                        Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                        value: currentStep.state == .current
                                    )
                            }
                        }
                        
                        Text(currentStep.title)
                            .font(.subheadline).bold()
                            .foregroundColor(stepColor(for: currentStep.state))
                        
                        Spacer()
                        
                        // Step progress indicator
                        Text("\(currentStepIndex + 1)/\(steps.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                    
                    // Overall progress bar
                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.brandBlue, AppTheme.deepBlue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * overallProgress, height: 6)
                                    .animation(.easeInOut(duration: 0.5), value: overallProgress)
                            }
                        }
                        .frame(height: 6)
                        
                        HStack {
                            Text("\(Int(overallProgress * 100))% Complete")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Step \(min(currentStepIndex + 1, steps.count)) of \(steps.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
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

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                AnimatedProgressTimelineRow(
                                    step: step,
                                    isLast: index == steps.count - 1,
                                    isCurrentlyActive: index == currentStepIndex,
                                    stepProgress: stepProgress
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
                
                // Push notification-style alert
                if showStepChangeAlert {
                    VStack {
                        StepChangeNotification(stepName: lastStepChange)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .zIndex(1)
                }
            }
            .onAppear {
                startProgressSimulation()
            }
            .onDisappear {
                stopProgressSimulation()
            }
        }
        
        // MARK: - Helper Methods
        
        private func startProgressSimulation() {
            // Start timer that updates every 30 seconds
            timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                updateProgress()
            }
            
            // Also update every second for countdown
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { countdownTimer in
                if remainingMinutes > 0 {
                    // Update countdown every 60 seconds
                    if Int(Date().timeIntervalSince1970) % 60 == 0 {
                        withAnimation {
                            remainingMinutes = max(0, remainingMinutes - 1)
                        }
                    }
                } else {
                    countdownTimer.invalidate()
                }
            }
        }
        
        private func stopProgressSimulation() {
            timer?.invalidate()
            timer = nil
        }
        
        private func updateProgress() {
            withAnimation(.easeInOut(duration: 0.5)) {
                // Increment step progress
                stepProgress += 0.33 // Progress through current step
                
                // Check if we should move to next step
                if stepProgress >= 1.0 {
                    stepProgress = 0.0
                    
                    if currentStepIndex < steps.count - 1 {
                        let oldStepIndex = currentStepIndex
                        currentStepIndex += 1
                        
                        // Show notification for step change
                        lastStepChange = steps[currentStepIndex].title
                        showStepChangeNotification()
                        
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        // Update ETA based on step
                        updateETA(for: currentStepIndex)
                    }
                }
            }
        }
        
        private func updateETA(for stepIndex: Int) {
            // Simulate ETA updates based on step
            switch stepIndex {
            case 0: remainingMinutes = 150 // Order placed: 2.5 hours
            case 1: remainingMinutes = 120 // Driver assigned: 2 hours
            case 2: remainingMinutes = 90  // Pickup complete: 1.5 hours
            case 3: remainingMinutes = 60  // Washing: 1 hour
            case 4: remainingMinutes = 45  // Drying: 45 min
            case 5: remainingMinutes = 30  // Folding: 30 min
            case 6: remainingMinutes = 15  // Out for delivery: 15 min
            case 7: remainingMinutes = 0   // Delivered
            default: break
            }
        }
        
        private func showStepChangeNotification() {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showStepChangeAlert = true
            }
            
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showStepChangeAlert = false
                }
            }
        }
        
        private func stepColor(for state: Step.State) -> Color {
            switch state {
            case .done: return .green
            case .current: return .blue
            case .next: return Color.secondary.opacity(0.3)
            }
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

        private struct AnimatedProgressTimelineRow: View {
            let step: Step
            let isLast: Bool
            let isCurrentlyActive: Bool
            let stepProgress: Double
            
            var body: some View {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 4) {
                        bullet
                        if !isLast {
                            Rectangle()
                                .fill(lineColor)
                                .frame(width: 2, height: 24)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(step.title)
                                .font(.subheadline)
                                .fontWeight(step.state == .current ? .semibold : .regular)
                                .foregroundColor(step.state == .current ? .blue : .primary)
                            
                            if step.state == .current && stepProgress > 0 {
                                ProgressView(value: stepProgress, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    .frame(width: 50)
                                    .scaleEffect(y: 0.5)
                            }
                        }
                        
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
                            
                            if isCurrentlyActive {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                    .scaleEffect(1.5)
                                    .opacity(0.3)
                                    .animation(
                                        Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false),
                                        value: isCurrentlyActive
                                    )
                            }
                        }
                    case .next:
                        Circle().fill(Color.secondary.opacity(0.25)).frame(width: 16, height: 16)
                    }
                }
            }
            
            private var lineColor: Color {
                step.state == .done ? Color.green.opacity(0.5) : Color.secondary.opacity(0.25)
            }
        }
        
        // Push notification-style alert view
        private struct StepChangeNotification: View {
            let stepName: String
            
            var body: some View {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.brandBlue)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Order Updated")
                            .font(.subheadline).bold()
                        Text("Now: \(stepName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.brandBlue.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 16)
                .padding(.top, 8)
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
    
    // State for animations and interactions
    @State private var timelineProgress: CGFloat = 0.0
    @State private var showChatInterface: Bool = false
    @State private var showCancelDialog: Bool = false
    @State private var showReorderSheet: Bool = false
    @State private var isCancelling: Bool = false
    
    // Mock driver location (Irvine, CA area)
    @State private var driverLocation = CLLocationCoordinate2D(
        latitude: 33.6846,
        longitude: -117.8265
    )
    
    // Mock customer location
    @State private var customerLocation = CLLocationCoordinate2D(
        latitude: 33.6900,
        longitude: -117.8200
    )
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.6873, longitude: -117.8232),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                header

                liveMapView

                timeline

                actions
            }
            .padding(16)
        }
        .background(AppTheme.softBG.ignoresSafeArea())
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChatInterface) {
            DriverChatInterface(order: order)
        }
        .sheet(isPresented: $showReorderSheet) {
            ReorderSheet(order: order)
        }
        .alert("Cancel Order?", isPresented: $showCancelDialog) {
            Button("Keep Order", role: .cancel) { }
            Button("Cancel Order", role: .destructive) {
                cancelOrder()
            }
        } message: {
            Text("Are you sure you want to cancel this order? This action cannot be undone.")
        }
        .onAppear {
            // Animate timeline progress based on order status
            animateTimelineProgress()
            
            // Simulate driver movement if order is in progress
            if order.status == .inProgress {
                startDriverMovementSimulation()
            }
        }
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

    private var liveMapView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live Tracking", systemImage: "location.fill")
                    .font(.headline)
                Spacer()
                if order.status == .inProgress {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Driver en route")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12), in: Capsule())
                }
            }
            
            Map(coordinateRegion: $mapRegion, annotationItems: mapAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(annotation.annotationType == .driver ? Color.blue : Color.green)
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: annotation.annotationType == .driver ? "car.fill" : "house.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        if order.status == .inProgress {
                            Text(annotation.annotationType == .driver ? "Driver" : "You")
                                .font(.caption2).bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7), in: Capsule())
                        }
                    }
                }
            }
            .frame(height: 220)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            if order.status == .inProgress {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated Arrival")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(order.eta ?? "—")
                            .font(.subheadline).bold()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("0.8 mi")
                            .font(.subheadline).bold()
                    }
                }
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
    
    private var mapAnnotations: [OrderMapAnnotation] {
        var annotations: [OrderMapAnnotation] = [
            OrderMapAnnotation(
                coordinate: customerLocation,
                annotationType: .customer
            )
        ]
        
        if order.status == .inProgress {
            annotations.append(
                OrderMapAnnotation(
                    coordinate: driverLocation,
                    annotationType: .driver
                )
            )
        }
        
        return annotations
    }
    
    struct OrderMapAnnotation: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let annotationType: AnnotationType
        
        enum AnnotationType {
            case driver
            case customer
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                AnimatedTimelineRow(
                    title: "Order Placed",
                    time: "2:05 PM",
                    active: true,
                    progress: timelineProgress,
                    step: 0
                )
                AnimatedTimelineRow(
                    title: "Picked Up",
                    time: "2:28 PM",
                    active: true,
                    progress: timelineProgress,
                    step: 1
                )
                AnimatedTimelineRow(
                    title: order.status == .inProgress ? "In Progress" : "In Wash",
                    time: order.status == .inProgress ? "Now" : "—",
                    active: order.status == .inProgress,
                    progress: timelineProgress,
                    step: 2
                )
                AnimatedTimelineRow(
                    title: "En Route",
                    time: "—",
                    active: false,
                    progress: timelineProgress,
                    step: 3
                )
                AnimatedTimelineRow(
                    title: "Delivered",
                    time: "—",
                    active: false,
                    progress: timelineProgress,
                    step: 4,
                    isLast: true
                )
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }
    
    // Animated timeline row component
    private struct AnimatedTimelineRow: View {
        let title: String
        let time: String
        let active: Bool
        let progress: CGFloat
        let step: Int
        var isLast: Bool = false
        
        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(bulletColor)
                            .frame(width: 10, height: 10)
                            .scaleEffect(active && shouldPulse ? 1.2 : 1.0)
                            .animation(
                                active && shouldPulse ?
                                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                                    .default,
                                value: active
                            )
                        
                        if active && shouldPulse {
                            Circle()
                                .stroke(bulletColor, lineWidth: 2)
                                .frame(width: 18, height: 18)
                                .scaleEffect(active ? 1.3 : 1.0)
                                .opacity(active ? 0.5 : 0)
                                .animation(
                                    Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                    value: active
                                )
                        }
                    }
                    
                    if !isLast {
                        Rectangle()
                            .fill(lineColor)
                            .frame(width: 2, height: 24)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.subheadline).bold()
                            .foregroundColor(active ? .primary : .secondary)
                        
                        if active && shouldPulse {
                            PillLabel(text: "Active", color: .blue)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        
        private var shouldPulse: Bool {
            progress >= CGFloat(step) && progress < CGFloat(step + 1)
        }
        
        private var bulletColor: Color {
            if progress > CGFloat(step) {
                return .green
            } else if active {
                return .blue
            } else {
                return Color.secondary.opacity(0.3)
            }
        }
        
        private var lineColor: Color {
            progress > CGFloat(step) ? Color.green.opacity(0.5) : Color.secondary.opacity(0.25)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            // Primary actions
            HStack(spacing: 12) {
                Button {
                    // Track on map
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Label("Track", systemImage: "location.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if order.status == .inProgress {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        showChatInterface = true
                    } label: {
                        Label("Contact Driver", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        // Support
                    } label: {
                        Label("Support", systemImage: "bubble.left.and.bubble.right.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.subheadline)
            
            // Secondary actions
            HStack(spacing: 12) {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    showReorderSheet = true
                } label: {
                    Label("Reorder", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if order.status == .inProgress || order.status == .scheduled {
                    Button(role: .destructive) {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        showCancelDialog = true
                    } label: {
                        Label("Cancel Order", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .font(.subheadline)
        }
        .padding(.top, 2)
    }
    
    // MARK: - Helper Methods
    
    private func animateTimelineProgress() {
        // Determine progress based on order status
        let targetProgress: CGFloat = switch order.status {
        case .inProgress:
            2.5 // Currently in progress (between step 2 and 3)
        case .scheduled:
            0.5 // Scheduled but not started
        case .delivered:
            5.0 // Completed all steps
        case .canceled:
            1.0 // Stopped after pickup
        }
        
        withAnimation(.easeInOut(duration: 1.5)) {
            timelineProgress = targetProgress
        }
    }
    
    private func startDriverMovementSimulation() {
        // Simulate driver moving toward customer
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 2.0)) {
                // Move driver slightly closer to customer
                let latDiff = customerLocation.latitude - driverLocation.latitude
                let lonDiff = customerLocation.longitude - driverLocation.longitude
                
                driverLocation.latitude += latDiff * 0.1
                driverLocation.longitude += lonDiff * 0.1
                
                // Stop when close enough
                if abs(latDiff) < 0.001 && abs(lonDiff) < 0.001 {
                    timer.invalidate()
                }
            }
        }
    }
    
    private func cancelOrder() {
        isCancelling = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        
        // Simulate API call
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                isCancelling = false
                
                // Success feedback
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)
                
                // Dismiss view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
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

// MARK: - Driver Chat Interface

private struct DriverChatInterface: View {
    let order: CustomerOrdersView.Order
    @Environment(\.dismiss) private var dismiss
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = [
        .init(text: "Hi! I'm on my way to pick up your laundry.", sender: .driver, timestamp: Date().addingTimeInterval(-300)),
        .init(text: "Great! About how long?", sender: .customer, timestamp: Date().addingTimeInterval(-240)),
        .init(text: "About 10 minutes. I'll text when I arrive.", sender: .driver, timestamp: Date().addingTimeInterval(-180))
    ]
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let sender: Sender
        let timestamp: Date
        
        enum Sender {
            case driver
            case customer
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Driver info header
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mike Johnson")
                            .font(.headline)
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text("4.9")
                                .foregroundColor(.secondary)
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Online")
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    Button {
                        // Call driver
                    } label: {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.brandBlue, in: Circle())
                    }
                }
                .padding()
                .background(AppTheme.cardBG)
                
                Divider()
                
                // Messages
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                // Input
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.isEmpty ? .secondary : AppTheme.brandBlue)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(AppTheme.cardBG)
            }
            .navigationTitle("Chat with Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let newMessage = ChatMessage(
            text: messageText,
            sender: .customer,
            timestamp: Date()
        )
        
        withAnimation {
            messages.append(newMessage)
        }
        
        messageText = ""
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

private struct ChatBubble: View {
    let message: DriverChatInterface.ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .customer {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.sender == .driver ? .leading : .trailing, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundColor(message.sender == .driver ? .primary : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.sender == .driver ?
                        Color(uiColor: .secondarySystemBackground) :
                        AppTheme.brandBlue,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if message.sender == .driver {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Reorder Sheet

private struct ReorderSheet: View {
    let order: CustomerOrdersView.Order
    @Environment(\.dismiss) private var dismiss
    
    @State private var bagCount: Int = 2
    @State private var pickupMode: CustomerHomeView.PickupMode = .asap
    @State private var scheduledDate: Date = Date()
    @State private var showOrderFlow: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Order preview
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title2)
                                .foregroundColor(AppTheme.brandBlue)
                            Text("Reorder")
                                .font(.title2).bold()
                        }
                        
                        Text("This will create a new order with the same details as your previous order.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Order details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Order Details")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Label("Previous Order", systemImage: "bag.fill")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(order.title)
                                    .bold()
                            }
                            
                            Divider()
                            
                            HStack {
                                Label("Bags", systemImage: "cube.box.fill")
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Button {
                                        if bagCount > 1 { bagCount -= 1 }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(bagCount > 1 ? AppTheme.brandBlue : .secondary)
                                    }
                                    
                                    Text("\(bagCount)")
                                        .font(.headline)
                                        .frame(minWidth: 30)
                                    
                                    Button {
                                        bagCount += 1
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(AppTheme.brandBlue)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Label("Pickup", systemImage: "clock.fill")
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                Picker("", selection: $pickupMode) {
                                    ForEach(CustomerHomeView.PickupMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }
                            
                            if pickupMode == .later {
                                DatePicker(
                                    "Schedule Time",
                                    selection: $scheduledDate,
                                    in: Date()...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
                    
                    // Estimated cost
                    VStack(spacing: 12) {
                        HStack {
                            Text("Estimated Total")
                                .font(.headline)
                            Spacer()
                            Text("$\(7 + max(0, bagCount - 1) * 6)")
                                .font(.title2).bold()
                                .foregroundColor(AppTheme.brandBlue)
                        }
                        
                        Text("Final price may vary based on actual weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(AppTheme.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Place order button
                    Button {
                        placeReorder()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Place Reorder")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.brandBlue, AppTheme.deepBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(AppTheme.softBG.ignoresSafeArea())
            .navigationTitle("Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Pre-fill with previous order details
            bagCount = order.bags
        }
    }
    
    private func placeReorder() {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Simulate order placement
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// Remove old TimelineRow - it's now AnimatedTimelineRow inside CustomerOrderDetailView

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
                    Text("Marketplace")
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
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.large)
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
                NavigationLink("Support") { Text("Support placeholder") }
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

// MARK: - Driver Feature Views (Stubs)

struct JobMatchingView: View {
    var body: some View {
        Text("Job Matching View")
            .navigationTitle("Jobs")
    }
}

struct OrderIntakeView: View {
    var body: some View {
        Text("Order Intake View")
            .navigationTitle("Orders")
    }
}

struct OperationsDashboardView: View {
    var body: some View {
        Text("Operations Dashboard")
            .navigationTitle("Operations")
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

// MARK: - Quick Action Sheets

struct PaymentMethodsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Visa •••• 4242")
                                .font(.subheadline).bold()
                            Text("Expires 12/25")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.purple)
                            .frame(width: 32, height: 32)
                            .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mastercard •••• 8888")
                                .font(.subheadline).bold()
                            Text("Expires 03/26")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Payment Methods")
                }
                
                Section {
                    Button {
                        // Add new payment method
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Payment Method")
                        }
                    }
                }
            }
            .navigationTitle("Quick Pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var orderUpdates: Bool = true
    @State private var promoAlerts: Bool = true
    @State private var driverMessages: Bool = true
    @State private var emailNotifications: Bool = false
    @State private var smsNotifications: Bool = true
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Order Updates", isOn: $orderUpdates)
                    Toggle("Driver Messages", isOn: $driverMessages)
                    Toggle("Promotional Alerts", isOn: $promoAlerts)
                } header: {
                    Text("Push Notifications")
                } footer: {
                    Text("Get real-time updates about your orders")
                }
                
                Section {
                    Toggle("Email Notifications", isOn: $emailNotifications)
                    Toggle("SMS Notifications", isOn: $smsNotifications)
                } header: {
                    Text("Other Channels")
                }
                
                Section {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.orange)
                        Text("You have 3 unread notifications")
                            .font(.subheadline)
                        Spacer()
                        Button("View") {
                            // View notifications
                        }
                        .font(.subheadline).bold()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct PromoCodesView: View {
    @State private var promoCode: String = ""
    @State private var availablePromos: [PromoCode] = [
        .init(code: "WELCOME10", discount: "10% off", description: "New user discount", expiresAt: "Dec 31", isActive: true),
        .init(code: "FREESHIP", discount: "Free delivery", description: "Orders over $25", expiresAt: "Jan 15", isActive: true),
        .init(code: "SAVE5", discount: "$5 off", description: "Any order", expiresAt: "Used", isActive: false)
    ]
    
    struct PromoCode: Identifiable {
        let id = UUID()
        let code: String
        let discount: String
        let description: String
        let expiresAt: String
        let isActive: Bool
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Add promo code section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter Promo Code")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.secondary)
                        TextField("Enter code", text: $promoCode)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                        
                        Button {
                            // Apply promo code
                        } label: {
                            Text("Apply")
                                .font(.subheadline).bold()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue, in: Capsule())
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(16)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
                .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
                
                // Available promos
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available Promos")
                            .font(.headline)
                        Spacer()
                        Text("\(availablePromos.filter { $0.isActive }.count) active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(availablePromos) { promo in
                        PromoCodeCard(promo: promo)
                    }
                }
                .padding(16)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
                .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
                
                // Info section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("How Promo Codes Work")
                            .font(.subheadline).bold()
                    }
                    
                    Text("• Promo codes are automatically applied at checkout\n• Only one promo code can be used per order\n• Some codes may have minimum order requirements\n• Expired codes cannot be reactivated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(AppTheme.softBG.ignoresSafeArea())
        .navigationTitle("Promo Codes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PromoCodeCard: View {
    let promo: PromoCodesView.PromoCode
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(promo.isActive ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: promo.isActive ? "tag.fill" : "tag.slash.fill")
                        .foregroundColor(promo.isActive ? .green : .gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(promo.code)
                        .font(.subheadline).bold()
                        .foregroundColor(promo.isActive ? .primary : .secondary)
                    
                    Spacer()
                    
                    if promo.isActive {
                        Button {
                            // Copy code
                            UIPasteboard.general.string = promo.code
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                Text("Copy")
                            }
                            .font(.caption).bold()
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Text(promo.discount)
                    .font(.headline)
                    .foregroundColor(promo.isActive ? .green : .secondary)
                
                Text(promo.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(promo.isActive ? "Expires \(promo.expiresAt)" : promo.expiresAt)
                        .foregroundColor(.secondary)
                }
                .font(.caption2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(promo.isActive ? Color.white : Color(uiColor: .systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(promo.isActive ? Color.green.opacity(0.25) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Order Flow

struct OrderFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bagCount: Int
    @Binding var pickupMode: CustomerHomeView.PickupMode
    @Binding var scheduledDate: Date
    let estimatedCost: Double
    
    @State private var currentStep: OrderStep = .address
    @State private var address: String = ""
    @State private var apartmentUnit: String = ""
    @State private var specialInstructions: String = ""
    @State private var selectedPaymentMethod: PaymentMethod = .visa
    @State private var agreedToTerms: Bool = false
    @State private var showingSuccess: Bool = false
    @State private var validationError: String?
    
    enum OrderStep: Int, CaseIterable {
        case address = 0
        case bagCount = 1
        case pickupTime = 2
        case review = 3
        case confirm = 4
        
        var title: String {
            switch self {
            case .address: return "Address"
            case .bagCount: return "Bags"
            case .pickupTime: return "Pickup Time"
            case .review: return "Review"
            case .confirm: return "Confirm"
            }
        }
        
        var icon: String {
            switch self {
            case .address: return "mappin.circle.fill"
            case .bagCount: return "bag.fill"
            case .pickupTime: return "clock.fill"
            case .review: return "list.bullet.clipboard.fill"
            case .confirm: return "checkmark.seal.fill"
            }
        }
    }
    
    enum PaymentMethod: String, CaseIterable {
        case visa = "Visa •••• 4242"
        case mastercard = "Mastercard •••• 8888"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Progress indicator
                    progressBar
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            currentStepView
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 100)
                    }
                }
                
                // Bottom buttons
                VStack {
                    Spacer()
                    bottomButtons
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.clear, AppTheme.softBG.opacity(0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                        )
                }
                
                // Success overlay
                if showingSuccess {
                    successOverlay
                }
            }
            .background(AppTheme.softBG.ignoresSafeArea())
            .navigationTitle("New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(OrderStep.allCases, id: \.rawValue) { step in
                    if step != .address {
                        Rectangle()
                            .fill(step.rawValue <= currentStep.rawValue ? AppTheme.brandBlue : Color.secondary.opacity(0.3))
                            .frame(height: 3)
                    }
                    
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? AppTheme.brandBlue : Color.secondary.opacity(0.3))
                        .frame(width: step == currentStep ? 12 : 8, height: step == currentStep ? 12 : 8)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.brandBlue, lineWidth: step == currentStep ? 2 : 0)
                                .frame(width: 18, height: 18)
                        )
                }
            }
            .padding(.horizontal, 16)
            
            Text(currentStep.title)
                .font(.headline)
                .foregroundColor(AppTheme.brandBlue)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Current Step View
    
    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .address:
            addressStep
        case .bagCount:
            bagCountStep
        case .pickupTime:
            pickupTimeStep
        case .review:
            reviewStep
        case .confirm:
            confirmStep
        }
    }
    
    // MARK: - Address Step
    
    private var addressStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "mappin.circle.fill",
                title: "Pickup Address",
                subtitle: "Where should we pick up your laundry?"
            )
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Street Address")
                        .font(.subheadline).bold()
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.secondary)
                        TextField("123 Main St", text: $address)
                            .textContentType(.streetAddressLine1)
                    }
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(address.isEmpty ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apt / Suite (Optional)")
                        .font(.subheadline).bold()
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.secondary)
                        TextField("Apt 4B", text: $apartmentUnit)
                            .textContentType(.streetAddressLine2)
                    }
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Special Instructions (Optional)")
                        .font(.subheadline).bold()
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "note.text")
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        TextField("e.g., Leave at front door", text: $specialInstructions, axis: .vertical)
                            .lineLimit(3...5)
                    }
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
            
            if let error = validationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
    
    // MARK: - Bag Count Step
    
    private var bagCountStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "bag.fill",
                title: "How Many Bags?",
                subtitle: "Each bag can hold approximately 15-20 items"
            )
            
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    Button {
                        if bagCount > 1 {
                            bagCount -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                LinearGradient(
                                    colors: bagCount > 1 ? [AppTheme.brandBlue, AppTheme.deepBlue] : [Color.gray, Color.gray],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .shadow(color: bagCount > 1 ? AppTheme.shadow : .clear, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(bagCount <= 1)
                    
                    VStack(spacing: 8) {
                        Text("\(bagCount)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(AppTheme.brandBlue)
                        Text("bag\(bagCount == 1 ? "" : "s")")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button {
                        bagCount += 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.brandBlue, AppTheme.deepBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
                .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 6)
                
                VStack(spacing: 12) {
                    InfoRow(icon: "dollarsign.circle.fill", title: "Estimated Cost", value: "$\(Int(7 + max(0, bagCount - 1) * 6))", tint: .green)
                    InfoRow(icon: "scalemass.fill", title: "Total Weight", value: "~\(bagCount * 15) lbs", tint: .blue)
                }
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - Pickup Time Step
    
    private var pickupTimeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "clock.fill",
                title: "Pickup Time",
                subtitle: "When would you like us to pick up your laundry?"
            )
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(CustomerHomeView.PickupMode.allCases, id: \.self) { mode in
                        Button {
                            pickupMode = mode
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: mode == .asap ? "bolt.fill" : "calendar")
                                    .font(.title2)
                                    .foregroundColor(pickupMode == mode ? .white : AppTheme.brandBlue)
                                
                                Text(mode.rawValue)
                                    .font(.headline)
                                    .foregroundColor(pickupMode == mode ? .white : .primary)
                                
                                Text(mode == .asap ? "25-35 min" : "Schedule ahead")
                                    .font(.caption)
                                    .foregroundColor(pickupMode == mode ? .white.opacity(0.9) : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                pickupMode == mode ?
                                LinearGradient(
                                    colors: [AppTheme.brandBlue, AppTheme.deepBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(colors: [Color.white, Color.white], startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(pickupMode == mode ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: pickupMode == mode ? AppTheme.shadow : .clear, radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if pickupMode == .later {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Date & Time")
                            .font(.headline)
                        
                        DatePicker(
                            "Pickup time",
                            selection: $scheduledDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .tint(AppTheme.brandBlue)
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
                }
            }
            .padding(16)
            .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
        }
    }
    
    // MARK: - Review Step
    
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "list.bullet.clipboard.fill",
                title: "Review Your Order",
                subtitle: "Please verify all details before confirming"
            )
            
            VStack(spacing: 16) {
                ReviewSection(title: "Pickup Address") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(address)
                            .font(.subheadline)
                        if !apartmentUnit.isEmpty {
                            Text(apartmentUnit)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if !specialInstructions.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .foregroundColor(.secondary)
                                Text(specialInstructions)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
                ReviewSection(title: "Order Details") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Bags")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(bagCount) bag\(bagCount == 1 ? "" : "s")")
                                .bold()
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Pickup Time")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(pickupTimeText)
                                .bold()
                        }
                    }
                    .font(.subheadline)
                }
                
                ReviewSection(title: "Payment") {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(selectedPaymentMethod == .visa ? .blue : .purple)
                        Text(selectedPaymentMethod.rawValue)
                            .font(.subheadline)
                        Spacer()
                        Button("Change") {
                            // Could expand to show payment selector
                        }
                        .font(.subheadline).bold()
                    }
                }
                
                ReviewSection(title: "Pricing") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Service Fee")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(Int(estimatedCost))")
                        }
                        
                        HStack {
                            Text("Processing")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$1.00")
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text("$\(Int(estimatedCost + 1))")
                                .font(.headline)
                                .foregroundColor(AppTheme.brandBlue)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Confirm Step
    
    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                icon: "checkmark.seal.fill",
                title: "Almost Done!",
                subtitle: "Review terms and confirm your order"
            )
            
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title)
                            .foregroundColor(AppTheme.success)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your order is ready")
                                .font(.headline)
                            Text("We'll send you a confirmation shortly")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $agreedToTerms) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I agree to the Terms & Conditions")
                                    .font(.subheadline).bold()
                                Text("By continuing, you agree to our service terms and privacy policy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(AppTheme.brandBlue)
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(16)
                .background(AppTheme.cardBG, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
                
                if let error = validationError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if currentStep != .address {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentStep = OrderStep(rawValue: currentStep.rawValue - 1) ?? .address
                        validationError = nil
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundColor(AppTheme.brandBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.brandBlue, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
            
            Button {
                handleNextButton()
            } label: {
                HStack(spacing: 8) {
                    Text(currentStep == .confirm ? "Place Order" : "Continue")
                        .font(.headline)
                    if currentStep != .confirm {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [AppTheme.brandBlue, AppTheme.deepBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 60)
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 100, height: 100)
                        .scaleEffect(showingSuccess ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showingSuccess)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(showingSuccess ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showingSuccess)
                }
                
                VStack(spacing: 8) {
                    Text("Order Placed!")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text("We'll pick up your laundry soon")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .opacity(showingSuccess ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.4), value: showingSuccess)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleNextButton() {
        // Validate current step
        validationError = nil
        
        switch currentStep {
        case .address:
            if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationError = "Please enter a pickup address"
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                return
            }
        case .bagCount:
            if bagCount < 1 {
                validationError = "Please select at least 1 bag"
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                return
            }
        case .pickupTime:
            if pickupMode == .later && scheduledDate < Date() {
                validationError = "Please select a future date and time"
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                return
            }
        case .review:
            // No validation needed for review
            break
        case .confirm:
            if !agreedToTerms {
                validationError = "Please agree to the terms and conditions"
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                return
            }
            // Place order
            placeOrder()
            return
        }
        
        // Success haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Move to next step
        if let nextStep = OrderStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.spring(response: 0.3)) {
                currentStep = nextStep
            }
        }
    }
    
    private func placeOrder() {
        // Success haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show success animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showingSuccess = true
        }
        
        // Dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dismiss()
        }
    }
    
    private var pickupTimeText: String {
        switch pickupMode {
        case .asap:
            return "ASAP (25-35 min)"
        case .later:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: scheduledDate)
        }
    }
}

// MARK: - Order Flow Helper Views

private struct StepHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppTheme.brandBlue)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.brandBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
        .font(.subheadline)
    }
}

private struct ReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            content
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 4)
    }
}

// MARK: - Support Tickets

struct SupportTicketsView: View {
    var body: some View {
        List {
            Section("Contact Support") {
                NavigationLink {
                    Text("Chat Support")
                } label: {
                    Label("Start Live Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                
                NavigationLink {
                    Text("Call Support")
                } label: {
                    Label("Call Us", systemImage: "phone.fill")
                }
                
                NavigationLink {
                    Text("Email Support")
                } label: {
                    Label("Send Email", systemImage: "envelope.fill")
                }
            }
            
            Section("Recent Tickets") {
                Text("No recent support tickets")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Support")
    }
}

