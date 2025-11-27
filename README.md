# Rapidual

[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-orange?style=for-the-badge&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue?style=for-the-badge&logo=apple)](https://developer.apple.com/ios/)

Rapidual is a modern SwiftUI-based iOS app prototype for an on-demand laundry delivery service. It integrates retail shopping for bundled deliveries, with dual modes for customers (ordering and tracking) and drivers (job management and navigation). Built with a focus on intuitive UX, location-aware features, and scalable architecture, this demo showcases a seamless experience in select California service areas.

## 🚀 Features

### Customer Experience
- **Home Dashboard**: Personalized greetings, quick laundry ordering (ASAP or scheduled), bag counter, ETA estimates, and cost previews.
- **Activity/Orders**: Track in-progress, scheduled, and completed orders with rich timelines, maps, and actions (track, support, reorder).
- **Retail Marketplace**: Browse and link major retailers (e.g., Walmart, Target, Costco) for free bundled deliveries with laundry. Includes categories, deals, ratings, and perks.
- **Sustainability Insights**: Track savings in water, energy, CO2, and time with interactive metrics.
- **Account & Support**: Profile management, preferences, and ticket-based support.

### Driver Experience
- **Map-Centric Home**: Real-time navigation with online/offline toggle, earnings dashboard, and current job cards.
- **Job Matching**: Browse and accept pickups with details like bags, routes, and boosts.
- **Order Intake**: Manage workflows (accept, pickup, drop-off) with notes and confirmations.
- **Operations Dashboard**: Metrics for trips, ratings, and history.
- **Support**: Integrated ticketing.

### Shared Features
- **Location Services**: Availability checks in predefined California areas (e.g., Irvine, Newport Beach) using CoreLocation and MapKit.
- **Theming**: Custom color scheme with gradients, shadows, and responsive components.
- **Mode Switching**: Seamless toggle between customer and driver modes.
- **Reusable UI**: Modular components like cards, pills, chips, and progress trackers.

## 📱 Screenshots

| Customer Home | Driver Home | Orders Timeline |
|---------------|-------------|-----------------|
| ![Customer Home](https://via.placeholder.com/400x800?text=Customer+Home) | ![Driver Home](https://via.placeholder.com/400x800?text=Driver+Home) | ![Orders](https://via.placeholder.com/400x800?text=Orders+Timeline) |

*(Add actual screenshots from Xcode previews or simulators.)*

## 🛠 Tech Stack
- **Language**: Swift 5.0+
- **Framework**: SwiftUI (iOS 17.0+)
- **Location**: CoreLocation, MapKit, CLGeocoder
- **UI Enhancements**: Combine for state management, UIKit interop where needed
- **No External Dependencies**: Pure Apple frameworks for a lightweight prototype

## 🔌 API Integration Guide

This prototype uses mock data and local state for demonstration. For production, integrate with a backend API (e.g., RESTful service on AWS, Firebase, or custom Node.js/Express server) to handle user auth, orders, payments, and real-time updates. Below is a guide to add API support using native Swift tools like `URLSession` and `Codable`. For advanced needs, consider third-party libraries like Alamofire (add via Swift Package Manager).

### Key APIs to Implement
Design your backend with these endpoints (using JSON over HTTPS):

| Endpoint | Method | Description | Example Request Body |
|----------|--------|-------------|----------------------|
| `/auth/login` | POST | User/driver login | `{ "email": "user@example.com", "password": "pass" }` |
| `/users/{id}/profile` | GET/PUT | Fetch/update profile | (PUT) `{ "name": "John Doe", "phone": "+1555123456" }` |
| `/orders` | GET/POST | List/create orders | (POST) `{ "bags": 2, "pickupMode": "ASAP", "retailItems": [...] }` |
| `/orders/{id}` | GET/PUT | Order details/update status | (PUT) `{ "status": "inProgress", "notes": "Fragile items" }` |
| `/retail/link` | POST | Link retailer account | `{ "retailer": "Walmart", "token": "auth_token" }` |
| `/drivers/jobs` | GET/POST | List/accept jobs | (POST) `{ "jobId": 123, "accepted": true }` |
| `/payments/process` | POST | Handle payments (integrate Stripe/PayPal) | `{ "amount": 7.00, "orderId": 456 }` |
| `/support/tickets` | GET/POST | List/create support tickets | (POST) `{ "subject": "Delivery delay", "description": "..." }` |

- **Auth**: Use JWT tokens stored in Keychain (via `Security` framework).
- **Real-Time**: For live tracking, add WebSockets (e.g., via Starscream library) or Firebase Realtime Database.
- **Error Handling**: Standardize responses: `{ "success": true, "data": {}, "error": "message" }`.
- **Security**: HTTPS only; validate inputs; rate-limit endpoints.

### Integration Steps

1. **Add Networking Layer**:
   Create a shared `NetworkManager` for API calls. Use `async/await` for concurrency.

   ```swift
   // NetworkManager.swift
   import Foundation

   enum APIError: Error {
       case invalidURL, noResponse, invalidData, serverError(Int)
   }

   struct NetworkManager {
       private let baseURL = URL(string: "https://api.rapidual.com/v1")!
       private let session = URLSession.shared
       private var token: String? // Load from Keychain

       func request<T: Codable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
           guard let url = URL(string: endpoint, relativeTo: baseURL) else {
               throw APIError.invalidURL
           }
           var request = URLRequest(url: url)
           request.httpMethod = method
           request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
           request.setValue("application/json", forHTTPHeaderField: "Content-Type")
           if let body { request.httpBody = body }

           let (data, response) = try await session.data(for: request)
           guard let httpResponse = response as? HTTPURLResponse else { throw APIError.noResponse }
           guard (200...299).contains(httpResponse.statusCode) else { throw APIError.serverError(httpResponse.statusCode) }

           return try JSONDecoder().decode(T.self, from: data)
       }
   }
   ```

2. **Define Models**:
   Use `Codable` for request/response structs. Example for orders:

   ```swift
   // Models.swift
   struct Order: Codable, Identifiable {
       let id: Int
       let status: OrderStatus
       let bags: Int
       let eta: String?
       // ... other fields
   }

   enum OrderStatus: String, Codable {
       case inProgress, scheduled, delivered, canceled
   }
   ```

3. **Create API Services**:
   Wrap calls in `ObservableObject` classes for SwiftUI binding.

   ```swift
   // OrderService.swift
   @MainActor
   class OrderService: ObservableObject {
       private let network = NetworkManager()
       @Published var orders: [Order] = []
       @Published var isLoading = false

       func fetchOrders() async {
           isLoading = true
           do {
               orders = try await network.request("/orders")
           } catch {
               // Handle error (e.g., show alert)
               print("Error: \(error)")
           }
           isLoading = false
       }

       func createOrder(bags: Int, mode: String) async throws -> Order {
           let body = try JSONEncoder().encode(["bags": bags, "pickupMode": mode])
           return try await network.request("/orders", method: "POST", body: body)
       }
   }
   ```

4. **Update Views**:
   Inject services via `@StateObject` and trigger calls on events.

   ```swift
   // In CustomerHomeView.swift
   @StateObject private var orderService = OrderService()

   // In body:
   Button("Start Order") {
       Task {
           do {
               let newOrder = try await orderService.createOrder(bags: bagCount, mode: pickupMode.rawValue)
               // Navigate to detail or update UI
           } catch {
               // Show error toast
           }
       }
   }
   .task { await orderService.fetchOrders() } // Load on view appear
   ```

5. **Handle Authentication**:
   - On login: Store token in Keychain.
   - Use `URLSessionDelegate` for token refresh if needed.
   - Example login flow in a `LoginView`:

   ```swift
   func login(email: String, password: String) async throws -> String {
       let body = try JSONEncoder().encode(["email": email, "password": password])
       let response: AuthResponse = try await network.request("/auth/login", method: "POST", body: body)
       // Save response.token to Keychain
       return response.token
   }

   struct AuthResponse: Codable {
       let token: String
   }
   ```

6. **Testing & Debugging**:
   - Use Postman/Insomnia to mock backend.
   - Add logging with `os_log`.
   - Unit test services with XCTest (mock URLSession).
   - For retail APIs (e.g., Walmart Developer API), register for keys and add OAuth flows.

7. **Production Tips**:
   - **Rate Limiting/Offline**: Cache responses with Core Data; use Reachability for offline mode.
   - **Analytics**: Integrate Firebase Analytics or Mixpanel for tracking.
   - **Payments**: Use Stripe SDK for iOS—add via SPM and handle webhooks.
   - **Scalability**: Paginate lists (e.g., `/orders?page=1&limit=20`).
   - **Compliance**: GDPR/CCPA for user data; PCI for payments.

For a full backend starter, consider Vapor (Swift server) or Firebase. If integrating third-party retail APIs, review their docs (e.g., Target's API for order linking).

## 🔧 Installation

1. **Prerequisites**:
   - Xcode 15.0+
   - iOS Simulator or physical device (for location testing)

2. **Clone & Open**:
   ```bash
   git clone <your-repo-url>
   cd Rapidual
   open Rapidual.xcodeproj
   ```

3. **Build & Run**:
   - Select an iOS simulator (e.g., iPhone 15).
   - Build (⌘+B) and run (⌘+R).
   - Grant location permissions when prompted.

4. **Testing Service Areas**:
   - The app simulates locations in Orange County, CA. Use Xcode's location simulation for testing outside these areas.

## 🎮 Usage

### Customer Mode
- Launch the app and toggle to **User** mode via the top switcher.
- On **Home**, select pickup time, adjust bag count, and tap **Start Order**.
- Browse **Retail** for bundled shopping; link accounts for free delivery.
- Track orders in **Activity** with live timelines.

### Driver Mode
- Toggle to **Driver** mode.
- Go **Online** on the map view to see metrics and jobs.
- Accept jobs in **Jobs** tab; use **Home** for navigation.
- Complete workflows: Pickup → Drop-off → Notes.

### Customization
- Edit `ServiceArea.defaultAreas` for new regions.
- Modify `AppTheme` for branding.
- Extend `LocationService` for production geofencing.

## 🏗 Architecture
- **MVVM Pattern**: `@StateObject`/`@Published` for reactive state (e.g., `LocationService`).
- **Modular Views**: Reusable components (e.g., `Card`, `Pill`, `ProgressLine`) in dedicated sections.
- **State Management**: `@State` for local UI, `@StateObject` for services.
- **Navigation**: `NavigationStack` with tabs for main flows; `navigationDestination` for deep links.

File Structure (Single-File Prototype):
- `ContentView`: Root with mode switcher.
- `Customer*` Views: Home, Orders, Explore, Account.
- `Driver*` Views: Home (Map), Jobs, Orders, Ops.
- Helpers: Themes, Services, Reusables.

## 🤝 Contributing
Pull requests welcome! For major changes, open an issue first.

1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Commit changes (`git commit -m 'Add amazing feature'`).
4. Push (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments
- Inspired by modern delivery apps (e.g., Uber, Instacart).
- UI patterns from Apple's Human Interface Guidelines.
- Built by Thomas Peters (as per code header).

---

*Questions? Open an issue or reach out.*  
*Happy coding! 🚀*
